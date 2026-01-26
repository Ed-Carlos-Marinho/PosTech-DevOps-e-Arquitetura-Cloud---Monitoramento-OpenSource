# Setup de Instâncias EC2 para Observabilidade Completa - Aula 05

Guia para criar duas instâncias EC2: uma para o stack completo de observabilidade (Grafana + Prometheus + Loki + Jaeger) e outra para aplicações distribuídas instrumentadas com tracing.

## Arquitetura da Aula 05

- **Instância 1**: Stack de Observabilidade Completa (t4g.medium - ARM64)
  - Grafana (visualização unificada de métricas, logs e traces)
  - Loki (armazenamento centralizado de logs)
  - Prometheus (coleta de métricas)
  - Jaeger (tracing distribuído completo)
  - Promtail (coleta local de logs)

- **Instância 2**: Aplicações Distribuídas Instrumentadas (t3.medium - AMD64)
  - Frontend Service (Node.js/Express com OpenTelemetry)
  - Backend API Service (Python/Flask com OpenTelemetry)
  - PostgreSQL Database (armazenamento persistente)
  - Redis Cache (cache de consultas)
  - RabbitMQ (message queue)
  - Jaeger Agent (coleta local de traces)
  - Promtail (envio de logs para Loki)

## Pré-requisitos

- Conta AWS ativa
- Key Pair criado
- VPC e Subnet configuradas

**Importante sobre as arquiteturas:**
- **t4g.medium** (ARM64): Para stack de observabilidade completa incluindo Jaeger (4GB RAM recomendado)
- **t3.medium** (AMD64): Para aplicações distribuídas com múltiplos serviços (4GB RAM recomendado)

**Novidades da Aula 05:**
- **Tracing Distribuído**: Jaeger para rastreamento de requisições entre serviços
- **Aplicações Instrumentadas**: OpenTelemetry nativo em Node.js e Python
- **Correlação Completa**: Traces, logs e métricas integrados no Grafana
- **Arquitetura de Microserviços**: Frontend, Backend, Database, Cache e Message Queue

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
# Nome: observability-stack-sg
# Descrição: Security group para stack completo de observabilidade (Grafana + Prometheus + Loki + Jaeger)
```

**Regras de entrada:**
- SSH (22) - Source: Seu IP
- Custom TCP (8080) - Source: 0.0.0.0/0 (code-server)
- Custom TCP (3000) - Source: 0.0.0.0/0 (Grafana web)
- Custom TCP (3100) - Source: VPC CIDR (Loki API)
- Custom TCP (9090) - Source: 0.0.0.0/0 (Prometheus web)
- Custom TCP (16686) - Source: 0.0.0.0/0 (Jaeger UI)
- Custom TCP (14250) - Source: VPC CIDR (Jaeger Collector gRPC)
- Custom TCP (14268) - Source: VPC CIDR (Jaeger Collector HTTP)

### Security Group para Aplicações Distribuídas
```bash
# Nome: distributed-apps-sg
# Descrição: Security group para instância com aplicações distribuídas instrumentadas
```

**Regras de entrada:**
- SSH (22) - Source: Seu IP
- Custom TCP (80) - Source: 0.0.0.0/0 (Frontend web)
- Custom TCP (5000) - Source: 0.0.0.0/0 (Backend API)
- Custom TCP (15672) - Source: 0.0.0.0/0 (RabbitMQ Management)
- Custom TCP (9080) - Source: Security Group da Stack de Observabilidade (Promtail metrics)
- Custom TCP (5778) - Source: Security Group da Stack de Observabilidade (Jaeger Agent metrics)

## Passo 3: Criar Instância da Stack de Observabilidade

### Via Console AWS

1. **EC2 Dashboard** → **Launch Instance**

2. **Configurações básicas:**
   - Name: `observability-stack-server`
   - AMI: Ubuntu Server 24.04 LTS
   - Instance type: t4g.medium
   - Key pair: Selecione sua chave

3. **Network settings:**
   - VPC: Default ou sua VPC
   - Subnet: Pública
   - Auto-assign public IP: Enable
   - Security group: `observability-stack-sg`

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
  --tag-specifications 'ResourceType=instance,Tags=[{Key=Name,Value=observability-stack-server}]'
```

## Passo 4: Criar Instância para Aplicações Distribuídas

### Via Console AWS

1. **EC2 Dashboard** → **Launch Instance**

2. **Configurações básicas:**
   - Name: `distributed-apps-server`
   - AMI: Ubuntu Server 24.04 LTS
   - Instance type: t3.medium
   - Key pair: Selecione sua chave

3. **Network settings:**
   - VPC: Mesma da instância de observabilidade
   - Subnet: Mesma ou diferente (mesma AZ recomendada)
   - Auto-assign public IP: Enable
   - Security group: `distributed-apps-sg`

