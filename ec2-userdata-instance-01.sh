#!/bin/bash

# =============================================================================
# EC2 USER DATA SCRIPT - AUTOMATED SETUP
# =============================================================================
# Script de configuração automática para instâncias EC2 Ubuntu
# Aula 03 - PosTech DevOps e Arquitetura Cloud - Monitoramento OpenSource
# 
# OBJETIVO DA AULA 03:
# Configurar o Grafana para integrar fontes de dados (Prometheus, Zabbix),
# criar dashboards dinâmicos e configurar alertas visuais e notificações.
#
# Este script instala e configura automaticamente:
# - Docker e Docker Compose (para stack completa de monitoramento)
# - Code-server (VS Code no navegador) para desenvolvimento
# - Configurações básicas de segurança
# - Preparação para stack Grafana + Prometheus + Zabbix + Alertmanager
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
echo "=== Iniciando configuração da demo em $(date) ==="

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
apt-get install -y git curl htop docker.io  # Instala ferramentas essenciais
# git: Controle de versão
# curl: Cliente HTTP para downloads
# htop: Monitor de processos interativo
# docker.io: Plataforma de containerização
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
# FASE 4: INSTALAÇÃO DO DOCKER COMPOSE
# =============================================================================

echo "🐳 Instalando Docker Compose..."
# Download da versão específica para arquitetura ARM64 (t4g.small)
curl -L "https://github.com/docker/compose/releases/download/v2.24.5/docker-compose-linux-aarch64" -o /usr/local/bin/docker-compose
chmod +x /usr/local/bin/docker-compose       # Torna executável
check_status "Instalação do Docker Compose"

# =============================================================================
# FASE 5: INSTALAÇÃO DO CODE-SERVER
# =============================================================================

echo "💻 Instalando code-server..."
# Usa script oficial de instalação do code-server
curl -fsSL https://code-server.dev/install.sh | sh
check_status "Instalação do code-server"

# Aguarda e verifica se instalação foi bem-sucedida
sleep 3
if [ ! -f /usr/bin/code-server ]; then
    echo "❌ Code-server não foi instalado corretamente"
    exit 1
fi

# =============================================================================
# FASE 6: CRIAÇÃO DE USUÁRIO DEDICADO PARA CODE-SERVER
# =============================================================================

echo "👤 Criando usuário dedicado para code-server..."
# Cria usuário específico para code-server com diretório home
useradd -m -s /bin/bash -c "Code Server User" codeserver
# Adiciona ao grupo docker para poder usar Docker se necessário
usermod -a -G docker codeserver
check_status "Criação do usuário codeserver"

# =============================================================================
# FASE 7: CONFIGURAÇÃO DO CODE-SERVER
# =============================================================================

echo "⚙️ Configurando code-server..."
# Cria diretório de configuração para o usuário codeserver
mkdir -p /home/codeserver/.config/code-server

# Cria arquivo de configuração do code-server
cat > /home/codeserver/.config/code-server/config.yaml << 'EOF'
bind-addr: 0.0.0.0:8080                     # Escuta em todas interfaces na porta 8080
auth: password                              # Usa autenticação por senha
password: demo123                           # Senha de acesso (ALTERAR EM PRODUÇÃO)
cert: false                                 # Desabilita HTTPS (usar proxy reverso em produção)
EOF

# Define propriedade correta dos arquivos de configuração
chown -R codeserver:codeserver /home/codeserver/.config
check_status "Configuração do code-server"

# =============================================================================
# FASE 8: CRIAÇÃO DO SERVIÇO SYSTEMD
# =============================================================================

echo "🔧 Criando serviço systemd..."
# Cria arquivo de serviço para gerenciar code-server via systemd
cat > /etc/systemd/system/code-server.service << 'EOF'
[Unit]
Description=Code Server - VS Code in Browser
After=network.target

[Service]
Type=simple
User=codeserver
Group=codeserver
WorkingDirectory=/home/codeserver
Environment=HOME=/home/codeserver
Environment=XDG_CONFIG_HOME=/home/codeserver/.config
Environment=XDG_DATA_HOME=/home/codeserver/.local/share
ExecStart=/usr/bin/code-server --config /home/codeserver/.config/code-server/config.yaml
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

# =============================================================================
# FASE 9: INICIALIZAÇÃO DO CODE-SERVER
# =============================================================================

echo "🚀 Iniciando code-server..."
systemctl daemon-reload                     # Recarrega configurações do systemd
systemctl enable code-server                # Habilita para iniciar com sistema
systemctl start code-server                 # Inicia o serviço
check_status "Inicialização do code-server"

# =============================================================================
# FASE 10: CONFIGURAÇÃO DO FIREWALL
# =============================================================================

echo "🔥 Configurando firewall..."
ufw --force enable                          # Habilita firewall (força sem prompt)
ufw allow ssh                               # Permite SSH (porta 22)
ufw allow http                              # Permite HTTP (porta 80) - para Grafana
ufw allow 8081                              # Permite porta 8081 - para Zabbix web
ufw allow 9090                              # Permite porta 9090 - para Prometheus
ufw allow 9093                              # Permite porta 9093 - para Alertmanager
ufw allow 8080                              # Permite porta 8080 - para code-server
ufw allow 10051                             # Permite porta 10051 - para Zabbix Server
check_status "Configuração do firewall"

