# Setup de Instâncias EC2 para Grafana

Guia para criar duas instâncias EC2: uma para o stack completo de monitoramento (Grafana + Prometheus + Zabbix) e outra para ser monitorada.

## Arquitetura

- **Instância 1**: Stack de Monitoramento (t4g.medium - ARM64 com user data)
  - Grafana (visualização)
  - Prometheus (métricas modernas)
  - Zabbix Server (monitoramento tradicional)
  - Alertmanager (alertas)
- **Instância 2**: Host monitorado (t3.small - AMD64 para exporters)
  - Node Exporter
  - cAdvisor
  - Zabbix Agent

## Pré-requisitos

- Conta AWS ativa
- Key Pair criado
- VPC e Subnet configuradas

**Importante sobre as arquiteturas:**
- **t4g.medium** (ARM64): Para stack completa de monitoramento com Docker (4GB RAM recomendado)
- **t3.small** (AMD64): Para host monitorado com exporters

## Passo 1: Criar IAM Role para SSM

### Via Console AWS

1. **IAM Dashboard** → **Roles** → **Create role**

2. **Trusted entity type:**
   - AWS service
   - Use case: EC2

3. **Add permissions:**
   - Buscar e selecionar: `AmazonSSMManagedInstanceCore`

4. **Role details:**
   - Role name: `PosTech-DevOps-Monitoramento-Role`
   - Description: `Role para acesso SSM às instâncias EC2 - PosTech DevOps`

5. **Create role**

### Via AWS CLI
```bash
# Criar policy de confiança
cat > trust-policy.json << 'EOF'
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "ec2.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF

# Criar role
aws iam create-role \
  --role-name PosTech-DevOps-Monitoramento-Role \
  --assume-role-policy-document file://trust-policy.json

# Anexar policy do SSM
aws iam attach-role-policy \
  --role-name PosTech-DevOps-Monitoramento-Role \
  --policy-arn arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore

# Criar instance profile
aws iam create-instance-profile --instance-profile-name PosTech-DevOps-Monitoramento-Profile

# Adicionar role ao instance profile
aws iam add-role-to-instance-profile \
  --instance-profile-name PosTech-DevOps-Monitoramento-Profile \
  --role-name PosTech-DevOps-Monitoramento-Role
```

## Passo 2: Criar Security Groups

### Security Group para Stack de Monitoramento
```bash
# Nome: grafana-monitoring-sg
# Descrição: Security group para stack completa de monitoramento (Grafana + Prometheus + Zabbix)
```

**Regras de entrada:**
- SSH (22) - Source: Seu IP
- Custom TCP (8080) - Source: 0.0.0.0/0 (code-server)
- Custom TCP (3000) - Source: 0.0.0.0/0 (Grafana web)
- Custom TCP (9090) - Source: 0.0.0.0/0 (Prometheus web)
- Custom TCP (9093) - Source: 0.0.0.0/0 (Alertmanager web)
- Custom TCP (8080) - Source: 0.0.0.0/0 (Zabbix web)
- Custom TCP (10051) - Source: VPC CIDR (Zabbix server)

### Security Group para Exporters
```bash
# Nome: monitoring-exporters-sg
# Descrição: Security group para instâncias com exporters
```

**Regras de entrada:**
- SSH (22) - Source: Seu IP
- Custom TCP (9100) - Source: Security Group da Stack de Monitoramento (Node Exporter)
- Custom TCP (8080) - Source: Security Group da Stack de Monitoramento (cAdvisor)
- Custom TCP (10050) - Source: Security Group da Stack de Monitoramento (Zabbix Agent)

## Passo 3: Criar Instância da Stack de Monitoramento

### Via Console AWS

1. **EC2 Dashboard** → **Launch Instance**

2. **Configurações básicas:**
   - Name: `grafana-monitoring-server`
   - AMI: Ubuntu Server 24.04 LTS
   - Instance type: t4g.medium
   - Key pair: Selecione sua chave

3. **Network settings:**
   - VPC: Default ou sua VPC
   - Subnet: Pública
   - Auto-assign public IP: Enable
   - Security group: `grafana-monitoring-sg`

4. **Advanced details:**
   - IAM instance profile: `PosTech-DevOps-Monitoramento-Profile`
   - User data: Cole o conteúdo do `ec2-userdata-instance-01.sh`

5. **Launch instance**

### Via AWS CLI
```bash
aws ec2 run-instances \
  --image-id ami-0c7217cdde317cfec \
  --instance-type t4g.medium \
  --key-name sua-chave \
  --security-group-ids sg-xxxxxxxxx \
  --subnet-id subnet-xxxxxxxxx \
  --associate-public-ip-address \
  --iam-instance-profile Name=PosTech-DevOps-Monitoramento-Profile \
  --user-data file://ec2-userdata-instance-01.sh \
  --tag-specifications 'ResourceType=instance,Tags=[{Key=Name,Value=grafana-monitoring-server}]'
```

## Passo 4: Criar Instância para Exporters

### Via Console AWS

1. **EC2 Dashboard** → **Launch Instance**

2. **Configurações básicas:**
   - Name: `monitored-host-01`
   - AMI: Ubuntu Server 24.04 LTS
   - Instance type: t3.small
   - Key pair: Selecione sua chave

3. **Network settings:**
   - VPC: Mesma do Prometheus Server
   - Subnet: Mesma ou diferente (mesma AZ recomendada)
   - Auto-assign public IP: Enable
   - Security group: `monitoring-exporters-sg`

4. **Advanced details:**
   - IAM instance profile: `PosTech-DevOps-Monitoramento-Profile`
   - User data: Cole o conteúdo do `ec2-userdata-instance-02.sh`

