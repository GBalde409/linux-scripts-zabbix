#!/bin/bash
# Universal SMART Discovery for Zabbix (Discos Diretos + Hardware RAID)

echo "["
first=1

# Função para montar o objeto JSON
add_disk() {
    local path=$1
    local type=$2
    local name=$3
    if [ $first -eq 0 ]; then echo ","; fi
    echo -n '{"{#DISKPATH}":"'$path'", "{#SMART_TYPE}":"'$type'", "{#DISKNAME}":"'$name'"}'
    first=0
}

# 1. Descoberta de discos normais (SATA, NVMe, USB, etc) via scan nativo
while read -r line; do
    if [[ -z "$line" || "$line" == "#"* ]]; then continue; fi
    path=$(echo "$line" | awk '{print $1}')
    type=$(echo "$line" | awk '{print $3}')
    name=$(basename "$path")
    add_disk "$path" "$type" "$name"
done < <(sudo /usr/sbin/smartctl --scan)

# Mapeia apenas block devices reais para economizar tempo no probing do RAID
BLOCK_DEVS=$(lsblk -nd -o NAME | grep -E "^sd|^nvme" | awk '{print "/dev/"$1}')

# 2. Sondagem para HP Smart Array (cciss)
if lspci | grep -i -E "Hewlett-Packard Company Smart Array" >/dev/null 2>&1; then
    for dev in $BLOCK_DEVS; do
        for id in {0..15}; do
            # Testa silenciosamente se o disco físico responde
            if sudo /usr/sbin/smartctl -i -d cciss,$id "$dev" >/dev/null 2>&1; then
                add_disk "$dev" "cciss,$id" "$(basename "$dev")_cciss_$id"
            fi
        done
    done
fi

# 3. Sondagem para LSI / MegaRAID
if lspci | grep -i -E "MegaRAID|LSI Logic" >/dev/null 2>&1; then
    for dev in $BLOCK_DEVS; do
        for id in {0..15}; do
            if sudo /usr/sbin/smartctl -i -d megaraid,$id "$dev" >/dev/null 2>&1; then
                add_disk "$dev" "megaraid,$id" "$(basename "$dev")_mega_$id"
            fi
        done
    done
fi

echo "]"