4. **Advanced details:**
   - IAM instance profile: `PosTech-DevOps-Monitoramento-Profile`
   - User data: Cole o conteúdo do `ec2-userdata-instance-02.sh`

5. **Launch instance**

### Via AWS CLI
```bash
aws ec2 run-instances \
  --image-id ami-0c7217cdde317cfec \
  --instance-type t3.medium \
  --key-name sua-chave \
  --security-group-ids sg-yyyyyyyyy \
  --subnet-id subnet-xxxxxxxxx \
  --associate-public-ip-address \
  --iam-instance-profile Name=PosTech-DevOps-Monitoramento-Profile \
  --user-data file://ec2-userdata-instance-02.sh \
  --tag-specifications 'ResourceType=instance,Tags=[{Key=Name,Value=distributed-apps-server}]'
```

## Passo 5: Clonar repositório com os arquivos

Após criar as duas instâncias, clone o repositório para ter acesso aos arquivos necessários:

```bash
git clone -b aula-05 https://github.com/Ed-Carlos-Marinho/PosTech-DevOps-e-Arquitetura-Cloud---Monitoramento-OpenSource.git PosTech
cd PosTech-DevOps-e-Arquitetura-Cloud---Monitoramento-OpenSource
```

Os arquivos estarão disponíveis:
- `docker-compose-observability.yml` - Stack completa de observabilidade com Jaeger
- `distributed-app/` - Aplicações distribuídas instrumentadas
- `ec2-userdata-instance-01.sh` - Script para instância de observabilidade
- `ec2-userdata-instance-02.sh` - Script para instância de aplicações
- `prometheus.yml`, `loki-config.yml`, `promtail-config.yml` - Configurações básicas
- `docs/tracing-guide.md` - Guia completo de tracing distribuído
- `docs/instrumentation-guide.md` - Guia de instrumentação de aplicações

## Passo 6: Verificar Stack de Observabilidade Completa

### Aguardar inicialização (5-10 minutos)

### Verificar serviços
```bash
# Conectar via SSH
ssh -i sua-chave.pem ubuntu@IP_OBSERVABILITY_SERVER

# OU conectar via SSM (sem necessidade de SSH)
aws ssm start-session --target i-1234567890abcdef0

# Verificar user data
sudo tail -f /var/log/user-data.log

# Verificar code-server
sudo systemctl status code-server

# Verificar Docker
docker --version
docker-compose --version

# Verificar stack de observabilidade
docker-compose -f docker-compose-observability.yml ps
```

### Acessar interfaces
- **Code-server**: `http://IP_OBSERVABILITY_SERVER:8080` (senha: demo123)
- **Grafana**: `http://IP_OBSERVABILITY_SERVER:3000` (admin/admin123)
- **Prometheus**: `http://IP_OBSERVABILITY_SERVER:9090`
- **Loki**: `http://IP_OBSERVABILITY_SERVER:3100` (API - sem interface web)
- **Jaeger UI**: `http://IP_OBSERVABILITY_SERVER:16686`

## Passo 7: Verificar Aplicações Distribuídas

### Conectar na instância de aplicações
```bash
# Via SSH
ssh -i sua-chave.pem ubuntu@IP_DISTRIBUTED_APPS_SERVER

# OU via SSM (recomendado)
aws ssm start-session --target i-0987654321fedcba0
```

### Verificar serviços instalados automaticamente
```bash
# Verificar user data
sudo tail -f /var/log/user-data.log

# Verificar aplicações distribuídas
cd /home/ubuntu/PosTech-DevOps-e-Arquitetura-Cloud---Monitoramento-OpenSource/distributed-app
docker-compose -f docker-compose-app.yml ps

# Testar frontend
curl http://localhost/

# Testar backend API
curl http://localhost:5000/health
curl http://localhost:5000/api/users

# Verificar Promtail
curl http://localhost:9080/metrics

# Verificar Jaeger Agent
curl http://localhost:5778/metrics
```

### Configurar IPs dos serviços de observabilidade
```bash
# Obter IP privado da instância de observabilidade
# Navegar para diretório das aplicações
cd /home/ubuntu/PosTech-DevOps-e-Arquitetura-Cloud---Monitoramento-OpenSource/distributed-app

# Configurar IP do Jaeger Collector
sed -i 's/JAEGER_COLLECTOR_IP/IP_PRIVADO_INSTANCIA_1/' docker-compose-app.yml
sed -i 's/JAEGER_COLLECTOR_IP/IP_PRIVADO_INSTANCIA_1/' jaeger-agent-config.yml

# Configurar IP do Loki
sed -i 's/LOKI_SERVER_IP/IP_PRIVADO_INSTANCIA_1/' promtail-app-config.yml

# Reiniciar stack para aplicar configurações
docker-compose -f docker-compose-app.yml down
docker-compose -f docker-compose-app.yml up -d
```

