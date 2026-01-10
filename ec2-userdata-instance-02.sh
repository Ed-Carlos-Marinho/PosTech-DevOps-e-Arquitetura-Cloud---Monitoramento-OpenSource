#!/bin/bash

# =============================================================================
# EC2 USER DATA SCRIPT - MONITORED HOST SETUP
# =============================================================================
# Script de configuração automática para instância monitorada (Instância 2)
# Aula 03 - PosTech DevOps e Arquitetura Cloud - Monitoramento OpenSource
# 
# Este script instala e configura automaticamente:
# - Node Exporter (métricas do sistema)
# - cAdvisor (métricas de containers)
# - Zabbix Agent (monitoramento tradicional)
# - Docker (para cAdvisor)
# =============================================================================

# -----------------------------------------------------------------------------
# CONFIGURAÇÕES DE AMBIENTE
# -----------------------------------------------------------------------------
# Define variáveis de ambiente essenciais para execução como root
export HOME=/root
export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

# -----------------------------------------------------------------------------
# CONFIGURAÇÃO DE LOGS
# -----------------------------------------------------------------------------
# Redireciona toda saída (stdout e stderr) para arquivo de log
# Permite acompanhar a execução via: sudo tail -f /var/log/user-data.log
exec > >(tee /var/log/user-data.log) 2>&1
echo "=== Iniciando configuração do host monitorado em $(date) ==="

# -----------------------------------------------------------------------------
# FUNÇÃO DE VERIFICAÇÃO DE STATUS
# -----------------------------------------------------------------------------
# Função utilitária para verificar se comandos foram executados com sucesso
# Parâmetro: $1 = Descrição da operação para log
check_status() {
    if [ $? -eq 0 ]; then
        echo "✅ $1 - Sucesso"
    else
        echo "❌ $1 - Falhou"
        exit 1                              # Para execução em caso de erro
    fi
}

# =============================================================================
# FASE 1: ATUALIZAÇÃO DO SISTEMA
# =============================================================================

echo "📦 Atualizando sistema..."
apt-get update -y                           # Atualiza lista de pacotes disponíveis
check_status "Atualização do sistema"

# =============================================================================
# FASE 2: INSTALAÇÃO DE PACOTES BÁSICOS
# =============================================================================

echo "📦 Instalando pacotes básicos..."
apt-get install -y curl wget htop docker.io # Instala ferramentas essenciais
# curl/wget: Clientes HTTP para downloads
# htop: Monitor de processos interativo
# docker.io: Para executar cAdvisor
check_status "Instalação de pacotes básicos"

# =============================================================================
# FASE 3: CONFIGURAÇÃO DO DOCKER
# =============================================================================

echo "🐳 Configurando Docker..."
systemctl start docker                      # Inicia serviço do Docker
systemctl enable docker                     # Habilita Docker para iniciar com o sistema
usermod -a -G docker ubuntu                 # Adiciona usuário ubuntu ao grupo docker
check_status "Configuração do Docker"

# =============================================================================
# FASE 4: INSTALAÇÃO DO NODE EXPORTER
# =============================================================================

echo "📊 Instalando Node Exporter..."

# Criar usuário para o Node Exporter
useradd --no-create-home --shell /bin/false node_exporter
check_status "Criação do usuário node_exporter"

# Baixar Node Exporter (versão AMD64 para t3.small)
cd /tmp
wget https://github.com/prometheus/node_exporter/releases/download/v1.8.2/node_exporter-1.8.2.linux-amd64.tar.gz
check_status "Download do Node Exporter"

# Extrair e instalar
tar xvf node_exporter-1.8.2.linux-amd64.tar.gz
cp node_exporter-1.8.2.linux-amd64/node_exporter /usr/local/bin/
chown node_exporter:node_exporter /usr/local/bin/node_exporter
check_status "Instalação do Node Exporter"

# Limpar arquivos temporários
rm -rf node_exporter-1.8.2.linux-amd64*
check_status "Limpeza de arquivos temporários do Node Exporter"

# =============================================================================
# FASE 5: CONFIGURAÇÃO DO SERVIÇO NODE EXPORTER
# =============================================================================

echo "🔧 Configurando serviço Node Exporter..."

