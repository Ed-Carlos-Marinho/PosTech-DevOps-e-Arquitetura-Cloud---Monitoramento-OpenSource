#!/bin/bash

# =============================================================================
# EC2 USER DATA SCRIPT - OBSERVABILITY INSTANCE
# =============================================================================
# Script de configuração automática para instâncias EC2 Ubuntu
# Aula 04 - PosTech DevOps e Arquitetura Cloud - Monitoramento OpenSource
# 
# OBJETIVO DA AULA 04:
# Implementar observabilidade completa com logs centralizados usando Loki,
# correlação entre métricas e logs, e dashboards unificados no Grafana.
#
# Este script instala e configura automaticamente:
# - Docker e Docker Compose (para stack de observabilidade)
# - Code-server (VS Code no navegador) para desenvolvimento
# - Stack Grafana + Prometheus + Loki + Promtail
# - Configurações básicas de segurança
# - Preparação para coleta de logs centralizados
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
ufw allow 9090                              # Permite porta 9090 - para Prometheus
ufw allow 3100                              # Permite porta 3100 - para Loki API
ufw allow 8080                              # Permite porta 8080 - para code-server
ufw allow 9080                              # Permite porta 9080 - para Promtail metrics
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
echo "🎯 AULA 04 - STACK DE OBSERVABILIDADE PREPARADA"
echo "=============================================="
echo "🌐 Code-server disponível em: http://$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4):8080"
echo "🔑 Senha: demo123"
echo ""
echo "📊 PRÓXIMOS PASSOS PARA AULA 04:"
echo "1. Clonar repositório: git clone -b aula-04 https://github.com/Ed-Carlos-Marinho/PosTech-DevOps-e-Arquitetura-Cloud---Monitoramento-OpenSource.git"
echo "2. Executar stack de observabilidade: docker-compose -f docker-compose-observability.yml up -d"
echo "3. Acessar interfaces:"
echo "   - Grafana: http://$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4):80 (admin/admin123)"
echo "   - Prometheus: http://$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4):9090"
echo "   - Loki API: http://$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4):3100"
echo "   - Promtail Metrics: http://$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4):9080/metrics"
echo ""
echo "🐳 Docker e Docker Compose instalados e configurados"
echo "🔧 Sistema pronto para observabilidade completa com logs centralizados"

# =============================================================================
# INFORMAÇÕES IMPORTANTES PARA AULA 04:
# =============================================================================
# 
# STACK DE OBSERVABILIDADE COMPLETA:
# - Grafana: Plataforma de visualização unificada (logs + métricas) (porta 80)
# - Prometheus: Coleta de métricas modernas (porta 9090)
# - Loki: Sistema de agregação de logs centralizados (porta 3100)
# - Promtail: Agente de coleta de logs (métricas na porta 9080)
#
# LOGS E TROUBLESHOOTING:
# - Log de execução: /var/log/user-data.log
# - Status do code-server: systemctl status code-server
# - Logs do code-server: journalctl -u code-server -f
# - Reiniciar code-server: systemctl restart code-server
# - Logs da stack: docker-compose -f docker-compose-observability.yml logs -f
#
# ARQUIVOS DE CONFIGURAÇÃO:
# - Code-server config: /home/codeserver/.config/code-server/config.yaml (porta 8080)
# - Serviço systemd: /etc/systemd/system/code-server.service
# - Docker Compose: docker-compose-observability.yml
# - Prometheus config: prometheus.yml
# - Loki config: loki-config.yml
# - Promtail config: promtail-config.yml
#
# PORTAS UTILIZADAS:
# - 22: SSH
# - 80: Grafana web interface
# - 8080: Code-server
# - 9090: Prometheus web interface
# - 3100: Loki API (HTTP)
# - 9096: Loki gRPC (interno)
# - 9080: Promtail metrics endpoint
#
# INTEGRAÇÃO GRAFANA + PROMETHEUS + LOKI:
# 1. Grafana como frontend unificado para logs e métricas
# 2. Prometheus para métricas (próprio Prometheus, Promtail, Loki)
# 3. Loki para logs centralizados (sistema, aplicações, containers)
# 4. Promtail para coleta automática de logs
# 5. Dashboards combinando logs e métricas com correlação temporal
# 6. Consultas LogQL para análise de logs estruturados
#
# DATA SOURCES NO GRAFANA:
# - Prometheus: http://prometheus:9090
# - Loki: http://loki:3100
#
# DASHBOARDS RECOMENDADOS:
# - Node Exporter Full (ID: 1860) - Para métricas do Prometheus
# - Loki Stack Monitoring (ID: 14055) - Para monitoramento do Loki
# - Promtail (ID: 15141) - Para monitoramento do Promtail
# - Logs App (built-in do Grafana) - Para exploração de logs
#
# CONSULTAS LOGQL BÁSICAS:
# - {job="syslog"}: Todos os logs do sistema
# - {job="docker-observability"}: Logs dos containers
# - {job="syslog"} |= "error": Logs contendo "error"
# - rate({job="syslog"}[5m]): Taxa de logs por segundo
# - {service="grafana"}: Logs específicos do Grafana
#
# CORRELAÇÃO LOGS + MÉTRICAS:
# - Use split view no Grafana para correlacionar eventos
# - Dashboards com painéis de logs e métricas sincronizados
# - Alertas baseados em logs usando LogQL
# - Análise de causa raiz combinando ambas as fontes
#
# SEGURANÇA EM PRODUÇÃO:
# - Alterar senhas padrão (code-server: demo123, Grafana: admin123)
# - Configurar HTTPS/SSL para todas as interfaces web
# - Restringir acesso por IP no Security Group
# - Usar autenticação mais robusta (LDAP, OAuth, etc.)
# - Configurar backup automático dos volumes Docker
# - Habilitar auth_enabled no Loki para multi-tenancy
#
# MONITORAMENTO DA PRÓPRIA STACK:
# - Métricas dos containers via cAdvisor
# - Métricas do Prometheus via self-monitoring
# - Métricas do Grafana via built-in metrics
# - Métricas do Loki via /metrics endpoint
# - Métricas do Promtail via porta 9080
# - Alertas para serviços down, alto uso de recursos, etc.
#
# OTIMIZAÇÕES PARA PRODUÇÃO:
# - Configurar retenção adequada no Loki (retention_period)
# - Ajustar limites de ingestão conforme volume de logs
# - Usar armazenamento distribuído (S3, GCS) para Loki
# - Configurar compactação automática de dados antigos
# - Implementar sharding para alta disponibilidade
# - Monitorar performance das consultas LogQL
# =============================================================================