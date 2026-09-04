#!/bin/bash
# Ajuste a URL abaixo para o link "Raw" do seu arquivo no GitHub
GITHUB_RAW_URL="https://raw.githubusercontent.com/seu-usuario/seu-repo/main/smart_check_linux.sh"

# 1. Baixa o script e dá permissão
mkdir -p /etc/zabbix/scripts
wget -qO /etc/zabbix/scripts/discover_smart_universal.sh $GITHUB_RAW_URL
chmod +x /etc/zabbix/scripts/discover_smart_universal.sh

# 2. Configura o sudoers restrito apenas para o smartctl
echo "zabbix ALL=(ALL) NOPASSWD: /usr/sbin/smartctl" > /etc/sudoers.d/zabbix_smartctl
chmod 440 /etc/sudoers.d/zabbix_smartctl

# 3. Injeta os UserParameters do Zabbix Agent 2
cat << 'EOF' > /etc/zabbix/zabbix_agent2.d/smart_universal.conf
UserParameter=universal.smart.discovery,/etc/zabbix/scripts/discover_smart_universal.sh
UserParameter=universal.smart.get[*],sudo /usr/sbin/smartctl -j -a -d $2 $1
EOF

# 4. Reinicia o agente para aplicar
systemctl restart zabbix-agent2
