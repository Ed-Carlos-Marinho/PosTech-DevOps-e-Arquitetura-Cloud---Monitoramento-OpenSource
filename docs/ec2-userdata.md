# EC2 User Data Scripts

Scripts de configuração automática para instâncias EC2 Ubuntu usados na Aula 04 do módulo Monitoramento OpenSource.

## Scripts Disponíveis

### ec2-userdata-instance-01.sh
Script para a **Instância de Observabilidade** (t4g.medium - ARM64):
- Docker e Docker Compose
- Code-server (VS Code no navegador) na porta 8080
- Configurações básicas de segurança
- Preparação para stack de observabilidade (Grafana + Loki + Prometheus)

### ec2-userdata-instance-02.sh  
Script para a **Instância de Aplicação de Teste** (t3.small - AMD64):
- Docker e Docker Compose
- Clonagem automática do repositório
- Inicialização da stack de aplicação de teste
- Configurações de firewall

## O que cada script faz

### Instância 01 (Observabilidade)
**Instalações:**
- Git, curl, htop: Ferramentas básicas
- Docker: Plataforma de containerização  
- Docker Compose: Orquestração de containers
- Code-server: VS Code no navegador

**Configurações:**
- Code-server: Porta 8080, senha "demo123"
- Docker: Configurado para usuário ubuntu
- Firewall: SSH, HTTP e porta 8080 liberados
- Serviço: Code-server como systemd service

### Instância 02 (Monitorada)
**Instalações:**
- Node Exporter: Métricas do sistema operacional
- cAdvisor: Métricas de containers Docker
### Instância 02 (Aplicação de Teste)
**Instalações:**
- Git, curl, htop: Ferramentas básicas
- Docker: Plataforma de containerização
- Docker Compose: Orquestração de containers
- Clonagem automática do repositório

**Componentes da aplicação:**
- Aplicação Flask: Gera logs abundantes
- Nginx: Proxy reverso e logs de acesso
- Promtail: Coleta de logs para Loki
- Log Generator: Gerador adicional de logs

**Configurações:**
- Aplicação Flask: Porta 5000 (interna)
- Nginx: Porta 80 (externa)
- Promtail: Porta 9080 (métricas)
- Firewall: SSH, HTTP e porta do Promtail liberadas

## Como usar

## Como usar

### 1. No Console AWS

#### Para Instância 01 (Observabilidade)
1. Criar nova instância EC2 Ubuntu 24.04 LTS
2. Instance type: **t4g.medium** (ARM64)
3. Em "Advanced Details" → "User data"
4. Colar o conteúdo do arquivo `ec2-userdata-instance-01.sh`
5. Finalizar criação da instância

#### Para Instância 02 (Aplicação de Teste)  
1. Criar nova instância EC2 Ubuntu 24.04 LTS
2. Instance type: **t3.small** (AMD64)
3. Em "Advanced Details" → "User data"
4. Colar o conteúdo do arquivo `ec2-userdata-instance-02.sh`
5. Finalizar criação da instância

### 2. Via AWS CLI

#### Instância 01 (Observabilidade)
```bash
aws ec2 run-instances \
  --image-id ami-0c7217cdde317cfec \
  --instance-type t4g.medium \
  --key-name sua-chave \
  --security-group-ids sg-xxxxxxxxx \
  --user-data file://ec2-userdata-instance-01.sh \
  --tag-specifications 'ResourceType=instance,Tags=[{Key=Name,Value=loki-observability-server}]'
```

#### Instância 02 (Aplicação de Teste)
```bash
aws ec2 run-instances \
  --image-id ami-0c7217cdde317cfec \
  --instance-type t3.small \
  --key-name sua-chave \
  --security-group-ids sg-yyyyyyyyy \
  --user-data file://ec2-userdata-instance-02.sh \
  --tag-specifications 'ResourceType=instance,Tags=[{Key=Name,Value=test-app-server}]'
```

#### Instância 02 (Monitorada)
```bash
aws ec2 run-instances \
  --image-id ami-0c7217cdde317cfec \
  --instance-type t3.small \
  --key-name sua-chave \
  --security-group-ids sg-yyyyyyyyy \
  --user-data file://ec2-userdata-instance-02.sh \
  --tag-specifications 'ResourceType=instance,Tags=[{Key=Name,Value=monitored-host-01}]'
```

### 3. Via Terraform