## Passo 8: Configurar Data Sources no Grafana

### Verificar targets no Prometheus
1. **Acessar Prometheus Web**: `http://IP_OBSERVABILITY_SERVER:9090`
2. **Status** → **Targets**
3. **Verificar** se todos os serviços estão "UP"

### Configurar Data Sources no Grafana
1. **Acessar Grafana**: `http://IP_OBSERVABILITY_SERVER:3000` (admin/admin123)
2. **Configuration** → **Data Sources** → **Add data source**

#### Configurar Prometheus
- **URL**: `http://prometheus:9090`
- **Access**: Server (default)
- **Save & Test**

#### Configurar Loki
- **URL**: `http://loki:3100`
- **Access**: Server (default)
- **Save & Test**

#### Configurar Jaeger
- **URL**: `http://jaeger-query:16686`
- **Access**: Server (default)
- **Save & Test**

### Testar consultas básicas

#### PromQL (Prometheus)
- `up` - Status de todos os targets
- `prometheus_tsdb_samples_appended_total` - Métricas do Prometheus
- `loki_ingester_streams` - Streams do Loki
- `promtail_sent_entries_total` - Logs enviados pelo Promtail
- `jaeger_collector_spans_received_total` - Spans recebidos pelo Jaeger

#### LogQL (Loki)
- `{job="frontend-service"}` - Logs do frontend
- `{job="backend-service"}` - Logs do backend
- `{job="syslog"}` - Logs do sistema
- `{level="error"}` - Todos os logs de erro
- `{job="frontend-service"} |= "trace_id"` - Logs com trace_id
- `rate({job="backend-service"}[5m])` - Taxa de logs por segundo

#### Traces no Jaeger
- **Service**: `frontend-service`
- **Operation**: `GET /api/users`
- **Tags**: `http.status_code=200`

## Passo 9: Testar Tracing Distribuído

### Gerar traces nas aplicações
```bash
# Conectar na instância de aplicações distribuídas
ssh -i sua-chave.pem ubuntu@IP_DISTRIBUTED_APPS_SERVER

# Gerar traces com requisições
curl http://localhost/api/users
curl http://localhost/api/products
curl http://localhost/api/orders

# Criar pedido (trace complexo)
curl -X POST http://localhost/api/orders \
  -H "Content-Type: application/json" \
  -d '{
    "user_id": 1,
    "total_amount": 299.99,
    "products": [
      {"id": 1, "quantity": 2},
      {"id": 3, "quantity": 1}
    ]
  }'

# Script para gerar traces contínuos
for i in {1..20}; do
  curl -s http://localhost/api/users > /dev/null
  curl -s http://localhost/api/products > /dev/null
  sleep 2
done
```

### Verificar traces no Jaeger UI
1. **Acessar Jaeger UI**: `http://IP_OBSERVABILITY_SERVER:16686`
2. **Service**: Selecionar `frontend-service` ou `backend-service`
3. **Find Traces**: Buscar traces recentes
4. **Analisar**: Spans, duração, tags e logs

### Correlacionar traces com logs no Grafana
1. **Acessar Grafana**: `http://IP_OBSERVABILITY_SERVER:3000`
2. **Explore** → **Loki**
3. **Consulta**: `{job="frontend-service"} |= "trace_id"`
4. **Copiar trace_id** de um log
5. **Jaeger** → **Buscar pelo trace_id específico**

## Passo 10: Endpoints e Interfaces Disponíveis

### Instância de Observabilidade (IP_OBSERVABILITY_SERVER)
- **Grafana**: `http://IP:3000` (admin/admin123)
- **Prometheus**: `http://IP:9090`
- **Jaeger UI**: `http://IP:16686`
- **Loki API**: `http://IP:3100` (sem interface web)
- **Code-server**: `http://IP:8080` (senha: demo123)

### Instância de Aplicações Distribuídas (IP_DISTRIBUTED_APPS_SERVER)
- **Frontend Web**: `http://IP/` (aplicação principal)
- **Backend API**: `http://IP:5000/` (API REST)
- **RabbitMQ Management**: `http://IP:15672` (guest/guest)
- **Promtail Metrics**: `http://IP:9080/metrics`
- **Jaeger Agent Metrics**: `http://IP:5778/metrics`

### Endpoints da API Backend
```bash
# Health checks
GET /health
GET /api/health

# Recursos principais
GET /api/users          # Lista usuários (com cache)
GET /api/products       # Lista produtos (com cache)
GET /api/orders         # Lista pedidos

# Operações complexas (geram traces interessantes)
POST /api/orders        # Criar pedido (envolve DB, cache, queue)
PUT /api/users/:id      # Atualizar usuário
DELETE /api/products/:id # Deletar produto
```

