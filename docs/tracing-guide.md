# Guia de Tracing Distribuído com Jaeger

Guia completo para entender e utilizar tracing distribuído com Jaeger na Aula 05 do módulo Monitoramento OpenSource.

## Conceitos Fundamentais

### O que é Tracing Distribuído?

Tracing distribuído é uma técnica de observabilidade que permite rastrear requisições através de múltiplos serviços em uma arquitetura distribuída. Cada requisição gera um **trace** único que contém múltiplos **spans** representando operações individuais.

### Terminologia Essencial

#### Trace
- **Definição**: Representação completa de uma requisição através do sistema
- **Identificador**: trace_id único (128-bit)
- **Composição**: Conjunto de spans relacionados
- **Duração**: Do início da primeira operação até o fim da última

#### Span
- **Definição**: Unidade básica de trabalho em um trace
- **Identificador**: span_id único (64-bit) + trace_id
- **Atributos**: Nome da operação, timestamps, tags, logs
- **Relacionamentos**: Parent-child entre spans

#### Context Propagation
- **Definição**: Mecanismo para passar informações de trace entre serviços
- **Implementação**: Headers HTTP, message queues, etc.
- **Padrão**: Jaeger native format ou B3 propagation

### Arquitetura Jaeger

#### Componentes Principais

**Jaeger Agent**
- **Função**: Coleta traces localmente das aplicações
- **Protocolo**: UDP (baixa latência) ou HTTP
- **Localização**: Sidecar ou daemon no host da aplicação
- **Porta padrão**: 6832 (UDP), 14268 (HTTP)

**Jaeger Collector**
- **Função**: Recebe traces dos agents, valida e armazena
- **Protocolo**: gRPC, HTTP, Kafka
- **Responsabilidades**: Batching, validação, sampling
- **Porta padrão**: 14267 (gRPC), 14268 (HTTP)

**Jaeger Query**
- **Função**: Interface de consulta e API
- **Componentes**: Backend API + Jaeger UI
- **Funcionalidades**: Busca, visualização, análise
- **Porta padrão**: 16686 (UI), 16687 (gRPC)

**Storage Backend**
- **Opções**: Elasticsearch, Cassandra, Kafka, Memory
- **Escolha**: Elasticsearch (melhor para desenvolvimento e produção pequena)
- **Configuração**: Via variáveis de ambiente

## Instrumentação de Aplicações

### Jaeger Client Libraries (Nativo)

#### Vantagens
- Controle total sobre instrumentação
- Menor overhead comparado ao OpenTelemetry
- Integração direta com Jaeger
- Suporte a sampling avançado

#### Instrumentação Node.js

**Configuração Básica**
```javascript
const initJaegerTracer = require('jaeger-client').initTracer;
const opentracing = require('opentracing');

function initTracer(serviceName) {
  const config = {
    serviceName: serviceName,
    sampler: {
      type: 'const',
      param: 1,
    },
    reporter: {
      logSpans: true,
      agentHost: process.env.JAEGER_AGENT_HOST || 'localhost',
      agentPort: process.env.JAEGER_AGENT_PORT || 6832,
    },
  };

  const tracer = initJaegerTracer(config);
  opentracing.initGlobalTracer(tracer);
  
  return tracer;
}
```

**Instrumentação Manual**
```javascript
const tracer = opentracing.globalTracer();

app.get('/api/users', async (req, res) => {
  const span = tracer.startSpan('get_users');
  
  try {
    span.setTag('http.method', 'GET');
    span.setTag('http.url', req.url);
    
    const users = await getUsersFromDatabase();
    
    span.setTag('users.count', users.length);
    res.json(users);
  } catch (error) {
    span.setTag(opentracing.Tags.ERROR, true);
    span.log({
      'event': 'error',
      'error.object': error,
      'message': error.message,
    });
    res.status(500).json({ error: 'Failed to get users' });
  } finally {
    span.finish();
  }
});
```

#### Instrumentação Python

**Configuração Básica**
```python
import opentracing
from jaeger_client import Config

def initialize_tracing():
    config = Config(
        config={
            'sampler': {
                'type': 'const',
                'param': 1,
            },
            'local_agent': {
                'reporting_host': 'localhost',
                'reporting_port': 6832,
            },
            'logging': True,
        },
        service_name='backend-service',
        validate=True,
    )
    
    tracer = config.initialize_tracer()
    opentracing.set_global_tracer(tracer)
    
    return tracer
```

