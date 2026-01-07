#!/bin/bash

# =============================================================================
# EC2 USER DATA SCRIPT - AUTOMATED SETUP
# =============================================================================
# Script de configuração automática para instâncias EC2 Ubuntu
# Aula 01 - PosTech DevOps e Arquitetura Cloud - Monitoramento OpenSource
# 
# Este script instala e configura automaticamente:
# - Docker e Docker Compose
# - Code-server (VS Code no navegador)
# - Configurações básicas de segurança
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
# Download da versão específica para arquitetura ARM64 (t4g.medium)
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
# FASE 6: CONFIGURAÇÃO DO CODE-SERVER
# =============================================================================

echo "⚙️ Configurando code-server..."
# Cria diretório de configuração para o usuário ubuntu
mkdir -p /home/ubuntu/.config/code-server

# Cria arquivo de configuração do code-server
cat > /home/ubuntu/.config/code-server/config.yaml << 'EOF'
bind-addr: 0.0.0.0:8080                     # Escuta em todas interfaces na porta 8080
auth: password                              # Usa autenticação por senha
password: demo123                           # Senha de acesso (ALTERAR EM PRODUÇÃO)
cert: false                                 # Desabilita HTTPS (usar proxy reverso em produção)
EOF

# Define propriedade correta dos arquivos de configuração
chown -R ubuntu:ubuntu /home/ubuntu/.config
check_status "Configuração do code-server"

# =============================================================================
# FASE 7: CRIAÇÃO DO SERVIÇO SYSTEMD
# =============================================================================

echo "🔧 Criando serviço systemd..."
# Cria arquivo de serviço para gerenciar code-server via systemd
cat > /etc/systemd/system/code-server.service << 'EOF'
[Unit]
Description=code-server                     # Descrição do serviço
After=network.target                        # Inicia após rede estar disponível

[Service]
Type=simple                                 # Tipo de serviço simples
User=ubuntu                                 # Executa como usuário ubuntu
Group=ubuntu                                # Executa como grupo ubuntu
WorkingDirectory=/home/ubuntu               # Diretório de trabalho
Environment=HOME=/home/ubuntu               # Define HOME para o usuário
ExecStart=/usr/bin/code-server --config /home/ubuntu/.config/code-server/config.yaml
Restart=always                             # Reinicia automaticamente se falhar
RestartSec=10                               # Aguarda 10s antes de reiniciar

[Install]
WantedBy=multi-user.target                  # Inicia no boot do sistema
EOF

# =============================================================================
# FASE 8: INICIALIZAÇÃO DO CODE-SERVER
# =============================================================================

echo "🚀 Iniciando code-server..."
systemctl daemon-reload                     # Recarrega configurações do systemd
systemctl enable code-server                # Habilita para iniciar com sistema
systemctl start code-server                 # Inicia o serviço
check_status "Inicialização do code-server"

# =============================================================================
# FASE 9: CONFIGURAÇÃO DO FIREWALL
# =============================================================================

echo "🔥 Configurando firewall..."
ufw --force enable                          # Habilita firewall (força sem prompt)
ufw allow ssh                               # Permite SSH (porta 22)
ufw allow http                              # Permite HTTP (porta 80) - para Zabbix
ufw allow 8080                              # Permite porta 8080 - para code-server
check_status "Configuração do firewall"

# =============================================================================
# FASE 10: VERIFICAÇÃO FINAL
# =============================================================================

echo "🔍 Verificando status dos serviços..."
# Verifica se serviços estão ativos e reporta status
systemctl is-active docker && echo "✅ Docker está rodando"
systemctl is-active code-server && echo "✅ Code-server está rodando"

# =============================================================================
# FINALIZAÇÃO E INFORMAÇÕES DE ACESSO
# =============================================================================

echo "=== ✅ Configuração concluída com sucesso em $(date) ==="
echo "🌐 Code-server disponível em: http://$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4):8080"
echo "🔑 Senha: demo123"
echo "🐳 Docker e Docker Compose instalados e configurados"

# =============================================================================
# INFORMAÇÕES IMPORTANTES PARA MANUTENÇÃO:
# =============================================================================
# 
# LOGS E TROUBLESHOOTING:
# - Log de execução: /var/log/user-data.log
# - Status do code-server: systemctl status code-server
# - Logs do code-server: journalctl -u code-server -f
# - Reiniciar code-server: systemctl restart code-server
#
# ARQUIVOS DE CONFIGURAÇÃO:
# - Code-server config: /home/ubuntu/.config/code-server/config.yaml
# - Serviço systemd: /etc/systemd/system/code-server.service
#
# PORTAS UTILIZADAS:
# - 22: SSH
# - 80: HTTP (Zabbix web interface)
# - 8080: Code-server
# - 10050: Zabbix Agent (se configurado)
# - 10051: Zabbix Server (se configurado)
#
# SEGURANÇA EM PRODUÇÃO:
# - Alterar senha padrão do code-server (demo123)
# - Configurar HTTPS/SSL para code-server
# - Restringir acesso por IP no Security Group
# - Usar autenticação mais robusta (OAuth, etc.)
#
# CUSTOMIZAÇÕES POSSÍVEIS:
# - Alterar porta do code-server (modificar config.yaml e firewall)
# - Instalar extensões específicas do VS Code
# - Configurar workspace padrão
# - Adicionar usuários adicionais
# =============================================================================