5. **Launch instance** (sem user data)

### Via AWS CLI
```bash
aws ec2 run-instances \
  --image-id ami-0c7217cdde317cfec \
  --instance-type t4g.small \
  --key-name sua-chave \
  --security-group-ids sg-yyyyyyyyy \
  --subnet-id subnet-xxxxxxxxx \
  --associate-public-ip-address \
  --user-data file://ec2-userdata-instance-02.sh \
  --tag-specifications 'ResourceType=instance,Tags=[{Key=Name,Value=monitored-host-01}]'
```

## Passo 5: Clonar repositório com os arquivos

Após criar as duas instâncias, clone o repositório para ter acesso aos arquivos necessários:

```bash
git clone -b aula-03 https://github.com/Ed-Carlos-Marinho/PosTech-DevOps-e-Arquitetura-Cloud---Monitoramento-OpenSource.git
cd PosTech-DevOps-e-Arquitetura-Cloud---Monitoramento-OpenSource
```

Os arquivos estarão disponíveis:
- `docker-compose.yml` - Para subir a stack completa de monitoramento
- `ec2-userdata-instance-01.sh` - Script usado no user data da instância 1
- `ec2-userdata-instance-02.sh` - Script usado no user data da instância 2
- `prometheus.yml`, `alertmanager.yml`, `alert_rules.yml` - Configurações
- `setup-ec2-instances.md` - Este guia
- `grafana-compose.md` - Documentação da stack completa

## Passo 6: Verificar Stack de Monitoramento

### Aguardar inicialização (5-10 minutos)

### Verificar serviços
```bash
# Conectar via SSH
ssh -i sua-chave.pem ubuntu@IP_PROMETHEUS_SERVER

# OU conectar via SSM (sem necessidade de SSH)
aws ssm start-session --target i-1234567890abcdef0

# Verificar user data
sudo tail -f /var/log/user-data.log

# Verificar code-server
sudo systemctl status code-server

# Verificar Docker
docker --version
docker-compose --version
```

### Acessar interfaces
- **Code-server**: `http://IP_MONITORING_SERVER:8080` (senha: demo123)
- **Grafana**: `http://IP_MONITORING_SERVER:3000` (admin/admin123)
- **Prometheus**: `http://IP_MONITORING_SERVER:9090`
- **Alertmanager**: `http://IP_MONITORING_SERVER:9093`
- **Zabbix**: `http://IP_MONITORING_SERVER:8080` (Admin/zabbix)

## Passo 7: Verificar instância monitorada

### Conectar na instância monitorada
```bash
# Via SSH
ssh -i sua-chave.pem ubuntu@IP_MONITORED_HOST

# OU via SSM (recomendado)
aws ssm start-session --target i-0987654321fedcba0
```

### Verificar serviços instalados automaticamente
```bash
# Verificar user data
sudo tail -f /var/log/user-data.log

# Verificar Node Exporter
sudo systemctl status node_exporter
curl http://localhost:9100/metrics

# Verificar cAdvisor
docker ps | grep cadvisor
curl http://localhost:8080/metrics

# Verificar Zabbix Agent (ainda não iniciado)
sudo systemctl status zabbix-agent
```

### Configurar IP do Zabbix Server
```bash
# Obter IP privado da instância de monitoramento
# Substituir ZABBIX_SERVER_IP pelo IP real
sudo sed -i 's/ZABBIX_SERVER_IP/IP_PRIVADO_INSTANCIA_1/' /etc/zabbix/zabbix_agentd.conf

# Iniciar Zabbix Agent
sudo systemctl start zabbix-agent
sudo systemctl status zabbix-agent
```

## Passo 8: Configurar integração no Grafana

### Atualizar configuração
1. **Editar prometheus.yml** na instância do Prometheus Server
2. **Substituir IPs** pelos IPs privados reais das instâncias
3. **Recarregar configuração**: `docker-compose restart prometheus`

### Verificar targets
1. **Acessar Prometheus Web**: `http://IP_PROMETHEUS_SERVER:9090`
2. **Status** → **Targets**
3. **Verificar** se todos os exporters estão "UP"

### Testar consultas PromQL
- `up` - Status de todos os targets
- `node_cpu_seconds_total` - Métricas de CPU
- `container_memory_usage_bytes` - Métricas de containers
- `rate(node_cpu_seconds_total[5m])` - Taxa de uso de CPU

## Verificação final

### No Prometheus Server
- Targets devem aparecer como "UP" em alguns minutos
- Métricas começam a ser coletadas automaticamente
- Alertas configurados começam a funcionar

### Comandos úteis
```bash
# Testar conectividade do Prometheus para exporters
telnet IP_EXPORTERS_HOST 9100
telnet IP_EXPORTERS_HOST 8080

# Ver logs dos exporters
sudo journalctl -u node_exporter -f
sudo journalctl -u cadvisor -f

# Testar métricas localmente
curl http://localhost:9100/metrics
curl http://localhost:8080/metrics

# Verificar configuração do Prometheus
docker-compose exec prometheus promtool check config /etc/prometheus/prometheus.yml
```

## Troubleshooting

### Exporters não conectam
- Verificar Security Groups (portas 9100 e 8080)
- Confirmar IPs privados no prometheus.yml
- Verificar se serviços estão rodando: `systemctl status node_exporter cadvisor`

### Prometheus não coleta métricas
- Verificar logs: `docker-compose logs prometheus`
- Verificar targets em Status → Targets
- Testar conectividade de rede entre instâncias

### Alertmanager não funciona
- Verificar logs: `docker-compose logs alertmanager`
- Verificar configuração: `/etc/alertmanager/alertmanager.yml`
- Testar regras de alerta no Prometheus