# Criar arquivo de serviço systemd
cat > /etc/systemd/system/node_exporter.service << 'EOF'
[Unit]
Description=Node Exporter
Wants=network-online.target
After=network-online.target

[Service]
User=node_exporter
Group=node_exporter
Type=simple
ExecStart=/usr/local/bin/node_exporter \
    --collector.systemd \
    --collector.processes \
    --web.listen-address=:9100

[Install]
WantedBy=multi-user.target
EOF

# Recarregar systemd e iniciar serviço
systemctl daemon-reload
systemctl enable node_exporter
systemctl start node_exporter
check_status "Configuração e inicialização do Node Exporter"

# =============================================================================
# FASE 6: INSTALAÇÃO DO CADVISOR VIA DOCKER
# =============================================================================

echo "🐳 Instalando cAdvisor via Docker..."

# Executar cAdvisor como container Docker
docker run -d \
  --name=cadvisor \
  --restart=unless-stopped \
  --volume=/:/rootfs:ro \
  --volume=/var/run:/var/run:ro \
  --volume=/sys:/sys:ro \
  --volume=/var/lib/docker/:/var/lib/docker:ro \
  --volume=/dev/disk/:/dev/disk:ro \
  --publish=8080:8080 \
  --privileged \
  --device=/dev/kmsg \
  gcr.io/cadvisor/cadvisor:latest

check_status "Instalação e inicialização do cAdvisor"

# =============================================================================
# FASE 7: INSTALAÇÃO DO ZABBIX AGENT
# =============================================================================

echo "🔍 Instalando Zabbix Agent..."

# Baixar binário estático do Zabbix Agent 7.4.6 (AMD64)
wget https://cdn.zabbix.com/zabbix/binaries/stable/7.4/7.4.6/zabbix_agent-7.4.6-linux-3.0-amd64-static.tar.gz
check_status "Download do Zabbix Agent"

# Extrair arquivos
tar -xzf zabbix_agent-7.4.6-linux-3.0-amd64-static.tar.gz
check_status "Extração do Zabbix Agent"

# Criar usuário zabbix
useradd --system --shell /bin/false zabbix
check_status "Criação do usuário zabbix"

# Criar diretórios necessários
mkdir -p /usr/local/sbin
mkdir -p /etc/zabbix
mkdir -p /var/log/zabbix
mkdir -p /run/zabbix

# Copiar binários
cp sbin/zabbix_agentd /usr/local/sbin/
cp bin/zabbix_get /usr/local/bin/
cp bin/zabbix_sender /usr/local/bin/

# Definir permissões
chown root:root /usr/local/sbin/zabbix_agentd
chmod 755 /usr/local/sbin/zabbix_agentd
chown zabbix:zabbix /var/log/zabbix
chown zabbix:zabbix /run/zabbix

check_status "Configuração de binários e permissões do Zabbix Agent"

# Limpar arquivos temporários
rm -rf zabbix_agent-*
check_status "Limpeza de arquivos temporários do Zabbix Agent"

# =============================================================================
# FASE 8: CONFIGURAÇÃO DO ZABBIX AGENT
# =============================================================================

echo "⚙️ Configurando Zabbix Agent..."

# Criar arquivo de configuração
cat > /etc/zabbix/zabbix_agentd.conf << 'EOF'
PidFile=/run/zabbix/zabbix_agentd.pid
LogFile=/var/log/zabbix/zabbix_agentd.log
LogFileSize=0
Server=ZABBIX_SERVER_IP
ServerActive=ZABBIX_SERVER_IP
Hostname=monitored-host-01
EOF

check_status "Criação do arquivo de configuração do Zabbix Agent"

# Criar serviço systemd
cat > /etc/systemd/system/zabbix-agent.service << 'EOF'
[Unit]
Description=Zabbix Agent
After=syslog.target
After=network.target

[Service]
Environment="CONFFILE=/etc/zabbix/zabbix_agentd.conf"
Type=forking
Restart=on-failure
PIDFile=/run/zabbix/zabbix_agentd.pid
KillMode=control-group
ExecStart=/usr/local/sbin/zabbix_agentd -c $CONFFILE
ExecStop=/bin/kill -SIGTERM $MAINPID
RestartSec=10s
User=zabbix
Group=zabbix

