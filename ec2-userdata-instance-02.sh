#!/bin/bash

# =============================================================================
# EC2 USER DATA SCRIPT - TEST APPLICATION SETUP
# =============================================================================
# Script de configuração automática para instância de aplicação de teste (Instância 2)
# Aula 04 - PosTech DevOps e Arquitetura Cloud - Monitoramento OpenSource
# 
# Este script instala e configura automaticamente:
# - Docker e Docker Compose
# - Clona repositório com aplicação de teste
# - Inicia stack de aplicação via Docker Compose
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
echo "=== Iniciando configuração da aplicação de teste em $(date) ==="

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
apt-get install -y curl wget htop docker.io git # Instala ferramentas essenciais
# curl/wget: Clientes HTTP para downloads
# htop: Monitor de processos interativo
# docker.io: Para containers
# git: Para clonar repositório
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
# Download da versão específica para arquitetura AMD64 (t3.small)
curl -L "https://github.com/docker/compose/releases/download/v2.24.5/docker-compose-linux-x86_64" -o /usr/local/bin/docker-compose
chmod +x /usr/local/bin/docker-compose       # Torna executável
check_status "Instalação do Docker Compose"

# =============================================================================
# FASE 5: CLONAGEM DO REPOSITÓRIO
# =============================================================================

echo "📥 Clonando repositório..."
cd /home/ubuntu
git clone -b aula-04 https://github.com/Ed-Carlos-Marinho/PosTech-DevOps-e-Arquitetura-Cloud---Monitoramento-OpenSource.git repo
cd repo/test-app
chown -R ubuntu:ubuntu /home/ubuntu/repo
check_status "Clonagem do repositório"

# =============================================================================
# FASE 6: CONFIGURAÇÃO E INICIALIZAÇÃO DA STACK
# =============================================================================

echo "🚀 Iniciando stack de aplicação..."
# Iniciar stack usando docker-compose
sudo -u ubuntu docker-compose -f docker-compose-app.yml up -d
check_status "Inicialização da stack de aplicação"

# =============================================================================
# FASE 7: CONFIGURAÇÃO DO FIREWALL
# =============================================================================

echo "🔥 Configurando firewall..."
ufw --force enable                          # Habilita firewall (força sem prompt)
ufw allow ssh                               # Permite SSH (porta 22)
ufw allow http                              # Permite HTTP (porta 80) - para aplicação via Nginx
ufw allow 9080                              # Permite Promtail (métricas)
check_status "Configuração do firewall"

# =============================================================================
# FASE 8: VERIFICAÇÃO FINAL
# =============================================================================

echo "🔍 Verificando status dos serviços..."
# Verifica se serviços estão ativos e reporta status
systemctl is-active docker && echo "✅ Docker está rodando"
sudo -u ubuntu docker-compose -f /home/ubuntu/repo/test-app/docker-compose-app.yml ps

# =============================================================================
# FINALIZAÇÃO E INFORMAÇÕES DE ACESSO
# =============================================================================

echo "=== ✅ Configuração da aplicação de teste concluída em $(date) ==="
echo ""
echo "🚀 Serviços instalados e configurados:"
echo "   - Aplicação de teste: http://$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4)"
echo "   - Nginx (proxy): http://$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4)"
echo "   - Promtail: http://$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4):9080/metrics"
echo ""
echo "⚠️  PRÓXIMOS PASSOS MANUAIS:"
echo "   1. Obter IP privado da instância de observabilidade (Instância 1)"
echo "   2. Editar: /home/ubuntu/repo/test-app/promtail-app-config.yml"
echo "   3. Substituir LOKI_SERVER_IP pelo IP real"
echo "   4. Executar: cd /home/ubuntu/repo/test-app && docker-compose -f docker-compose-app.yml restart promtail"
echo "   5. Testar aplicação: curl http://localhost/"
echo "   6. Gerar logs: curl http://localhost/generate/100"
echo "   7. Verificar logs no Grafana via Loki"
echo ""
echo "🔧 Comandos úteis:"
echo "   - Testar aplicação: curl http://localhost/"
echo "   - Gerar logs: curl http://localhost/generate/50"
echo "   - Ver logs da stack: cd /home/ubuntu/repo/test-app && docker-compose -f docker-compose-app.yml logs -f"
echo "   - Status da stack: cd /home/ubuntu/repo/test-app && docker-compose -f docker-compose-app.yml ps"
echo "   - Verificar Promtail: curl http://localhost:9080/metrics"
echo "   - Logs de instalação: sudo tail -f /var/log/user-data.log"

# =============================================================================
# INFORMAÇÕES IMPORTANTES PARA MANUTENÇÃO:
# =============================================================================
# 
# LOGS E TROUBLESHOOTING:
# - Log de execução: /var/log/user-data.log
# - Logs da stack: docker-compose -f docker-compose-app.yml logs
# - Logs específicos: docker-compose -f docker-compose-app.yml logs [service]
#
# ARQUIVOS DE CONFIGURAÇÃO:
# - Docker Compose: /home/ubuntu/repo/test-app/docker-compose-app.yml
# - Promtail config: /home/ubuntu/repo/test-app/promtail-app-config.yml
# - Nginx config: /home/ubuntu/repo/test-app/nginx.conf
# - Aplicação: /home/ubuntu/repo/test-app/test-app.py
#
# PORTAS UTILIZADAS:
# - 22: SSH
# - 80: HTTP (Nginx + Aplicação)
# - 5000: Aplicação Python (interno)
# - 9080: Promtail (métricas)
#
# COMANDOS DE MANUTENÇÃO:
# - Reiniciar stack: docker-compose -f docker-compose-app.yml restart
# - Parar stack: docker-compose -f docker-compose-app.yml down
# - Iniciar stack: docker-compose -f docker-compose-app.yml up -d
# - Ver logs: docker-compose -f docker-compose-app.yml logs -f
# - Status: docker-compose -f docker-compose-app.yml ps
#
# CONFIGURAÇÃO FINAL NECESSÁRIA:
# 1. Substituir LOKI_SERVER_IP pelo IP real da instância 1 em promtail-app-config.yml
# 2. Verificar coleta de logs no Grafana
# 3. Testar geração de logs da aplicação
#
# ENDPOINTS DA APLICAÇÃO:
# - GET /: Página inicial com estatísticas
# - GET /generate/<count>: Gera <count> logs de teste
# - GET /health: Status da aplicação
# - GET /stress: Gera logs por 30 segundos
# - GET /error: Força um erro para teste
# =============================================================================