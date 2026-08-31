#!/bin/bash

# Lista apenas os discos físicos, ignorando partições (-d) e cabeçalhos (-n)
for disk in $(lsblk -d -n -o NAME | grep -E '^sd|^nvme'); do
    # Verifica se o disco é rotacional
    rota=$(cat /sys/block/$disk/queue/rotational 2>/dev/null)

    if [ "$rota" = "1" ]; then
        # É um HDD: Executa Teste Longo
        smartctl -t long /dev/$disk
    elif [ "$rota" = "0" ]; then
        # É um SSD/NVMe: Executa Teste Curto
        smartctl -t short /dev/$disk
    fi
done