**Instrumentação Manual**
```python
tracer = opentracing.global_tracer()

@app.route('/api/users')
def get_users():
    span = tracer.start_span("get_users")
    span.set_tag("http.method", "GET")
    span.set_tag("operation.name", "get_users")
    
    try:
        users = User.query.all()
        users_data = [user.to_dict() for user in users]
        
        span.set_tag("users.count", len(users_data))
        return jsonify(users_data)
        
    except Exception as e:
        span.set_tag(opentracing.Tags.ERROR, True)
        span.log_kv({
            'event': 'error',
            'error.object': e,
            'message': str(e),
        })
        raise
    finally:
        span.finish()
```

## Estratégias de Sampling

### Tipos de Sampling

#### Constant Sampling
- **Configuração**: `type: 'const'`
- **Parâmetro**: `param: 1` (100%) ou `param: 0` (0%)
- **Uso**: Desenvolvimento, debugging

#### Probabilistic Sampling
- **Configuração**: `type: 'probabilistic'`
- **Parâmetro**: `param: 0.01` (1%)
- **Uso**: Produção com alto volume

#### Rate Limiting Sampling
- **Configuração**: `type: 'ratelimiting'`
- **Parâmetro**: `param: 100` (100 traces/segundo)
- **Uso**: Controle de volume fixo

#### Remote Sampling
- **Configuração**: Via Jaeger Collector
- **Funcionamento**: Configuração centralizada
- **Uso**: Produção com múltiplos serviços

### Configuração de Sampling

**Per-Service Configuration**
```json
{
  "default_strategy": {
    "type": "probabilistic",
    "param": 0.1
  },
  "per_service_strategies": [
    {
      "service": "frontend-service",
      "type": "probabilistic",
      "param": 1.0,
      "max_traces_per_second": 100
    },
    {
      "service": "backend-service",
      "type": "probabilistic", 
      "param": 0.5,
      "max_traces_per_second": 200
    }
  ]
}
```

**Environment Variables**
```bash
# Constant sampling (100%)
JAEGER_SAMPLER_TYPE=const
JAEGER_SAMPLER_PARAM=1

# Probabilistic sampling (10%)
JAEGER_SAMPLER_TYPE=probabilistic
JAEGER_SAMPLER_PARAM=0.1

# Rate limiting (100 traces/sec)
JAEGER_SAMPLER_TYPE=ratelimiting
JAEGER_SAMPLER_PARAM=100
```

## Análise de Traces

### Jaeger UI - Funcionalidades

#### Search Interface
- **Service**: Filtrar por serviço específico
- **Operation**: Filtrar por operação/endpoint
- **Tags**: Filtrar por tags customizadas (user.id, order.id)
- **Duration**: Filtrar por duração mín/máx
- **Time Range**: Período de busca
- **Limit**: Número máximo de traces

#### Trace View
- **Timeline**: Visualização temporal dos spans
- **Service Map**: Dependências entre serviços
- **Span Details**: Tags, logs, processo
- **Critical Path**: Caminho que determina latência total
- **Gantt Chart**: Visualização de paralelismo

#### Comparação de Traces
- **Diff View**: Comparar dois traces similares
- **Performance**: Identificar regressões
- **Debugging**: Encontrar diferenças em comportamento

### Identificação de Problemas

#### Latência Alta
```
Sintomas:
- Traces com duração > threshold esperado
- Spans com tempo excessivo
- Gaps entre spans (network latency)
- Operações sequenciais que poderiam ser paralelas

Investigação:
1. Identificar span mais lento no critical path
2. Verificar tags do span (db.statement, http.url)
3. Analisar logs do span para detalhes
4. Correlacionar com métricas de infraestrutura
5. Verificar se operações podem ser otimizadas
```

#### Erros e Falhas
```
Sintomas:
- Spans com tag error=true
- Traces incompletos (spans não finalizados)
- Exceções registradas nos logs

Investigação:
1. Filtrar por error=true na busca
2. Examinar span logs para stack traces
3. Verificar propagação de erro entre serviços
4. Correlacionar com logs de aplicação
5. Identificar padrões de falha
```

