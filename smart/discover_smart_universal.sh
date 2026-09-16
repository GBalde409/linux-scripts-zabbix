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

    if [ "$type" == "scsi" ]; then
        if sudo /usr/sbin/smartctl -a -d sat "$path" | grep -q "SMART overall"; then
            type="sat"
        fi
    fi

    # VALIDAÇÃO 1: Falha se não responder ao SMART
    if ! sudo /usr/sbin/smartctl -H -d "$type" "$path" >/dev/null 2>&1; then
        continue
    fi

    # VALIDAÇÃO 2 (CORRIGIDA): Ignora Volumes Virtuais olhando apenas para o campo de Modelo/Fabricante
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

# 3. Varredura Otimizada para LSI / MegaRAID
if lspci | grep -i -E "MegaRAID|LSI Logic" >/dev/null 2>&1; then
    for dev in /dev/sd[a-z]; do
        [ -e "$dev" ] || continue
        for id in {0..3}; do
            if sudo /usr/sbin/smartctl -i -d megaraid,$id "$dev" >/dev/null 2>&1; then
                add_disk "$dev" "megaraid,$id" "$(basename "$dev")_mega_$id"
                break
            fi
        done
    done
fi

echo "]"
