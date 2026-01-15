#!/bin/bash

# =============================================================================
# EC2 USER DATA SCRIPT - EKS BASTION INSTANCE
# =============================================================================
# Aula 07 - PosTech DevOps - Observabilidade no Kubernetes
# Stack: kubectl + helm + AWS CLI + code-server para acesso ao EKS
# =============================================================================

# Configurações de ambiente
export HOME=/root
export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

# Logs de execução
exec > >(tee /var/log/user-data.log) 2>&1
echo "=== Iniciando configuração do bastion EKS em $(date) ==="

# Função de verificação
check_status() {
    if [ $? -eq 0 ]; then
        echo "✅ $1 - Sucesso"
    else
        echo "❌ $1 - Falhou"
        exit 1
    fi
}

# =============================================================================
# FASE 1: ATUALIZAÇÃO DO SISTEMA
# =============================================================================

echo "📦 Atualizando sistema..."
apt-get update -y
check_status "Atualização do sistema"

# =============================================================================
# FASE 2: INSTALAÇÃO DE PACOTES BÁSICOS
# =============================================================================

echo "📦 Instalando pacotes básicos..."
apt-get install -y curl wget htop git unzip jq tree vim nano
check_status "Instalação de pacotes básicos"

# =============================================================================
# FASE 3: INSTALAÇÃO DO AWS CLI V2
# =============================================================================

echo "☁️ Instalando AWS CLI v2..."
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
sudo ./aws/install
rm -rf aws awscliv2.zip
check_status "Instalação do AWS CLI v2"

# Verificar instalação
aws --version

# =============================================================================
# FASE 4: INSTALAÇÃO DO KUBECTL
# =============================================================================

echo "⚙️ Instalando kubectl..."
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
rm kubectl
check_status "Instalação do kubectl"

# Verificar instalação
kubectl version --client

# =============================================================================
# FASE 5: INSTALAÇÃO DO HELM
# =============================================================================

echo "📦 Instalando Helm..."
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
check_status "Instalação do Helm"

# Verificar instalação
helm version

# =============================================================================
# FASE 6: INSTALAÇÃO DO K9S
# =============================================================================

echo "🎯 Instalando k9s..."
curl -sS https://webinstall.dev/k9s | bash
sudo mv ~/.local/bin/k9s /usr/local/bin/
check_status "Instalação do k9s"

# Verificar instalação
k9s version

# =============================================================================
# FASE 7: INSTALAÇÃO DO CODE-SERVER
# =============================================================================

echo "💻 Instalando code-server..."
curl -fsSL https://code-server.dev/install.sh | sh
check_status "Instalação do code-server"

# Criação de usuário para code-server
echo "👤 Configurando usuário para code-server..."
useradd -m -s /bin/bash -c "Code Server User" codeserver
mkdir -p /home/codeserver/.config/code-server

cat > /home/codeserver/.config/code-server/config.yaml << 'EOF'
bind-addr: 0.0.0.0:8080
auth: password
password: demo123
cert: false
EOF

chown -R codeserver:codeserver /home/codeserver/.config
check_status "Configuração do code-server"

# Criação do serviço systemd
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

systemctl daemon-reload
systemctl enable code-server
systemctl start code-server
check_status "Inicialização do code-server"

# =============================================================================
# FASE 8: CONFIGURAÇÃO DE ALIASES E FERRAMENTAS
# =============================================================================

echo "🔧 Configurando aliases e ferramentas..."

# Aliases úteis para kubectl
cat >> /home/ubuntu/.bashrc << 'EOF'

# Kubernetes aliases
alias k='kubectl'
alias kgp='kubectl get pods'
alias kgs='kubectl get svc'
alias kgn='kubectl get nodes'
alias kga='kubectl get all'
alias kdp='kubectl describe pod'
alias kds='kubectl describe svc'
alias kl='kubectl logs'
alias kaf='kubectl apply -f'
alias kdf='kubectl delete -f'

# Helm aliases
alias h='helm'
alias hls='helm list'
alias hla='helm list -A'
alias hs='helm status'

# Alias para k9s
alias k9='k9s'

# Navegação rápida
alias ll='ls -alF'
alias la='ls -A'
alias l='ls -CF'
EOF

# Copiar aliases para o usuário codeserver também
cp /home/ubuntu/.bashrc /home/codeserver/.bashrc
chown codeserver:codeserver /home/codeserver/.bashrc

check_status "Configuração de aliases"

# =============================================================================
# FASE 9: CONFIGURAÇÃO DO FIREWALL
# =============================================================================

echo "🔥 Configurando firewall..."
ufw --force enable
ufw allow ssh                               # SSH (porta 22)
ufw allow 8080                              # Code-server
ufw allow out 443                           # HTTPS outbound
ufw allow out 80                            # HTTP outbound
check_status "Configuração do firewall"

# =============================================================================
# VERIFICAÇÃO FINAL
# =============================================================================

echo "🔍 Verificando status dos serviços..."
systemctl is-active code-server && echo "✅ Code-server está rodando"

# Verificar versões das ferramentas
echo "📋 Versões das ferramentas instaladas:"
aws --version
kubectl version --client
helm version --short
k9s version

# =============================================================================
# FINALIZAÇÃO
# =============================================================================

echo "=== ✅ Configuração do bastion EKS concluída em $(date) ==="
echo ""
echo "🎯 AULA 07 - BASTION PARA OBSERVABILIDADE NO KUBERNETES"
echo "======================================================="
echo "🌐 Code-server disponível em: http://$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4):8080"
echo "🔑 Senha: demo123"
echo ""
echo "📊 PRÓXIMOS PASSOS PARA AULA 07:"
echo "1. Configurar acesso ao EKS manualmente com: aws eks update-kubeconfig --region us-east-2 --name <cluster-name>"
echo "2. Verificar acesso: kubectl get nodes"
echo "3. Instalar repositórios Helm conforme necessário"
echo "4. Executar exercícios de observabilidade"
echo ""
echo "🔧 Ferramentas instaladas:"
echo "   - AWS CLI v2 (para acesso aos serviços AWS)"
echo "   - kubectl (cliente Kubernetes)"
echo "   - helm (gerenciador de pacotes K8s)"
echo "   - k9s (interface TUI para Kubernetes)"
echo "   - code-server (VS Code no navegador)"
echo ""
echo "🚀 Sistema pronto para laboratório de observabilidade no Kubernetes!"

# =============================================================================
# INFORMAÇÕES IMPORTANTES:
# 
# ACESSO:
# - SSH: ssh -i key.pem ubuntu@IP
# - Session Manager: aws ssm start-session --target INSTANCE_ID
# - Code-server: http://IP:8080 (senha: demo123)
#
# CONFIGURAÇÃO EKS:
# - Execute: aws eks update-kubeconfig --region <region> --name <cluster-name>
# - Exemplo: aws eks update-kubeconfig --region us-east-2 --name my-cluster
#
# COMANDOS ÚTEIS:
# - Verificar cluster: kubectl get nodes
# - Listar pods: kubectl get pods -A
# - Adicionar repos Helm conforme necessário
#
# FERRAMENTAS DISPONÍVEIS:
# - AWS CLI v2, kubectl, helm, k9s, code-server
# =============================================================================