#### Gargalos de Performance
```
Sintomas:
- Spans com alta frequência e duração
- Operações de banco lentas
- Chamadas externas demoradas
- Cache misses frequentes

Investigação:
1. Agrupar traces por operação
2. Calcular percentis (p50, p95, p99)
3. Identificar padrões temporais
4. Analisar distribuição de latência
5. Correlacionar com métricas de sistema
```

## Context Propagation

### HTTP Headers

#### Jaeger Native Format
```
uber-trace-id: {trace-id}:{span-id}:{parent-span-id}:{flags}

Exemplo:
uber-trace-id: 5b2b4e5f8c7d6a9b:1a2b3c4d5e6f7890:0:1
```

#### B3 Propagation
```
X-B3-TraceId: {trace-id}
X-B3-SpanId: {span-id}
X-B3-ParentSpanId: {parent-span-id}
X-B3-Sampled: {0|1}
```

#### Implementação
```javascript
// Node.js - Injeção
const headers = {};
tracer.inject(span, opentracing.FORMAT_HTTP_HEADERS, headers);

// Node.js - Extração
const parentSpanContext = tracer.extract(opentracing.FORMAT_HTTP_HEADERS, req.headers);
const span = tracer.startSpan('operation', { childOf: parentSpanContext });
```

```python
# Python - Injeção
headers = {}
tracer.inject(span, opentracing.Format.HTTP_HEADERS, headers)

# Python - Extração
span_ctx = tracer.extract(opentracing.Format.HTTP_HEADERS, request.headers)
span = tracer.start_span('operation', child_of=span_ctx)
```

## Correlação com Logs e Métricas

### Trace ID em Logs

**Configuração de Logging**
```javascript
// Node.js com Winston
const winston = require('winston');

const logger = winston.createLogger({
  format: winston.format.combine(
    winston.format.timestamp(),
    winston.format.printf(({ timestamp, level, message }) => {
      const span = opentracing.globalTracer().activeSpan();
      const traceId = span ? span.context().toTraceId() : 'no-trace';
      return `${timestamp} [${level}] [trace_id=${traceId}] ${message}`;
    })
  )
});
```

```python
# Python com structlog
import structlog
import opentracing

def add_trace_id(logger, method_name, event_dict):
    span = opentracing.global_tracer().active_span
    if span:
        event_dict['trace_id'] = '{:x}'.format(span.context.trace_id)
    return event_dict

structlog.configure(
    processors=[
        add_trace_id,
        structlog.processors.JSONRenderer()
    ]
)
```

### Consultas Correlacionadas

**LogQL com Trace ID**
```logql
# Todos os logs de um trace específico
{job=~"frontend-service|backend-service"} | json | trace_id="5b2b4e5f8c7d6a9b"

# Logs de erro com trace_id
{level="error"} | json | trace_id!=""

# Correlação temporal com traces
{job="backend-service"} | json | trace_id!="" and timestamp > now() - 1h
```

**PromQL com Labels de Trace**
```promql
# Métricas por serviço (correlacionar com traces)
http_requests_total{service="frontend-service"}

# Latência de requisições (correlacionar com span duration)
histogram_quantile(0.95, http_request_duration_seconds_bucket)

# Taxa de erro (correlacionar com spans de erro)
rate(http_requests_total{status=~"5.."}[5m])
```

### Dashboards Unificados

**Grafana Dashboard Structure**
```
Row 1: Overview Metrics
- Request rate, error rate, latency (RED metrics)
- Service dependency graph

Row 2: Trace Analysis  
- Trace count by service
- Average trace duration
- Error traces percentage
- Sampling rate

Row 3: Log Correlation
- Error logs with trace_id
- Log volume by service
- Recent traces with errors

Row 4: Infrastructure
- Resource usage by service
- Database performance
- Cache hit rates
- Network latency
```

## Best Practices

### Instrumentação

1. **Start Simple**: Comece com instrumentação básica nos endpoints principais
2. **Add Context**: Adicione spans manuais para operações críticas de negócio
3. **Meaningful Names**: Use nomes descritivos para operações (get_user_orders, process_payment)
4. **Rich Tags**: Adicione tags relevantes (user_id, order_id, payment_method)
5. **Error Handling**: Sempre marque spans com erro e adicione logs detalhados

