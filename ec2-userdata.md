# EC2 User Data Scripts

Scripts de configuração automática para instâncias EC2 Ubuntu usados na Aula 03 do módulo Monitoramento OpenSource.

## Scripts Disponíveis

### ec2-userdata-instance-01.sh
Script para a **Instância de Monitoramento** (t4g.medium - ARM64):
- Docker e Docker Compose
- Code-server (VS Code no navegador) na porta 8080
- Configurações básicas de segurança
- Preparação para stack completa de monitoramento

### ec2-userdata-instance-02.sh  
Script para a **Instância Monitorada** (t3.small - AMD64):
- Node Exporter (métricas do sistema)
- cAdvisor (métricas de containers via Docker)
- Zabbix Agent (monitoramento tradicional)
- Configurações de firewall

## O que cada script faz

### Instância 01 (Monitoramento)
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
- Zabbix Agent: Agente de monitoramento tradicional
- Docker: Para executar cAdvisor

**Configurações:**
- Node Exporter: Porta 9100
- cAdvisor: Porta 8080 (via container Docker)
- Zabbix Agent: Porta 10050 (requer configuração manual do IP)
- Firewall: SSH e portas dos exporters liberadas

## Como usar

## Como usar

### 1. No Console AWS

#### Para Instância 01 (Monitoramento)
1. Criar nova instância EC2 Ubuntu 24.04 LTS
2. Instance type: **t4g.medium** (ARM64)
3. Em "Advanced Details" → "User data"
4. Colar o conteúdo do arquivo `ec2-userdata-instance-01.sh`
5. Finalizar criação da instância

#### Para Instância 02 (Monitorada)  
1. Criar nova instância EC2 Ubuntu 24.04 LTS
2. Instance type: **t3.small** (AMD64)
3. Em "Advanced Details" → "User data"
4. Colar o conteúdo do arquivo `ec2-userdata-instance-02.sh`
5. Finalizar criação da instância

### 2. Via AWS CLI

#### Instância 01 (Monitoramento)
```bash
aws ec2 run-instances \
  --image-id ami-0c7217cdde317cfec \
  --instance-type t4g.medium \
  --key-name sua-chave \
  --security-group-ids sg-xxxxxxxxx \
  --user-data file://ec2-userdata-instance-01.sh \
  --tag-specifications 'ResourceType=instance,Tags=[{Key=Name,Value=grafana-monitoring-server}]'
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
  instance_type = "t4g.medium"
  key_name      = "sua-chave"
  
  user_data = file("${path.module}/ec2-userdata-instance-01.sh")
  
  tags = {
    Name = "grafana-monitoring-server"
  }
}
```

#### Instância 02 (Monitorada)
```hcl
resource "aws_instance" "monitored_host" {
  ami           = "ami-0c7217cdde317cfec"
  instance_type = "t3.small"
  key_name      = "sua-chave"
  
  user_data = file("${path.module}/ec2-userdata-instance-02.sh")
  
  tags = {
    Name = "monitored-host-01"
  }
}
```

## Verificação

### Instância 01 (Monitoramento)

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
- **Zabbix**: `http://IP_INSTANCIA_1:8080` - após docker-compose up

### Instância 02 (Monitorada)

#### Logs de execução
```bash
# Ver logs do user data
sudo tail -f /var/log/user-data.log

# Status dos exporters
sudo systemctl status node_exporter
docker ps | grep cadvisor
sudo systemctl status zabbix-agent
```

#### Verificar métricas
```bash
# Node Exporter
curl http://localhost:9100/metrics

# cAdvisor  
curl http://localhost:8080/metrics

# Zabbix Agent (após configurar IP)
sudo zabbix_agentd -t system.cpu.load[all,avg1]
```

#### Configuração manual necessária
```bash
# Substituir IP do Zabbix Server
sudo sed -i 's/ZABBIX_SERVER_IP/IP_PRIVADO_INSTANCIA_1/' /etc/zabbix/zabbix_agentd.conf

# Iniciar Zabbix Agent
sudo systemctl start zabbix-agent
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
ls -la docker-compose.yml prometheus.yml alertmanager.yml

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

#### Zabbix Agent não conecta
```bash
# Verificar configuração
cat /etc/zabbix/zabbix_agentd.conf

# Ver logs
sudo journalctl -u zabbix-agent -f

# Testar conectividade
telnet IP_ZABBIX_SERVER 10051

# Verificar firewall
sudo ufw status
```

## Security Groups

### Para Instância 01 (Monitoramento)
Certifique-se de que o Security Group permite:
- **SSH (22)**: Para acesso via terminal
- **HTTP (80)**: Para Zabbix web interface  
- **8080**: Para code-server
- **3000**: Para interface web do Grafana
- **9090**: Para interface web do Prometheus
- **9093**: Para interface web do Alertmanager
- **10051**: Para Zabbix Server (receber conexões de agentes)

### Para Instância 02 (Monitorada)
Certifique-se de que o Security Group permite:
- **SSH (22)**: Para acesso via terminal
- **9100**: Para Node Exporter (do Prometheus)
- **8080**: Para cAdvisor (do Prometheus)
- **10050**: Para Zabbix Agent (do Zabbix Server)

### Comunicação entre instâncias
- Instância 01 precisa acessar portas 9100, 8080 e 10050 da Instância 02
- Instância 02 precisa acessar porta 10051 da Instância 01 (Zabbix)

## Próximos passos após criação

### 1. Aguardar inicialização (5-10 minutos)
### 2. Configurar IPs nos arquivos de configuração
### 3. Subir stack de monitoramento na Instância 01
### 4. Configurar Data Sources no Grafana
### 5. Importar dashboards recomendados
### 6. Testar coleta de métricas e alertas