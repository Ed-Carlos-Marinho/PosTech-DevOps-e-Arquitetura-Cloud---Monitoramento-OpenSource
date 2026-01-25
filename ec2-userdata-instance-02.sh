#!/bin/bash

# =============================================================================
# CONFIGURAÇÃO DO IP DO SERVIDOR LOKI
# =============================================================================
# IMPORTANTE: Substitua o IP abaixo pelo IP PRIVADO da Instância 1 (Observabilidade)
# Exemplo: Se a Instância 1 tem IP privado 10.0.1.50, use:
# export LOKI_SERVER_IP="10.0.1.50"
# =============================================================================
export LOKI_SERVER_IP="10.0.1.100"

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
# - Configura Promtail para enviar logs ao Loki (se IP fornecido)
#
# =============================================================================
# CONFIGURAÇÃO AUTOMÁTICA DO IP DO LOKI:
# =============================================================================
# O script tenta obter o IP do servidor Loki automaticamente de 3 formas:
#
# OPÇÃO 1 - Variável de Ambiente (Recomendado):
# Adicione no início do userdata:
#   export LOKI_SERVER_IP="10.0.1.100"
#
# OPÇÃO 2 - Tag da Instância EC2:
# Adicione uma tag na instância com:
#   Key: LokiServerIP
#   Value: 10.0.1.100
#
# OPÇÃO 3 - SSM Parameter Store:
# Crie um parâmetro no Systems Manager:
#   aws ssm put-parameter --name "/observability/loki-server-ip" \
#     --value "10.0.1.100" --type String
#
# Se nenhuma opção for configurada, será necessário editar manualmente:
#   /home/ubuntu/PosTech/test-app/promtail-app-config.yml
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
curl -L "https://github.com/docker/compose/releases/download/v2.31.0/docker-compose-linux-x86_64" -o /usr/local/bin/docker-compose
chmod +x /usr/local/bin/docker-compose       # Torna executável
check_status "Instalação do Docker Compose"

# =============================================================================
# FASE 5: CLONAGEM DO REPOSITÓRIO
# =============================================================================

echo "📥 Clonando repositório..."
cd /home/ubuntu
git clone -b aula-04 https://github.com/Ed-Carlos-Marinho/PosTech-DevOps-e-Arquitetura-Cloud---Monitoramento-OpenSource.git PosTech
cd PosTech/test-app
chown -R ubuntu:ubuntu /home/ubuntu/PosTech
check_status "Clonagem do repositório"

# =============================================================================
# FASE 6: CONFIGURAÇÃO DO IP DO LOKI
# =============================================================================

echo "🔧 Configurando IP do servidor Loki..."

# Tentar obter IP do Loki de diferentes fontes (em ordem de prioridade):
# 1. Variável de ambiente LOKI_SERVER_IP (pode ser definida no userdata)
# 2. Tag da instância EC2 chamada "LokiServerIP"
# 3. Parameter Store do SSM
# 4. Deixar como LOKI_SERVER_IP para configuração manual

LOKI_IP=""

# Opção 1: Verificar variável de ambiente
if [ ! -z "$LOKI_SERVER_IP" ]; then
    LOKI_IP="$LOKI_SERVER_IP"
    echo "✅ IP do Loki obtido da variável de ambiente: $LOKI_IP"
fi

