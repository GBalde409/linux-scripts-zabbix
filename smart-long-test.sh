#!/bin/bash
# Script para agendamento mensal de Teste SMART Longo

smartctl --scan | while read -r line; do
    # Identifica o disco e o tipo (incluindo MegaRAID)
    device=$(echo "$line" | awk '{print $1}')
    type=$(echo "$line" | grep -o '\-d [a-zA-Z0-9,]*' || echo "")
    
    # Inicia o teste longo em background
    smartctl -t long $device $type >/dev/null 2>&1
    
    # IMPORTANTE: Pausa de 2 horas (7200 segundos) entre os discos.
    # Como o teste longo demora e degrada a performance de leitura/escrita,
    # essa pausa garante que o I/O do Storage como um todo não seja enforcado.
    sleep 7200
done
