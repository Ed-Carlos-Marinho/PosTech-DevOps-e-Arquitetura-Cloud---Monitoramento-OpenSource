#!/bin/bash

# User Data para demo - Ubuntu
export HOME=/root
export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

exec > >(tee /var/log/user-data.log) 2>&1
echo "=== Iniciando configuração da demo em $(date) ==="

# Função para verificar se comando foi executado com sucesso
check_status() {
    if [ $? -eq 0 ]; then
        echo "✅ $1 - Sucesso"
    else
        echo "❌ $1 - Falhou"
        exit 1
    fi
}

# Atualizar sistema
echo "📦 Atualizando sistema..."
apt-get update -y
check_status "Atualização do sistema"

# Instalar pacotes básicos
echo "📦 Instalando pacotes básicos..."
apt-get install -y git curl htop docker.io
check_status "Instalação de pacotes básicos"

# Configurar Docker
echo "🐳 Configurando Docker..."
systemctl start docker
systemctl enable docker
usermod -a -G docker ubuntu
check_status "Configuração do Docker"

# Instalar Docker Compose
echo "🐳 Instalando Docker Compose..."
curl -L "https://github.com/docker/compose/releases/download/v2.24.5/docker-compose-linux-aarch64" -o /usr/local/bin/docker-compose
chmod +x /usr/local/bin/docker-compose
check_status "Instalação do Docker Compose"

# Instalar code-server
echo "💻 Instalando code-server..."
curl -fsSL https://code-server.dev/install.sh | sh
check_status "Instalação do code-server"

# Aguardar e verificar instalação
sleep 3
if [ ! -f /usr/bin/code-server ]; then
    echo "❌ Code-server não foi instalado corretamente"
    exit 1
fi

# Configurar code-server
echo "⚙️ Configurando code-server..."
mkdir -p /home/ubuntu/.config/code-server
cat > /home/ubuntu/.config/code-server/config.yaml << 'EOF'
bind-addr: 0.0.0.0:8080
auth: password
password: demo123
cert: false
EOF

chown -R ubuntu:ubuntu /home/ubuntu/.config
check_status "Configuração do code-server"

# Criar serviço systemd para code-server
echo "🔧 Criando serviço systemd..."
cat > /etc/systemd/system/code-server.service << 'EOF'
[Unit]
Description=code-server
After=network.target

[Service]
Type=simple
User=ubuntu
Group=ubuntu
WorkingDirectory=/home/ubuntu
Environment=HOME=/home/ubuntu
ExecStart=/usr/bin/code-server --config /home/ubuntu/.config/code-server/config.yaml
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

# Iniciar code-server
systemctl daemon-reload
systemctl enable code-server
systemctl start code-server
check_status "Inicialização do code-server"

# Configurar firewall
echo "🔥 Configurando firewall..."
ufw --force enable
ufw allow ssh
ufw allow http
ufw allow 8080
check_status "Configuração do firewall"

# Verificar status dos serviços
echo "🔍 Verificando status dos serviços..."
systemctl is-active docker && echo "✅ Docker está rodando"
systemctl is-active code-server && echo "✅ Code-server está rodando"

# Finalizar
echo "=== ✅ Configuração concluída com sucesso em $(date) ==="
echo "🌐 Code-server disponível em: http://$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4):8080"
echo "🔑 Senha: demo123"
echo "🐳 Docker e Docker Compose instalados e configurados"