# Opção 2: Tentar obter de tag da instância EC2
if [ -z "$LOKI_IP" ]; then
    INSTANCE_ID=$(curl -s http://169.254.169.254/latest/meta-data/instance-id)
    REGION=$(curl -s http://169.254.169.254/latest/meta-data/placement/region)
    
    # Verificar se AWS CLI está disponível
    if command -v aws &> /dev/null; then
        LOKI_IP=$(aws ec2 describe-tags --region $REGION --filters "Name=resource-id,Values=$INSTANCE_ID" "Name=key,Values=LokiServerIP" --query 'Tags[0].Value' --output text 2>/dev/null)
        if [ ! -z "$LOKI_IP" ] && [ "$LOKI_IP" != "None" ]; then
            echo "✅ IP do Loki obtido da tag da instância: $LOKI_IP"
        else
            LOKI_IP=""
        fi
    fi
fi

# Opção 3: Tentar obter do Parameter Store
if [ -z "$LOKI_IP" ]; then
    if command -v aws &> /dev/null; then
        LOKI_IP=$(aws ssm get-parameter --name "/observability/loki-server-ip" --query 'Parameter.Value' --output text 2>/dev/null)
        if [ ! -z "$LOKI_IP" ] && [ "$LOKI_IP" != "None" ]; then
            echo "✅ IP do Loki obtido do Parameter Store: $LOKI_IP"
        else
            LOKI_IP=""
        fi
    fi
fi

# Aplicar configuração
if [ ! -z "$LOKI_IP" ]; then
    sed -i "s/LOKI_SERVER_IP/$LOKI_IP/g" promtail-app-config.yml
    echo "✅ Configuração do Promtail atualizada com IP do Loki: $LOKI_IP"
else
    echo "⚠️  IP do Loki não configurado automaticamente"
    echo "⚠️  Será necessário configurar manualmente após a inicialização"
    echo "⚠️  Edite: /home/ubuntu/PosTech/test-app/promtail-app-config.yml"
fi

# =============================================================================
# FASE 7: CONFIGURAÇÃO E INICIALIZAÇÃO DA STACK
# =============================================================================

echo "🚀 Iniciando stack de aplicação..."
# Iniciar stack usando docker-compose
sudo -u ubuntu docker-compose -f docker-compose-app.yml up -d
check_status "Inicialização da stack de aplicação"

# Aguardar aplicação estar pronta
echo "⏳ Aguardando aplicação iniciar..."
sleep 15

# Gerar tráfego inicial para criar logs
echo "🌐 Gerando tráfego inicial para criar logs..."
curl -s http://localhost/ > /dev/null 2>&1 || true
curl -s http://localhost/health > /dev/null 2>&1 || true
curl -s http://localhost/generate/20 > /dev/null 2>&1 || true
echo "✅ Tráfego inicial gerado"

# =============================================================================
# FASE 8: CONFIGURAÇÃO DO FIREWALL
# =============================================================================

echo "🔥 Configurando firewall..."
ufw --force enable                          # Habilita firewall (força sem prompt)
ufw allow ssh                               # Permite SSH (porta 22)
ufw allow http                              # Permite HTTP (porta 80) - para aplicação via Nginx
ufw allow 9080                              # Permite Promtail (métricas)
check_status "Configuração do firewall"

# =============================================================================
# FASE 9: VERIFICAÇÃO FINAL
# =============================================================================

echo "🔍 Verificando status dos serviços..."
# Verifica se serviços estão ativos e reporta status
systemctl is-active docker && echo "✅ Docker está rodando"
sudo -u ubuntu docker-compose -f /home/ubuntu/PosTech/test-app/docker-compose-app.yml ps

# =============================================================================
# FINALIZAÇÃO E INFORMAÇÕES DE ACESSO
# =============================================================================

# Capturar IP público da instância
PUBLIC_IP=$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4)

echo "=== ✅ Configuração da aplicação de teste concluída em $(date) ==="
echo ""
echo "🚀 Serviços instalados e configurados:"
echo "   - Aplicação de teste: http://${PUBLIC_IP}"
echo "   - Nginx (proxy): http://${PUBLIC_IP}"
echo "   - Promtail: http://${PUBLIC_IP}:9080/metrics"
echo ""
echo "⚠️  CONFIGURAÇÃO DO LOKI:"
if [ ! -z "$LOKI_IP" ]; then
    echo "   ✅ IP do Loki configurado automaticamente: $LOKI_IP"
    echo "   ✅ Promtail está enviando logs para o Loki"
else
    echo "   ⚠️  IP do Loki NÃO foi configurado automaticamente"
    echo "   📝 PASSOS MANUAIS NECESSÁRIOS:"
    echo "   1. Obter IP privado da instância de observabilidade (Instância 1)"
    echo "   2. Editar: /home/ubuntu/PosTech/test-app/promtail-app-config.yml"
    echo "   3. Substituir LOKI_SERVER_IP pelo IP real"
    echo "   4. Executar: cd /home/ubuntu/PosTech/test-app && docker-compose -f docker-compose-app.yml restart promtail"
fi
echo ""
echo "📝 FORMAS DE CONFIGURAR O IP DO LOKI AUTOMATICAMENTE:"
echo "   Opção 1: Definir variável de ambiente LOKI_SERVER_IP no userdata"
echo "   Opção 2: Adicionar tag 'LokiServerIP' na instância EC2"
echo "   Opção 3: Criar parâmetro '/observability/loki-server-ip' no SSM Parameter Store"
echo ""
echo "   5. Testar aplicação: curl http://localhost/"
echo "   6. Gerar logs: curl http://localhost/generate/100"
echo "   7. Verificar logs no Grafana via Loki"
echo ""
echo "🔧 Comandos úteis:"
echo "   - Testar aplicação: curl http://localhost/"
echo "   - Gerar logs: curl http://localhost/generate/50"
echo "   - Ver logs da stack: cd /home/ubuntu/PosTech/test-app && docker-compose -f docker-compose-app.yml logs -f"
echo "   - Status da stack: cd /home/ubuntu/PosTech/test-app && docker-compose -f docker-compose-app.yml ps"
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
# - Docker Compose: /home/ubuntu/PosTech/test-app/docker-compose-app.yml
# - Promtail config: /home/ubuntu/PosTech/test-app/promtail-app-config.yml
# - Nginx config: /home/ubuntu/PosTech/test-app/nginx.conf
# - Aplicação: /home/ubuntu/PosTech/test-app/test-app.py
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