# =============================================================================
# FASE 11: VERIFICAÇÃO FINAL
# =============================================================================

echo "🔍 Verificando status dos serviços..."
# Verifica se serviços estão ativos e reporta status
systemctl is-active docker && echo "✅ Docker está rodando"
systemctl is-active code-server && echo "✅ Code-server está rodando"

# =============================================================================
# FINALIZAÇÃO E INFORMAÇÕES DE ACESSO
# =============================================================================

echo "=== ✅ Configuração concluída com sucesso em $(date) ==="
echo ""
echo "🎯 AULA 03 - STACK DE MONITORAMENTO PREPARADA"
echo "=============================================="
echo "🌐 Code-server disponível em: http://$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4):8080"
echo "🔑 Senha: demo123"
echo ""
echo "📊 PRÓXIMOS PASSOS PARA AULA 03:"
echo "1. Clonar repositório: git clone -b aula-03 https://github.com/Ed-Carlos-Marinho/PosTech-DevOps-e-Arquitetura-Cloud---Monitoramento-OpenSource.git PosTech"
echo "2. Executar: docker-compose up -d"
echo "3. Acessar interfaces:"
echo "   - Grafana: http://$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4):80 (admin/admin123)"
echo "   - Prometheus: http://$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4):9090"
echo "   - Alertmanager: http://$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4):9093"
echo "   - Zabbix: http://$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4):8080 (Admin/zabbix)"
echo ""
echo "🐳 Docker e Docker Compose instalados e configurados"
echo "🔧 Sistema pronto para stack completa de monitoramento"

# =============================================================================
# INFORMAÇÕES IMPORTANTES PARA AULA 03:
# =============================================================================
# 
# STACK DE MONITORAMENTO COMPLETA:
# - Grafana: Plataforma de visualização e dashboards (porta 80)
# - Prometheus: Coleta de métricas modernas (porta 9090)
# - Alertmanager: Gerenciamento de alertas (porta 9093)
# - Zabbix Server: Monitoramento tradicional (porta 10051)
# - Zabbix Web: Interface web do Zabbix (porta 80)
# - MySQL: Banco de dados para Zabbix
#
# LOGS E TROUBLESHOOTING:
# - Log de execução: /var/log/user-data.log
# - Status do code-server: systemctl status code-server
# - Logs do code-server: journalctl -u code-server -f
# - Reiniciar code-server: systemctl restart code-server
# - Logs da stack: docker-compose logs -f
#
# ARQUIVOS DE CONFIGURAÇÃO:
# - Code-server config: /home/codeserver/.config/code-server/config.yaml (porta 8080)
# - Serviço systemd: /etc/systemd/system/code-server.service
# - Docker Compose: docker-compose.yml (após clone do repositório)
# - Prometheus config: prometheus.yml
# - Alertmanager config: alertmanager.yml
# - Alert rules: alert_rules.yml
#
# PORTAS UTILIZADAS:
# - 22: SSH
# - 80: Grafana web interface
# - 8080: Code-server
# - 8081: Zabbix web interface
# - 9090: Prometheus web interface
# - 9093: Alertmanager web interface
# - 10050: Zabbix Agent (comunicação com agentes)
# - 10051: Zabbix Server (recebe dados de agentes)
#
# INTEGRAÇÃO GRAFANA + PROMETHEUS + ZABBIX:
# 1. Grafana como frontend unificado para visualização
# 2. Prometheus para métricas modernas (containers, APIs, aplicações)
# 3. Zabbix para monitoramento tradicional (SNMP, agentes, infraestrutura)
# 4. Alertmanager para centralização de alertas de ambas as fontes
# 5. Dashboards combinando dados de múltiplas fontes de dados
#
# DATA SOURCES NO GRAFANA:
# - Prometheus: http://prometheus:9090
# - Zabbix: http://zabbix-web:8080/api_jsonrpc.php
# - Alertmanager: http://alertmanager:9093
#
# DASHBOARDS RECOMENDADOS:
# - Node Exporter Full (ID: 1860) - Para métricas do Prometheus
# - Docker Container & Host Metrics (ID: 179) - Para containers
# - Zabbix Server Dashboard (ID: 11663) - Para dados do Zabbix
# - Alertmanager Overview (ID: 9578) - Para alertas
#
# SEGURANÇA EM PRODUÇÃO:
# - Alterar senhas padrão (code-server: demo123, Grafana: admin123, Zabbix: zabbix)
# - Configurar HTTPS/SSL para todas as interfaces web
# - Restringir acesso por IP no Security Group
# - Usar autenticação mais robusta (LDAP, OAuth, etc.)
# - Configurar backup automático dos volumes Docker
#
# MONITORAMENTO DA PRÓPRIA STACK:
# - Métricas dos containers via cAdvisor
# - Métricas do Prometheus via self-monitoring
# - Métricas do Grafana via built-in metrics
# - Alertas para serviços down, alto uso de recursos, etc.
# =============================================================================