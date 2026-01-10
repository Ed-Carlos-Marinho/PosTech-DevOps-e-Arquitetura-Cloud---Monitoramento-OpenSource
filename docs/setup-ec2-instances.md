# Setup de Instâncias EC2 para Loki

Guia para criar duas instâncias EC2: uma para o stack completo de observabilidade (Grafana + Prometheus + Loki) e outra para aplicação de teste com geração de logs.

## Arquitetura

- **Instância 1**: Stack de Observabilidade (t4g.medium - ARM64)
  - Grafana (visualização unificada)
  - Loki (logs centralizados)
  - Prometheus (métricas básicas)
- **Instância 2**: Aplicação de Teste (t3.small - AMD64)
  - Promtail (coleta de logs)
  - Aplicação web de teste (gera logs abundantes)
  - Nginx (proxy e logs de acesso)

## Pré-requisitos

- Conta AWS ativa
- Key Pair criado
- VPC e Subnet configuradas

**Importante sobre as arquiteturas:**
- **t4g.medium** (ARM64): Para stack de observabilidade com Docker (4GB RAM recomendado)
- **t3.small** (AMD64): Para aplicação de teste e Promtail

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

### Security Group para Stack de Observabilidade
```bash
# Nome: loki-observability-sg
# Descrição: Security group para stack de observabilidade (Grafana + Prometheus + Loki)
```

**Regras de entrada:**
- SSH (22) - Source: Seu IP
- Custom TCP (8080) - Source: 0.0.0.0/0 (code-server)
- Custom TCP (80) - Source: 0.0.0.0/0 (Grafana web)
- Custom TCP (3100) - Source: VPC CIDR (Loki API)
- Custom TCP (9090) - Source: 0.0.0.0/0 (Prometheus web)

### Security Group para Aplicação de Teste
```bash
# Nome: test-app-sg
# Descrição: Security group para instância com aplicação de teste e Promtail
```

**Regras de entrada:**
- SSH (22) - Source: Seu IP
- Custom TCP (80) - Source: 0.0.0.0/0 (Aplicação web via Nginx)
- Custom TCP (9080) - Source: Security Group da Stack de Observabilidade (Promtail metrics)

## Passo 3: Criar Instância da Stack de Observabilidade

### Via Console AWS

1. **EC2 Dashboard** → **Launch Instance**

2. **Configurações básicas:**
   - Name: `loki-observability-server`
   - AMI: Ubuntu Server 24.04 LTS
   - Instance type: t4g.medium
   - Key pair: Selecione sua chave

3. **Network settings:**
   - VPC: Default ou sua VPC
   - Subnet: Pública
   - Auto-assign public IP: Enable
   - Security group: `loki-observability-sg`

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
  --tag-specifications 'ResourceType=instance,Tags=[{Key=Name,Value=loki-observability-server}]'
```

## Passo 4: Criar Instância para Aplicação de Teste

### Via Console AWS

1. **EC2 Dashboard** → **Launch Instance**

2. **Configurações básicas:**
   - Name: `test-app-server`
   - AMI: Ubuntu Server 24.04 LTS
   - Instance type: t3.small
   - Key pair: Selecione sua chave

3. **Network settings:**
   - VPC: Mesma da instância de observabilidade
   - Subnet: Mesma ou diferente (mesma AZ recomendada)
   - Auto-assign public IP: Enable
   - Security group: `test-app-sg`

4. **Advanced details:**
   - IAM instance profile: `PosTech-DevOps-Monitoramento-Profile`
   - User data: Cole o conteúdo do `ec2-userdata-instance-02.sh`

5. **Launch instance**

### Via AWS CLI
```bash
aws ec2 run-instances \
  --image-id ami-0c7217cdde317cfec \
  --instance-type t3.small \
  --key-name sua-chave \
  --security-group-ids sg-yyyyyyyyy \
  --subnet-id subnet-xxxxxxxxx \
  --associate-public-ip-address \
  --iam-instance-profile Name=PosTech-DevOps-Monitoramento-Profile \
  --user-data file://ec2-userdata-instance-02.sh \
  --tag-specifications 'ResourceType=instance,Tags=[{Key=Name,Value=test-app-server}]'
```

## Passo 5: Clonar repositório com os arquivos

Após criar as duas instâncias, clone o repositório para ter acesso aos arquivos necessários:

```bash
git clone -b aula-04 https://github.com/Ed-Carlos-Marinho/PosTech-DevOps-e-Arquitetura-Cloud---Monitoramento-OpenSource.git
cd PosTech-DevOps-e-Arquitetura-Cloud---Monitoramento-OpenSource
docker-compose -f docker-compose-observability.yml up -d
```

Os arquivos estarão disponíveis:
- `docker-compose-observability.yml` - Para subir a stack de observabilidade
- `ec2-userdata-instance-01.sh` - Script usado no user data da instância 1
- `ec2-userdata-instance-02.sh` - Script usado no user data da instância 2
- `prometheus.yml`, `loki-config.yml`, `promtail-config.yml` - Configurações
- `setup-ec2-instances.md` - Este guia
- `loki-compose.md` - Documentação da stack de observabilidade

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
- **Grafana**: `http://IP_MONITORING_SERVER:80` (admin/admin123)
- **Prometheus**: `http://IP_MONITORING_SERVER:9090`
- **Loki**: `http://IP_MONITORING_SERVER:3100` (API - sem interface web)

