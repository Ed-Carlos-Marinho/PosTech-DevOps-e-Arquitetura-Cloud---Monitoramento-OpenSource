# EC2 User Data Script

Script de configuração automática para instâncias EC2 Ubuntu usado na Aula 01 do módulo Monitoramento OpenSource.

## O que o script faz

### Instalações
- **Git, curl, htop**: Ferramentas básicas
- **Docker**: Plataforma de containerização
- **Docker Compose**: Orquestração de containers (versão específica ARM64)
- **Code-server**: VS Code no navegador

### Configurações
- **Code-server**: Porta 3000, senha "demo123"
- **Docker**: Configurado para usuário ubuntu
- **Firewall**: SSH e porta 3000 liberados
- **Serviço**: Code-server como systemd service

## Como usar

### 1. No Console AWS
1. Criar nova instância EC2 Ubuntu
2. Em "Advanced Details" → "User data"
3. Colar o conteúdo do arquivo `ec2-userdata-demo.sh`
4. Finalizar criação da instância

### 2. Via AWS CLI
```bash
aws ec2 run-instances \
  --image-id ami-xxxxxxxxx \
  --instance-type t3.micro \
  --key-name sua-chave \
  --security-group-ids sg-xxxxxxxxx \
  --user-data file://ec2-userdata-demo.sh
```

### 3. Via Terraform
```hcl
resource "aws_instance" "demo" {
  ami           = "ami-xxxxxxxxx"
  instance_type = "t3.micro"
  key_name      = "sua-chave"
  
  user_data = file("${path.module}/ec2-userdata-demo.sh")
}
```

## Verificação

### Logs de execução
```bash
# Ver logs do user data
sudo tail -f /var/log/user-data.log

# Status do code-server
sudo systemctl status code-server
```

### Acesso
- **Code-server**: `http://SEU_IP:3000`
- **Usuário**: Acesso direto
- **Senha**: `demo123`

## Troubleshooting

### Code-server não inicia
```bash
# Verificar logs
sudo journalctl -u code-server -f

# Reiniciar serviço
sudo systemctl restart code-server
```

### Docker não funciona
```bash
# Verificar status
sudo systemctl status docker

# Testar Docker
docker --version
docker-compose --version
```

## Security Groups

Certifique-se de que o Security Group permite:
- **SSH (22)**: Para acesso via terminal
- **HTTP (80)**: Para interface web do Zabbix
- **3000**: Para code-server
- **10051**: Para Zabbix Server (entre instâncias)
- **10050**: Para Zabbix Agent (entre instâncias)