[Install]
WantedBy=multi-user.target
EOF

# Recarregar systemd e habilitar serviço (não iniciar ainda - precisa configurar IP)
systemctl daemon-reload
systemctl enable zabbix-agent
check_status "Configuração do serviço Zabbix Agent"

# =============================================================================
# FASE 9: CONFIGURAÇÃO DO FIREWALL
# =============================================================================

echo "🔥 Configurando firewall..."
ufw --force enable                          # Habilita firewall (força sem prompt)
ufw allow ssh                               # Permite SSH (porta 22)
ufw allow 9100                              # Permite Node Exporter
ufw allow 8080                              # Permite cAdvisor
ufw allow 10050                             # Permite Zabbix Agent
check_status "Configuração do firewall"

# =============================================================================
# FASE 10: VERIFICAÇÃO FINAL
# =============================================================================

echo "🔍 Verificando status dos serviços..."
# Verifica se serviços estão ativos e reporta status
systemctl is-active docker && echo "✅ Docker está rodando"
systemctl is-active node_exporter && echo "✅ Node Exporter está rodando"
docker ps | grep cadvisor && echo "✅ cAdvisor está rodando"
systemctl is-enabled zabbix-agent && echo "✅ Zabbix Agent está habilitado (aguardando configuração de IP)"

# =============================================================================
# FINALIZAÇÃO E INFORMAÇÕES DE CONFIGURAÇÃO
# =============================================================================

echo "=== ✅ Configuração do host monitorado concluída em $(date) ==="
echo ""
echo "📊 Serviços instalados e configurados:"
echo "   - Node Exporter: http://$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4):9100/metrics"
echo "   - cAdvisor: http://$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4):8080/metrics"
echo "   - Zabbix Agent: porta 10050 (aguardando configuração)"
echo ""
echo "⚠️  PRÓXIMOS PASSOS MANUAIS:"
echo "   1. Obter IP privado da instância de monitoramento"
echo "   2. Executar: sudo sed -i 's/ZABBIX_SERVER_IP/IP_REAL_AQUI/' /etc/zabbix/zabbix_agentd.conf"
echo "   3. Executar: sudo systemctl start zabbix-agent"
echo "   4. Configurar targets no Prometheus (prometheus.yml)"
echo "   5. Adicionar host no Zabbix Server"
echo ""
echo "🔧 Comandos úteis:"
echo "   - Verificar Node Exporter: curl http://localhost:9100/metrics"
echo "   - Verificar cAdvisor: curl http://localhost:8080/metrics"
echo "   - Status Zabbix Agent: sudo systemctl status zabbix-agent"
echo "   - Logs: sudo tail -f /var/log/user-data.log"

# =============================================================================
# INFORMAÇÕES IMPORTANTES PARA MANUTENÇÃO:
# =============================================================================
# 
# LOGS E TROUBLESHOOTING:
# - Log de execução: /var/log/user-data.log
# - Logs Node Exporter: journalctl -u node_exporter -f
# - Logs cAdvisor: docker logs cadvisor
# - Logs Zabbix Agent: journalctl -u zabbix-agent -f
#
# ARQUIVOS DE CONFIGURAÇÃO:
# - Node Exporter service: /etc/systemd/system/node_exporter.service
# - Zabbix Agent config: /etc/zabbix/zabbix_agentd.conf
# - Zabbix Agent service: /etc/systemd/system/zabbix-agent.service
#
# PORTAS UTILIZADAS:
# - 22: SSH
# - 9100: Node Exporter
# - 8080: cAdvisor
# - 10050: Zabbix Agent
#
# COMANDOS DE MANUTENÇÃO:
# - Reiniciar Node Exporter: systemctl restart node_exporter
# - Reiniciar cAdvisor: docker restart cadvisor
# - Reiniciar Zabbix Agent: systemctl restart zabbix-agent
# - Ver métricas: curl http://localhost:9100/metrics
# - Ver containers: curl http://localhost:8080/metrics
#
# CONFIGURAÇÃO FINAL NECESSÁRIA:
# 1. Substituir ZABBIX_SERVER_IP pelo IP real da instância 1
# 2. Atualizar prometheus.yml com IP desta instância
# 3. Adicionar host no Zabbix Server
# =============================================================================