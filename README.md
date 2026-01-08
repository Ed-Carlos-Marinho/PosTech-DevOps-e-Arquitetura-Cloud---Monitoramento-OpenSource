# Aula 05 - PosTech DevOps e Arquitetura Cloud

Este repositório contém os materiais da **Aula 05** do módulo **Monitoramento OpenSource** da PosTech DevOps e Arquitetura Cloud.

## Conteúdo da Branch aula-05

### 1. Script de User Data EC2 Instância 1 (`ec2-userdata-instance-01.sh`)
Script automatizado para configuração da instância de observabilidade com:
- Docker e Docker Compose
- Code-server (VS Code no navegador) na porta 8080
- Configurações básicas de segurança

### 2. Script de User Data EC2 Instância 2 (`ec2-userdata-instance-02.sh`)
Script automatizado para configuração da instância de aplicações distribuídas com:
- Docker e Docker Compose
- Clonagem do repositório
- Inicialização automática da stack de aplicações distribuídas

### 3. Docker Compose Stack de Observabilidade (`docker-compose-observability.yml`)
Stack completa de observabilidade para Instância 1:
- Grafana (visualização unificada de métricas, logs e traces)
- Loki (armazenamento e consulta de logs)
- Prometheus Server (métricas básicas para correlação)
- Promtail (agente de coleta de logs local)
- Jaeger (tracing distribuído completo)

### 4. Docker Compose Stack de Aplicações (`distributed-app/docker-compose-app.yml`)
Stack de aplicações distribuídas para Instância 2:
- Frontend Service (React/Node.js com instrumentação)
- Backend API Service (Python Flask com instrumentação)
- Database Service (PostgreSQL)
- Cache Service (Redis)
- Message Queue (RabbitMQ)
- Jaeger Agent (coleta de traces local)

### 5. Configurações de Tracing Distribuído
- Jaeger All-in-One (desenvolvimento) e componentes separados (produção)
- Instrumentação Jaeger Client Libraries nativo para múltiplas linguagens
- Sampling strategies para otimização de performance
- Correlação entre traces, logs e métricas no Grafana
- Context propagation entre serviços via HTTP headers

## Estrutura do Projeto

```
├── README.md                           # Documentação principal
├── docker-compose-observability.yml   # Stack de observabilidade (Instância 1)
├── loki-config.yml                     # Configuração do Loki
├── promtail-config.yml                 # Configuração do Promtail (Instância 1)
├── prometheus.yml                      # Configuração do Prometheus
├── jaeger-config.yml                   # Configuração do Jaeger
├── ec2-userdata-instance-01.sh         # Script para Instância 1
├── ec2-userdata-instance-02.sh         # Script para Instância 2
├── distributed-app/                    # Aplicações distribuídas (Instância 2)
│   ├── docker-compose-app.yml          # Stack das aplicações
│   ├── frontend/                       # Frontend Service (Node.js/React)
│   ├── backend/                        # Backend API Service (Python Flask)
│   ├── database/                       # Database scripts e configurações
│   └── jaeger-agent-config.yml         # Configuração do Jaeger Agent
├── docs/                               # Documentação adicional
    ├── setup-ec2-instances.md          # Guia de setup das instâncias
    ├── observability-compose.md        # Guia do Docker Compose com observabilidade completa
    ├── tracing-guide.md                # Guia completo de tracing distribuído
    ├── instrumentation-guide.md        # Guia de instrumentação de aplicações
    ├── loki-logql-guide.md             # Guia de LogQL
    └── ec2-userdata.md                 # Guia dos scripts
```

## Arquivos de Documentação

- `docs/ec2-userdata.md` - Guia detalhado dos scripts de user data
- `docs/loki-compose.md` - Guia detalhado do Docker Compose com Loki
- `docs/setup-ec2-instances.md` - Passo a passo completo para criar as instâncias EC2 com SSM
- `docs/loki-logql-guide.md` - Guia completo de consultas LogQL e correlação com métricas

## Como usar

### 1. Instância 1 (Observabilidade)
```bash
# Clonar repositório
git clone -b aula-05 https://github.com/Ed-Carlos-Marinho/PosTech-DevOps-e-Arquitetura-Cloud---Monitoramento-OpenSource.git
cd PosTech-DevOps-e-Arquitetura-Cloud---Monitoramento-OpenSource

# Iniciar stack de observabilidade
docker-compose -f docker-compose-observability.yml up -d

# Acessar interfaces
# - Grafana: http://IP_INSTANCIA_1:3000 (admin/admin123)
# - Prometheus: http://IP_INSTANCIA_1:9090
# - Loki: http://IP_INSTANCIA_1:3100 (API)
# - Jaeger UI: http://IP_INSTANCIA_1:16686
```

### 2. Instância 2 (Aplicações Distribuídas)
```bash
# Clonar repositório
git clone -b aula-05 https://github.com/Ed-Carlos-Marinho/PosTech-DevOps-e-Arquitetura-Cloud---Monitoramento-OpenSource.git
cd PosTech-DevOps-e-Arquitetura-Cloud---Monitoramento-OpenSource/distributed-app

# Configurar IP do Jaeger Collector
sed -i 's/JAEGER_COLLECTOR_IP/IP_PRIVADO_INSTANCIA_1/' jaeger-agent-config.yml

# Iniciar stack de aplicações distribuídas
docker-compose -f docker-compose-app.yml up -d

# Testar aplicações e gerar traces
curl http://localhost/api/users
curl http://localhost/api/orders
curl http://localhost/api/products
```

### 3. Configurar Data Sources no Grafana
1. **Loki**: `http://loki:3100`
2. **Prometheus**: `http://prometheus:9090`
3. **Jaeger**: `http://jaeger-query:16686`

### 4. Consultas básicas para correlação

#### Traces no Jaeger
- Service: `frontend-service`
- Operation: `GET /api/users`
- Tags: `http.status_code=200`

#### Logs correlacionados no Loki
```logql
{job="frontend"} |= "trace_id"
{job="backend"} |= "span_id"
```

#### Métricas correlacionadas no Prometheus
```promql
http_requests_total{service="frontend"}
http_request_duration_seconds{service="backend"}
```

## Objetivo da Aula

Entender o conceito de tracing distribuído e configurar o Jaeger para rastrear requisições entre serviços, identificar gargalos e melhorar a performance de aplicações distribuídas.

## Teoria Abordada

- **Conceitos de tracing distribuído**: Importância do rastreamento em arquiteturas de microserviços
- **Spans, traces e contexto de requisição**: Estrutura fundamental do tracing distribuído
- **Sampling e instrumentação de serviços**: Estratégias para coleta eficiente de traces
- **Arquitetura Jaeger**: Componentes (collector, agent, query e UI) e suas funções
- **Diagnóstico de latência e gargalos**: Identificação e resolução de problemas de performance
- **Correlação com logs e métricas**: Observabilidade completa com os três pilares
- **Jaeger Client Libraries**: Instrumentação nativa para controle total sobre tracing
- **Estratégias de sampling**: Balanceamento entre visibilidade e overhead
- **Context propagation**: Propagação de contexto entre serviços distribuídos