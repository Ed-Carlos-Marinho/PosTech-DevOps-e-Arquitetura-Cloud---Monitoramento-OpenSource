# Distributed Applications - Aula 05

Aplicações distribuídas instrumentadas com OpenTelemetry para demonstração de tracing distribuído, parte da Aula 05 do módulo Monitoramento OpenSource.

## Arquitetura

### Frontend Service (Node.js/Express)
- **Porta**: 80 (externa) → 3000 (interna)
- **Função**: Interface web e proxy para backend
- **Instrumentação**: OpenTelemetry automática + spans manuais
- **Logs**: JSON estruturado com trace_id/span_id

### Backend Service (Python/Flask)
- **Porta**: 5000
- **Função**: API REST com lógica de negócio
- **Instrumentação**: OpenTelemetry automática para Flask, SQLAlchemy, Redis
- **Logs**: JSON estruturado com correlação de traces

### Banco de Dados (PostgreSQL)
- **Porta**: 5432
- **Função**: Armazenamento persistente
- **Dados**: Usuários, produtos, pedidos
- **Instrumentação**: Automática via SQLAlchemy

### Cache (Redis)
- **Porta**: 6379
- **Função**: Cache de consultas frequentes
- **Instrumentação**: Automática via cliente Redis

### Message Queue (RabbitMQ)
- **Portas**: 5672 (AMQP), 15672 (Management)
- **Função**: Processamento assíncrono
- **Instrumentação**: Manual para publicação de mensagens

### Jaeger Agent
- **Portas**: 6831/6832 (UDP), 5778 (HTTP)
- **Função**: Coleta local de traces
- **Configuração**: Envia traces para collector na Instância 1

## Como usar

### 1. Configurar e iniciar
```bash
# Navegar para diretório
cd distributed-app

# Configurar IP do Jaeger Collector
sed -i 's/JAEGER_COLLECTOR_IP/IP_PRIVADO_INSTANCIA_1/' docker-compose-app.yml
sed -i 's/JAEGER_COLLECTOR_IP/IP_PRIVADO_INSTANCIA_1/' jaeger-agent-config.yml

# Iniciar stack
docker-compose -f docker-compose-app.yml up -d
```

### 2. Verificar status
```bash
# Status dos serviços
docker-compose -f docker-compose-app.yml ps

# Logs dos serviços
docker-compose -f docker-compose-app.yml logs -f frontend
docker-compose -f docker-compose-app.yml logs -f backend
```

### 3. Testar aplicações e gerar traces

#### Endpoints disponíveis
```bash
# Health checks
curl http://localhost/health
curl http://localhost:5000/health

# Listar usuários (com cache)
curl http://localhost/api/users

# Listar produtos (com cache)
curl http://localhost/api/products

# Listar pedidos
curl http://localhost/api/orders

# Criar pedido (operação complexa)
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
```

#### Script de teste automatizado
```bash
# Gerar traces variados
for i in {1..10}; do
  curl -s http://localhost/api/users > /dev/null
  curl -s http://localhost/api/products > /dev/null
  curl -s http://localhost/api/orders > /dev/null
  
  # Criar pedido ocasionalmente
  if [ $((i % 3)) -eq 0 ]; then
    curl -s -X POST http://localhost/api/orders \
      -H "Content-Type: application/json" \
      -d "{\"user_id\": $((RANDOM % 10 + 1)), \"total_amount\": $((RANDOM % 500 + 50))}" > /dev/null
  fi
  
  sleep 2
done
```

### 4. Acessar interfaces

#### Aplicações
- **Frontend**: http://IP_INSTANCIA_2
- **Backend API**: http://IP_INSTANCIA_2:5000
- **RabbitMQ Management**: http://IP_INSTANCIA_2:15672 (guest/guest)

#### Métricas
- **Jaeger Agent Metrics**: http://IP_INSTANCIA_2:5778/metrics

## Fluxo de Traces

### Trace típico de consulta (GET /api/users):
1. **Frontend**: Recebe requisição HTTP
2. **Frontend**: Cria span "get_users"
3. **Frontend**: Faz requisição HTTP para backend
4. **Backend**: Recebe requisição (span automático)
5. **Backend**: Verifica cache Redis (span automático)
6. **Backend**: Consulta PostgreSQL se necessário (span automático)
7. **Backend**: Retorna resposta
8. **Frontend**: Retorna resposta final

### Trace complexo de criação (POST /api/orders):
1. **Frontend**: Recebe requisição HTTP
2. **Frontend**: Cria span "create_order"
3. **Frontend**: Faz requisição HTTP para backend
4. **Backend**: Recebe requisição (span automático)
5. **Backend**: Valida dados (span manual)
6. **Backend**: Inicia transação PostgreSQL (span automático)
7. **Backend**: Insere pedido no banco (span automático)
8. **Backend**: Publica mensagem RabbitMQ (span manual)
9. **Backend**: Invalida cache Redis (span automático)
10. **Backend**: Confirma transação
11. **Backend**: Retorna resposta
12. **Frontend**: Retorna resposta final

## Correlação com Logs

### Logs estruturados incluem:
- **trace_id**: Identificador único do trace
- **span_id**: Identificador único do span
- **timestamp**: Timestamp preciso
- **level**: Nível do log (info, warning, error)
- **message**: Mensagem descritiva
- **context**: Dados específicos da operação

### Visualização de logs:
```bash
# Ver logs do frontend
docker-compose -f docker-compose-app.yml logs -f frontend

# Ver logs do backend
docker-compose -f docker-compose-app.yml logs -f backend

# Filtrar logs por trace_id
docker-compose -f docker-compose-app.yml logs | grep "trace_id=abc123"
```

## Troubleshooting

### Aplicações não iniciam
```bash
# Ver logs detalhados
docker-compose -f docker-compose-app.yml logs frontend
docker-compose -f docker-compose-app.yml logs backend

# Verificar conectividade com dependências
docker-compose -f docker-compose-app.yml exec backend ping postgres
docker-compose -f docker-compose-app.yml exec backend ping redis
```

### Traces não aparecem no Jaeger
```bash
# Verificar logs do Jaeger Agent
docker-compose -f docker-compose-app.yml logs jaeger-agent

# Verificar métricas do agent
curl http://localhost:5778/metrics

# Testar conectividade com collector
docker-compose -f docker-compose-app.yml exec jaeger-agent nc -zv JAEGER_COLLECTOR_IP 14250
```

### Performance e recursos
```bash
# Monitorar uso de recursos
docker stats

# Verificar logs de performance
docker-compose -f docker-compose-app.yml logs backend | grep "processing.time_ms"

# Verificar cache hits
docker-compose -f docker-compose-app.yml logs backend | grep "cache.hit"
```

## Desenvolvimento

### Modificar aplicações
```bash
# Rebuild frontend
docker-compose -f docker-compose-app.yml build frontend
docker-compose -f docker-compose-app.yml restart frontend

# Rebuild backend
docker-compose -f docker-compose-app.yml build backend
docker-compose -f docker-compose-app.yml restart backend
```

### Adicionar instrumentação
1. Editar código da aplicação
2. Adicionar spans manuais conforme necessário
3. Rebuild e restart do serviço
4. Verificar traces no Jaeger UI

### Configurar sampling
1. Editar `jaeger-agent-config.yml`
2. Ajustar estratégias de sampling
3. Restart do Jaeger Agent
4. Verificar impacto na coleta de traces