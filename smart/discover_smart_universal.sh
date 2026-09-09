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
    name=$(basename "$path")
    add_disk "$path" "$type" "$name"
done < <(sudo /usr/sbin/smartctl --scan)

# Trecho corrigido para a parte HP no script do GitHub:
if lspci | grep -i -E "Hewlett-Packard Company Smart Array" >/dev/null 2>&1; then
    for dev in /dev/sd[a-z]; do
        [ -e "$dev" ] || continue
        for id in {0..5}; do
            # O truque está em garantir que o tipo use a variável $id corretamente
            if sudo /usr/sbin/smartctl -i -d cciss,$id "$dev" >/dev/null 2>&1; then
                add_disk "$dev" "cciss,$id" "$(basename "$dev")_hp_$id"
            fi
        done
    done
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