## Passo 7: Verificar instância de aplicação de teste

### Conectar na instância de aplicação
```bash
# Via SSH
ssh -i sua-chave.pem ubuntu@IP_TEST_APP_HOST

# OU via SSM (recomendado)
aws ssm start-session --target i-0987654321fedcba0
```

### Verificar serviços instalados automaticamente
```bash
# Verificar user data
sudo tail -f /var/log/user-data.log

# Verificar aplicação de teste
curl http://localhost/

# Verificar Promtail metrics
curl http://localhost:9080/metrics

# Gerar logs de teste
curl http://localhost/generate/10
```

### Configurar IP do Loki
```bash
# Obter IP privado da instância de observabilidade
# Editar configuração do Promtail
cd /home/ubuntu/repo/test-app
nano promtail-app-config.yml

# Substituir LOKI_SERVER_IP pelo IP real
sed -i 's/LOKI_SERVER_IP/IP_PRIVADO_INSTANCIA_1/' promtail-app-config.yml

# Reiniciar Promtail
docker-compose -f docker-compose-app.yml restart promtail
```

## Passo 8: Configurar integração no Grafana

### Verificar targets
1. **Acessar Prometheus Web**: `http://IP_PROMETHEUS_SERVER:9090`
2. **Status** → **Targets**
3. **Verificar** se todos os serviços estão "UP"

### Configurar Data Sources no Grafana
1. **Prometheus**: `http://prometheus:9090`
2. **Loki**: `http://loki:3100`

### Testar consultas
#### PromQL (Prometheus)
- `up` - Status de todos os targets
- `prometheus_tsdb_samples_appended_total` - Métricas do Prometheus
- `loki_ingester_streams` - Streams do Loki
- `promtail_sent_entries_total` - Logs enviados pelo Promtail

#### LogQL (Loki)
- `{job="test-app"}` - Logs da aplicação de teste
- `{job="nginx-access"}` - Logs de acesso do Nginx
- `{job="syslog"}` - Logs do sistema
- `{level="error"}` - Todos os logs de erro
- `{job="test-app"} |= "error"` - Logs contendo "error"
- `rate({job="test-app"}[5m])` - Taxa de logs por segundo

## Verificação final

### No Prometheus Server
- Targets devem aparecer como "UP" em alguns minutos
- Métricas começam a ser coletadas automaticamente
- Alertas configurados começam a funcionar

### No Loki
- Logs começam a ser coletados pelo Promtail automaticamente
- Verificar no Grafana se Data Source Loki está funcionando
- Testar consultas LogQL básicas

### Comandos úteis
```bash
# Testar conectividade do Prometheus para Loki
telnet IP_LOKI_HOST 3100

# Testar conectividade do Promtail para Loki
telnet IP_LOKI_HOST 3100

# Ver logs dos serviços
docker-compose -f docker-compose-observability.yml logs -f
docker-compose -f docker-compose-app.yml logs -f

# Testar métricas localmente
curl http://localhost:9080/metrics  # Promtail metrics
curl http://localhost:3100/metrics  # Loki metrics

# Verificar configuração do Prometheus
docker-compose -f docker-compose-observability.yml exec prometheus promtool check config /etc/prometheus/prometheus.yml

# Verificar se Loki está recebendo logs
curl http://localhost:3100/metrics | grep loki_ingester_streams
```

## Troubleshooting

### Promtail não conecta ao Loki
- Verificar Security Groups (porta 3100 entre instâncias)
- Confirmar IP privado da instância Loki no promtail-app-config.yml
- Verificar se Loki está rodando: `docker-compose -f docker-compose-observability.yml ps`

### Prometheus não coleta métricas
- Verificar logs: `docker-compose -f docker-compose-observability.yml logs prometheus`
- Verificar targets em Status → Targets
- Testar conectividade de rede entre serviços

### Loki não recebe logs
- Verificar logs: `docker-compose -f docker-compose-observability.yml logs loki`
- Verificar se Promtail está conectado: `docker-compose -f docker-compose-app.yml logs promtail`
- Testar API do Loki: `curl http://localhost:3100/ready`

### Logs não aparecem no Grafana
```bash
# Verificar Data Source Loki no Grafana
# Configuration → Data Sources → Loki → Test

# Verificar se Promtail está enviando logs
curl http://localhost:9080/metrics | grep promtail_sent_entries_total

# Verificar se Loki está recebendo logs
curl http://localhost:3100/metrics | grep loki_ingester_streams

# Testar consulta LogQL simples no Grafana
{job="test-app"}
```