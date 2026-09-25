#!/bin/bash

echo "======================================================"
echo "Iniciando instalação/atualização do SMART Zabbix..."
echo "======================================================"

# 1. Limpeza e Idempotência (Evita duplicidade de chaves)
echo "[1/7] Limpando configurações legadas..."
rm -f /etc/zabbix/zabbix_agent2.d/smart*.conf
rm -f /etc/zabbix/zabbix_agentd.d/smart*.conf

# 2. Prepara diretório
echo "[2/7] Criando diretório de scripts..."
mkdir -p /etc/zabbix/scripts/

# 3. Baixa o script de descoberta (LLD) atualizado
echo "[3/7] Baixando discover_smart_universal.sh do GitHub..."
curl -sSL -o /etc/zabbix/scripts/discover_smart_universal.sh "https://raw.githubusercontent.com/GBalde409/linux-scripts-zabbix/refs/heads/main/smart/discover_smart_universal.sh"
chmod +x /etc/zabbix/scripts/discover_smart_universal.sh

# 4. Injeta as chaves (Discovery e Get) para Agent 2
if [ -d /etc/zabbix/zabbix_agent2.d ]; then
    echo "[4/7] Injetando UserParameters no Zabbix Agent 2..."
    echo "UserParameter=universal.smart.discovery,sudo /etc/zabbix/scripts/discover_smart_universal.sh" > /etc/zabbix/zabbix_agent2.d/smart_discovery.conf
    echo 'UserParameter=universal.smart.get[*],sudo /usr/sbin/smartctl -j -a -d $2 $1' >> /etc/zabbix/zabbix_agent2.d/smart_discovery.conf
fi

# 5. Configura permissão de Root (Sudoers) sem senha
echo "[5/7] Configurando permissões do Sudoers para o Zabbix..."
echo "zabbix ALL=(ALL) NOPASSWD: /etc/zabbix/scripts/discover_smart_universal.sh, /usr/sbin/smartctl" > /etc/sudoers.d/zabbix_smart
chmod 0440 /etc/sudoers.d/zabbix_smart

# 6. Aumenta o Timeout para 30 segundos (Previne 'context deadline exceeded')
echo "[6/7] Ajustando Timeout nos arquivos de configuração..."
if [ -f /etc/zabbix/zabbix_agent2.conf ]; then
    sed -i 's/^# Timeout=.*/Timeout=30/' /etc/zabbix/zabbix_agent2.conf
    sed -i 's/^Timeout=.*/Timeout=30/' /etc/zabbix/zabbix_agent2.conf
fi

# 7. Aplica as configurações
echo "[7/7] Reiniciando serviço do Zabbix Agent..."
systemctl restart zabbix-agent2 2>/dev/null || systemctl restart zabbix-agent 2>/dev/null

echo "======================================================"
echo "Instalação finalizada com sucesso!"
echo "O host já está pronto para o Template Zabbix."
echo "======================================================"