#### Instância 01 (Monitoramento)
```hcl
resource "aws_instance" "monitoring_server" {
  ami           = "ami-0c7217cdde317cfec"
#### Instância 01 (Observabilidade)
```hcl
resource "aws_instance" "observability_server" {
  ami           = "ami-0c7217cdde317cfec"
  instance_type = "t4g.medium"
  key_name      = "sua-chave"
  
  user_data = file("${path.module}/ec2-userdata-instance-01.sh")
  
  tags = {
    Name = "loki-observability-server"
  }
}
```

#### Instância 02 (Aplicação de Teste)
```hcl
resource "aws_instance" "test_app_server" {
  ami           = "ami-0c7217cdde317cfec"
  instance_type = "t3.small"
  key_name      = "sua-chave"
  
  user_data = file("${path.module}/ec2-userdata-instance-02.sh")
  
  tags = {
    Name = "test-app-server"
  }
}
```

## Verificação

### Instância 01 (Observabilidade)

#### Logs de execução
```bash
# Ver logs do user data
sudo tail -f /var/log/user-data.log

# Status do code-server
sudo systemctl status code-server

# Verificar Docker
docker --version
docker-compose --version
```

#### Acesso
- **Code-server**: `http://IP_INSTANCIA_1:8080` (senha: demo123)
- **Grafana**: `http://IP_INSTANCIA_1:3000` (admin/admin123) - após docker-compose up
- **Prometheus**: `http://IP_INSTANCIA_1:9090` - após docker-compose up
- **Loki**: `http://IP_INSTANCIA_1:3100` (API) - após docker-compose up

### Instância 02 (Aplicação de Teste)

#### Logs de execução
```bash
# Ver logs do user data
sudo tail -f /var/log/user-data.log

# Status da stack de aplicação
cd /home/ubuntu/repo/test-app
docker-compose -f docker-compose-app.yml ps
```

#### Verificar aplicação
```bash
# Testar aplicação
curl http://localhost/

# Gerar logs de teste
curl http://localhost/generate/50

# Verificar métricas do Promtail
curl http://localhost:9080/metrics
```

#### Configuração manual necessária
```bash
# Navegar para diretório da aplicação
cd /home/ubuntu/repo/test-app

# Substituir IP do Loki Server
sed -i 's/LOKI_SERVER_IP/IP_PRIVADO_INSTANCIA_1/' promtail-app-config.yml

# Reiniciar Promtail
docker-compose -f docker-compose-app.yml restart promtail
```

## Troubleshooting

### Instância 01 (Monitoramento)

#### Code-server não inicia
```bash
# Verificar logs
sudo journalctl -u code-server -f

# Reiniciar serviço
sudo systemctl restart code-server

# Verificar configuração
cat /home/ubuntu/.config/code-server/config.yaml
```

#### Docker não funciona
```bash
# Verificar status
sudo systemctl status docker

# Testar Docker
docker --version
docker-compose --version

# Verificar permissões
groups ubuntu
```

#### Stack de monitoramento não sobe
```bash
# Verificar arquivos de configuração
ls -la docker-compose-observability.yml prometheus.yml loki-config.yml

# Ver logs dos containers
docker-compose logs -f

# Verificar recursos
free -h
df -h
```

### Instância 02 (Monitorada)

#### Node Exporter não funciona
```bash
# Verificar status
sudo systemctl status node_exporter

# Ver logs
sudo journalctl -u node_exporter -f

# Testar manualmente
/usr/local/bin/node_exporter --version
```

#### cAdvisor não funciona
```bash
# Verificar container
docker ps | grep cadvisor

# Ver logs
docker logs cadvisor

# Reiniciar
docker restart cadvisor
```

#### Promtail não funciona
```bash
# Verificar status
sudo systemctl status promtail

# Ver logs
sudo journalctl -u promtail -f

# Testar configuração
/usr/local/bin/promtail -config.file /etc/promtail/config.yml -dry-run

# Testar conectividade com Loki
telnet IP_LOKI_SERVER 3100
```

## Security Groups

### Para Instância 01 (Monitoramento)
Certifique-se de que o Security Group permite:
- **SSH (22)**: Para acesso via terminal
- **8080**: Para code-server
- **3000**: Para interface web do Grafana
- **3100**: Para API do Loki (receber logs do Promtail)
- **9090**: Para interface web do Prometheus

### Para Instância 02 (Monitorada)
Certifique-se de que o Security Group permite:
- **SSH (22)**: Para acesso via terminal
- **9100**: Para Node Exporter (do Prometheus)
- **8080**: Para cAdvisor (do Prometheus)
- **9080**: Para Promtail (métricas)

### Comunicação entre instâncias
- Instância 01 precisa acessar portas 9100 e 8080 da Instância 02
- Instância 02 precisa acessar porta 3100 da Instância 01 (Loki)

## Próximos passos após criação

### 1. Aguardar inicialização (5-10 minutos)
### 2. Configurar IPs nos arquivos de configuração
### 3. Subir stack de observabilidade na Instância 01
### 4. Configurar Data Sources no Grafana (Prometheus e Loki)
### 5. Importar dashboards recomendados
### 6. Testar coleta de métricas, logs e alertas
### 7. Criar dashboards correlacionando logs e métricas