#!/bin/bash

# User Data simples para demo - Ubuntu
echo "Iniciando configuração da demo..." > /var/log/user-data.log

# Atualizar sistema
apt-get update -y

# Instalar pacotes básicos
apt-get install -y \
    git \
    curl \
    htop \
    docker.io

# Configurar Docker
systemctl start docker
systemctl enable docker
usermod -a -G docker ubuntu

# Instalar Docker Compose
curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
chmod +x /usr/local/bin/docker-compose

# Instalar code-server
curl -fsSL https://code-server.dev/install.sh | sh

# Configurar code-server
mkdir -p /home/ubuntu/.config/code-server
cat > /home/ubuntu/.config/code-server/config.yaml << 'EOF'
bind-addr: 0.0.0.0:80
auth: password
password: demo123
cert: false
EOF

chown -R ubuntu:ubuntu /home/ubuntu/.config

# Dar permissão para usar porta 80
setcap 'cap_net_bind_service=+ep' /usr/bin/code-server

# Criar serviço systemd para code-server
cat > /etc/systemd/system/code-server.service << 'EOF'
[Unit]
Description=code-server
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=/home/ubuntu
Environment=HOME=/home/ubuntu
ExecStart=/usr/bin/code-server --config /home/ubuntu/.config/code-server/config.yaml
Restart=always

[Install]
WantedBy=multi-user.target
EOF

# Iniciar code-server
systemctl daemon-reload
systemctl enable code-server
systemctl start code-server

# Configurar firewall básico
ufw --force enable
ufw allow ssh
ufw allow http

# Finalizar
echo "Demo configurada com sucesso em $(date)" >> /var/log/user-data.log