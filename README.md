# Aula 05 - PosTech DevOps e Arquitetura Cloud

Este repositório contém os materiais da **Aula 05** do módulo **Monitoramento OpenSource** da PosTech DevOps e Arquitetura Cloud.

## Conteúdo da Branch aula-05

### 1. Script de User Data EC2 Instância 1 (`ec2-userdata-instance-01.sh`)
Script automatizado para configuração da instância de tracing com:
- Docker e Docker Compose
- Code-server (VS Code no navegador) na porta 8080
- Configurações básicas de segurança

### 2. Script de User Data EC2 Instância 2 (`ec2-userdata-instance-02.sh`)
Script automatizado para configuração da instância de aplicações distribuídas com:
- Docker e Docker Compose
- Clonagem do repositório
- Inicialização automática da stack de aplicações distribuídas

### 3. Docker Compose Stack de Tracing (`docker-compose-observability.yml`)
Stack de tracing distribuído para Instância 1:
- Grafana (visualização de traces)
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
- Jaeger All-in-One para coleta e visualização de traces
- Instrumentação OpenTelemetry nativa para múltiplas linguagens
- Sampling strategies para otimização de performance
- Context propagation entre serviços via HTTP headers

## Estrutura do Projeto

```
├── README.md                           # Documentação principal
├── docker-compose-observability.yml   # Stack de tracing (Instância 1)
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
    ├── tracing-guide.md                # Guia completo de tracing distribuído
    ├── instrumentation-guide.md        # Guia de instrumentação de aplicações
    └── ec2-userdata.md                 # Guia dos scripts
```

## Arquivos de Documentação

- `docs/ec2-userdata.md` - Guia detalhado dos scripts de user data
- `docs/setup-ec2-instances.md` - Passo a passo completo para criar as instâncias EC2
- `docs/tracing-guide.md` - Guia completo de tracing distribuído
- `docs/instrumentation-guide.md` - Guia de instrumentação de aplicações

## Como usar

### 1. Instância 1 (Tracing)
```bash
# Clonar repositório
git clone -b aula-05 https://github.com/Ed-Carlos-Marinho/PosTech-DevOps-e-Arquitetura-Cloud---Monitoramento-OpenSource.git
cd PosTech-DevOps-e-Arquitetura-Cloud---Monitoramento-OpenSource

# Iniciar stack de tracing
docker-compose -f docker-compose-observability.yml up -d

# Acessar interfaces
# - Grafana: http://IP_INSTANCIA_1:3000 (admin/admin123)
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

### 3. Configurar Data Source no Grafana
1. **Jaeger**: `http://jaeger:16686`

### 4. Testar aplicações e gerar traces
```bash
# Requisições simples
curl http://localhost/api/users
curl http://localhost/api/orders
curl http://localhost/api/products

# Criar pedido (trace complexo)
curl -X POST http://localhost/api/orders \
  -H "Content-Type: application/json" \
  -d '{"user_id": 1, "total_amount": 299.99}'
```

### 5. Visualizar traces no Jaeger UI
- Service: `frontend-service` ou `backend-service`
- Operation: `GET /api/users`
- Tags: `http.status_code=200`

## Objetivo da Aula

Entender o conceito de tracing distribuído e configurar o Jaeger para rastrear requisições entre serviços, identificar gargalos e melhorar a performance de aplicações distribuídas.

## Teoria Abordada

- **Conceitos de tracing distribuído**: Importância do rastreamento em arquiteturas de microserviços
- **Spans, traces e contexto de requisição**: Estrutura fundamental do tracing distribuído
- **Sampling e instrumentação de serviços**: Estratégias para coleta eficiente de traces
- **Arquitetura Jaeger**: Componentes (collector, agent, query e UI) e suas funções
- **Diagnóstico de latência e gargalos**: Identificação e resolução de problemas de performance
- **OpenTelemetry**: Instrumentação nativa para controle total sobre tracing
- **Estratégias de sampling**: Balanceamento entre visibilidade e overhead
- **Context propagation**: Propagação de contexto entre serviços distribuídos