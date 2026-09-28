#!/bin/bash

echo "["
first=1
DISCOVERED_SERIALS="|"

add_disk() {
    local path=$1
    local type=$2
    local name=$3
    
    # Coleta o Serial Number para evitar duplicação de discos mapeados duas vezes (ex: JBOD)
    local serial
    serial=$(sudo /usr/sbin/smartctl -i -d "$type" "$path" 2>/dev/null | grep -i "^Serial Number" | awk '{print $NF}')
    
    # Se o serial existir e já estiver na nossa lista, aborta a adição deste disco
    if [ -n "$serial" ]; then
        if [[ "$DISCOVERED_SERIALS" == *"|$serial|"* ]]; then
            return
        fi
        DISCOVERED_SERIALS="$DISCOVERED_SERIALS$serial|"
    fi

    if [ $first -eq 0 ]; then echo ","; fi
    echo -n '{"{#DISKPATH}":"'$path'", "{#SMART_TYPE}":"'$type'", "{#DISKNAME}":"'$name'"}'
    first=0
}

# =========================================================
# 1. Controladoras HP Smart Array (Executado Primeiro)
# =========================================================
if lspci | grep -i -E "Hewlett-Packard|Smart Array" >/dev/null 2>&1; then
    hp_portal=$(ls /dev/sd[a-z] 2>/dev/null | head -n 1)
    
    if [ -n "$hp_portal" ]; then
        for id in {0..15}; do
            if sudo /usr/sbin/smartctl -i -d cciss,$id "$hp_portal" >/dev/null 2>&1; then
                add_disk "$hp_portal" "cciss,$id" "hp_bay_$id"
            fi
        done
    fi
fi

# =========================================================
# 2. Controladoras LSI / MegaRAID (Executado Primeiro)
# =========================================================
if lspci | grep -i -E "MegaRAID|LSI Logic" >/dev/null 2>&1; then
    lsi_portal=$(ls /dev/sd[a-z] 2>/dev/null | head -n 1)
    
    if [ -n "$lsi_portal" ]; then
        for id in {0..15}; do
            if sudo /usr/sbin/smartctl -i -d megaraid,$id "$lsi_portal" >/dev/null 2>&1; then
                add_disk "$lsi_portal" "megaraid,$id" "mega_$id"
            fi
        done
    fi
fi

# =========================================================
# 3. Discos Diretos / SO (Executado no Final)
# =========================================================
while read -r line; do
    if [[ -z "$line" || "$line" == "#"* ]]; then continue; fi
    path=$(echo "$line" | awk '{print $1}')
    type=$(echo "$line" | awk '{print $3}')

    # Ignora caminhos de barramento (ex: /dev/bus/2) e controladoras já tratadas
    if [[ "$path" == *"/bus/"* || "$type" == *"megaraid"* || "$type" == *"cciss"* ]]; then
        continue
    fi

    if [ "$type" == "scsi" ]; then
        if sudo /usr/sbin/smartctl -a -d sat "$path" | grep -q "SMART overall"; then
            type="sat"
        fi
    fi

    # Validação: Falha se não responder ao SMART
    if ! sudo /usr/sbin/smartctl -H -d "$type" "$path" >/dev/null 2>&1; then
        continue
    fi

    # Validação: Ignora Volumes Virtuais
    if sudo /usr/sbin/smartctl -i -d "$type" "$path" | grep -iE "^(Device Model|Model Family|Vendor|Product):" | grep -iE "PERC|Virtual|Logical|RAID|MegaSR" >/dev/null 2>&1; then
        continue
    fi

    name=$(basename "$path")
    add_disk "$path" "$type" "$name"
done < <(sudo /usr/sbin/smartctl --scan)

echo "]"
