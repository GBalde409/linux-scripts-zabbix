#!/bin/bash

# ATENÇÃO: Substitua a URL abaixo pelo link RAW do seu arquivo discover_smart_universal.sh no GitHub
URL_DISCOVERY="https://raw.githubusercontent.com/GBalde409/linux-scripts-zabbix/refs/heads/main/smart/discover_smart_universal.sh"

echo "1. Preparando diretorios..."
mkdir -p /etc/zabbix/scripts

echo "2. Baixando script de descoberta universal..."
wget -qO /etc/zabbix/scripts/discover_smart_universal.sh "$URL_DISCOVERY"
chmod +x /etc/zabbix/scripts/discover_smart_universal.sh

echo "3. Configurando permissoes no sudoers para o Zabbix..."
echo "zabbix ALL=(ALL) NOPASSWD: /usr/sbin/smartctl" > /etc/sudoers.d/zabbix_smartctl
chmod 440 /etc/sudoers.d/zabbix_smartctl

echo "4. Injetando parametros no Zabbix Agent 2..."
cat << 'EOF' > /etc/zabbix/zabbix_agent2.d/smart_universal.conf
UserParameter=universal.smart.discovery,/etc/zabbix/scripts/discover_smart_universal.sh
UserParameter=universal.smart.get[*],sudo /usr/sbin/smartctl -j -a -d $2 $1
EOF

echo "5. Reiniciando Zabbix Agent 2..."
systemctl restart zabbix-agent2

echo "Instalacao concluida com sucesso!"
