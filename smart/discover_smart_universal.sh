#!/bin/bash

echo "["
first=1

add_disk() {
    local path=$1
    local type=$2
    local name=$3
    if [ $first -eq 0 ]; then echo ","; fi
    echo -n '{"{#DISKPATH}":"'$path'", "{#SMART_TYPE}":"'$type'", "{#DISKNAME}":"'$name'"}'
    first=0
}

# 1. Discos Diretos (SATA, NVMe, etc)
while read -r line; do
    if [[ -z "$line" || "$line" == "#"* ]]; then continue; fi
    path=$(echo "$line" | awk '{print $1}')
    type=$(echo "$line" | awk '{print $3}')

if [[ "$type" == *"megaraid"* || "$type" == *"cciss"* ]]; then
        continue
    fi
   
    if [ "$type" == "scsi" ]; then
        if sudo /usr/sbin/smartctl -a -d sat "$path" | grep -q "SMART overall"; then
            type="sat"
        fi
    fi

    # VALIDAÇÃO 1: Falha se não responder ao SMART
    if ! sudo /usr/sbin/smartctl -H -d "$type" "$path" >/dev/null 2>&1; then
        continue
    fi

    # VALIDAÇÃO 2: Ignora Volumes Virtuais olhando apenas para o campo de Modelo/Fabricante
    if sudo /usr/sbin/smartctl -i -d "$type" "$path" | grep -iE "^(Device Model|Model Family|Vendor|Product):" | grep -iE "PERC|Virtual|Logical|RAID|MegaSR" >/dev/null 2>&1; then
        continue
    fi

    name=$(basename "$path")
    add_disk "$path" "$type" "$name"
done < <(sudo /usr/sbin/smartctl --scan)

# 2. Controladoras HP Smart Array
if lspci | grep -i -E "Hewlett-Packard|Smart Array" >/dev/null 2>&1; then
    # Pega apenas o primeiro disco lógico gerado pela HP para servir como portal
    hp_portal=$(ls /dev/sd[a-z] 2>/dev/null | head -n 1)
    
    if [ -n "$hp_portal" ]; then
        for id in {0..15}; do
            # Usando -i (Info) para garantir a compatibilidade com todas as iLOs
            if sudo /usr/sbin/smartctl -i -d cciss,$id "$hp_portal" >/dev/null 2>&1; then
                add_disk "$hp_portal" "cciss,$id" "hp_bay_$id"
            fi
        done
    fi
fi

# 3. Varredura Otimizada para LSI / MegaRAID (CORRIGIDO)
if lspci | grep -i -E "MegaRAID|LSI Logic" >/dev/null 2>&1; then
    # Pega apenas o primeiro disco lógico para servir como portal (evita duplicação)
    lsi_portal=$(ls /dev/sd[a-z] 2>/dev/null | head -n 1)
    
    if [ -n "$lsi_portal" ]; then
        # Expandido para 15 para cobrir servidores com backplanes maiores (antes estava {0..3})
        for id in {0..15}; do
            if sudo /usr/sbin/smartctl -i -d megaraid,$id "$lsi_portal" >/dev/null 2>&1; then
                # Nomeia de forma padronizada, independente do disco lógico usado como portal
                add_disk "$lsi_portal" "megaraid,$id" "mega_$id"
            fi
        done
    fi
fi

echo "]"