## Verificação Final

### Na Stack de Observabilidade
- Targets devem aparecer como "UP" no Prometheus
- Logs começam a ser coletados pelo Loki automaticamente
- Traces aparecem no Jaeger UI após requisições
- Data Sources configurados no Grafana funcionando

### Nas Aplicações Distribuídas
- Todos os serviços rodando (frontend, backend, database, cache, queue)
- Jaeger Agent coletando traces localmente
- Promtail enviando logs para Loki
- Aplicações respondendo às requisições HTTP

### Comandos úteis para verificação
```bash
# Verificar stack de observabilidade
docker-compose -f docker-compose-observability.yml ps
docker-compose -f docker-compose-observability.yml logs jaeger-collector

# Verificar aplicações distribuídas
cd distributed-app
docker-compose -f docker-compose-app.yml ps
docker-compose -f docker-compose-app.yml logs frontend
docker-compose -f docker-compose-app.yml logs backend

# Testar conectividade entre instâncias
# Da instância de aplicações para observabilidade
telnet IP_OBSERVABILITY_SERVER 14250  # Jaeger Collector
telnet IP_OBSERVABILITY_SERVER 3100   # Loki

# Verificar métricas dos agentes
curl http://localhost:5778/metrics | grep jaeger_agent_spans_received_total
curl http://localhost:9080/metrics | grep promtail_sent_entries_total

# Verificar se Jaeger está recebendo traces
curl http://IP_OBSERVABILITY_SERVER:14269/metrics | grep jaeger_collector_spans_received_total

# Verificar se Loki está recebendo logs
curl http://IP_OBSERVABILITY_SERVER:3100/metrics | grep loki_ingester_streams
```

## Troubleshooting

### Aplicações distribuídas não iniciam
```bash
# Ver logs detalhados
cd distributed-app
docker-compose -f docker-compose-app.yml logs frontend
docker-compose -f docker-compose-app.yml logs backend

# Verificar conectividade com dependências
docker-compose -f docker-compose-app.yml exec backend ping postgres
docker-compose -f docker-compose-app.yml exec backend ping redis
docker-compose -f docker-compose-app.yml exec frontend ping backend
```

### Traces não aparecem no Jaeger
```bash
# Verificar logs do Jaeger Agent
docker-compose -f docker-compose-app.yml logs jaeger-agent

# Verificar métricas do agent
curl http://localhost:5778/metrics | grep jaeger_agent_spans_received_total

# Testar conectividade com collector
docker-compose -f docker-compose-app.yml exec jaeger-agent nc -zv IP_OBSERVABILITY_SERVER 14250

# Verificar logs do Jaeger Collector na instância de observabilidade
docker-compose -f docker-compose-observability.yml logs jaeger-collector
```

### Logs não aparecem no Loki
```bash
# Verificar logs do Promtail
docker-compose -f docker-compose-app.yml logs promtail

# Verificar métricas do Promtail
curl http://localhost:9080/metrics | grep promtail_sent_entries_total

# Testar conectividade com Loki
docker-compose -f docker-compose-app.yml exec promtail wget -qO- http://IP_OBSERVABILITY_SERVER:3100/ready
```

### Instrumentação não funciona
```bash
# Verificar variáveis de ambiente das aplicações
docker-compose -f docker-compose-app.yml exec frontend env | grep JAEGER
docker-compose -f docker-compose-app.yml exec backend env | grep JAEGER

# Verificar logs de instrumentação
docker-compose -f docker-compose-app.yml logs frontend | grep -i "tracer\|span\|trace"
docker-compose -f docker-compose-app.yml logs backend | grep -i "tracer\|span\|trace"
```

### Performance e recursos
```bash
# Monitorar uso de recursos
docker stats

# Verificar logs de performance
docker-compose -f docker-compose-app.yml logs backend | grep "processing.time_ms"

# Verificar cache hits
docker-compose -f docker-compose-app.yml logs backend | grep "cache.hit"

# Verificar sampling de traces
curl http://localhost:5778/sampling | jq .
```

### Data Sources não conectam no Grafana
```bash
# Verificar conectividade interna do Docker
docker-compose -f docker-compose-observability.yml exec grafana ping prometheus
docker-compose -f docker-compose-observability.yml exec grafana ping loki
docker-compose -f docker-compose-observability.yml exec grafana ping jaeger-query

# Verificar logs dos serviços
docker-compose -f docker-compose-observability.yml logs prometheus
docker-compose -f docker-compose-observability.yml logs loki
docker-compose -f docker-compose-observability.yml logs jaeger-query
```