### Performance

1. **Sampling Strategy**: Configure sampling adequado para produção (1-10%)
2. **Async Reporting**: Use reporter assíncrono para reduzir latência
3. **Batch Size**: Configure batch size apropriado (10-100 spans)
4. **Resource Limits**: Monitore overhead de instrumentação (<5% CPU)

### Operacional

1. **Storage Planning**: Planeje retenção baseada em volume (7-30 dias)
2. **Monitoring**: Monitore o próprio sistema de tracing
3. **Alerting**: Configure alertas para falhas de coleta
4. **Documentation**: Documente convenções de naming e tagging

### Segurança

1. **Sensitive Data**: Nunca inclua dados sensíveis em spans (senhas, tokens)
2. **Access Control**: Controle acesso ao Jaeger UI
3. **Network Security**: Use TLS para comunicação em produção
4. **Data Retention**: Configure retenção adequada para compliance

## Troubleshooting

### Traces Não Aparecem

**Checklist de Diagnóstico:**
1. Verificar configuração do agent (host/port)
2. Testar conectividade: `telnet jaeger-agent 6832`
3. Verificar logs da aplicação para erros de tracing
4. Confirmar sampling configuration (não está 0%)
5. Verificar storage backend (Elasticsearch health)

### Performance Issues

**Sintomas e Soluções:**
- **Alta latência**: Reduzir sampling rate ou usar async reporter
- **Overhead de CPU**: Ajustar batch size e flush interval
- **Overhead de memória**: Limitar queue size
- **Network overhead**: Usar UDP para agent communication

### Dados Incompletos

**Possíveis Causas:**
- Context propagation falhou (headers não propagados)
- Spans não foram finalizados (missing span.finish())
- Timeout na coleta (ajustar reporter timeout)
- Problemas de storage (Elasticsearch disk space)

## Métricas do Jaeger

### Agent Metrics
```promql
# Spans recebidos pelo agent
jaeger_agent_spans_received_total

# Spans enviados para collector
jaeger_agent_spans_sent_total

# Queue length do agent
jaeger_agent_queue_length
```

### Collector Metrics
```promql
# Spans processados pelo collector
jaeger_collector_spans_received_total

# Spans salvos no storage
jaeger_collector_spans_saved_total

# Latência de processamento
jaeger_collector_save_latency_bucket
```

### Query Metrics
```promql
# Requests para UI
jaeger_query_requests_total

# Latência de consultas
jaeger_query_request_duration_seconds

# Traces encontrados
jaeger_query_traces_found_total
```

### Storage Metrics (Elasticsearch)
```promql
# Elasticsearch cluster health
elasticsearch_cluster_health_status

# Index size
elasticsearch_indices_store_size_bytes{index=~"jaeger-*"}

# Search latency
elasticsearch_indices_search_query_time_seconds{index=~"jaeger-*"}
```

## Configuração Avançada

### Environment Variables

**Jaeger Client (Node.js/Python)**
```bash
# Service identification
JAEGER_SERVICE_NAME=my-service
JAEGER_SERVICE_VERSION=1.0.0

# Agent configuration
JAEGER_AGENT_HOST=jaeger-agent
JAEGER_AGENT_PORT=6832

# Sampling configuration
JAEGER_SAMPLER_TYPE=probabilistic
JAEGER_SAMPLER_PARAM=0.1

# Reporter configuration
JAEGER_REPORTER_LOG_SPANS=true
JAEGER_REPORTER_MAX_QUEUE_SIZE=100
JAEGER_REPORTER_FLUSH_INTERVAL=1000
```

**Jaeger Components**
```bash
# Collector
SPAN_STORAGE_TYPE=elasticsearch
ES_SERVER_URLS=http://elasticsearch:9200
COLLECTOR_ZIPKIN_HOST_PORT=:9411

# Query
SPAN_STORAGE_TYPE=elasticsearch
ES_SERVER_URLS=http://elasticsearch:9200
QUERY_BASE_PATH=/jaeger

# Agent
REPORTER_GRPC_HOST_PORT=jaeger-collector:14250
```