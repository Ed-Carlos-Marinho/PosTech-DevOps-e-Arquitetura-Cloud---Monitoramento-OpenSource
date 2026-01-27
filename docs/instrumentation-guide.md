# Guia de Instrumentação Jaeger Nativo

Guia prático para instrumentar aplicações com Jaeger Client Libraries nativo para tracing distribuído na Aula 05.

## 📚 Entendendo a Estrutura da Instrumentação

A instrumentação Jaeger é dividida em **duas partes principais** que trabalham juntas:

### 1️⃣ Arquivo de Configuração (`tracing.js` ou `tracing.py`)

Este arquivo é o **"cérebro"** da instrumentação. Ele:

- ✅ **Configura a conexão** com o Jaeger Agent (host, porta)
- ✅ **Define estratégias de sampling** (quantas requisições rastrear)
- ✅ **Inicializa o tracer global** (disponibiliza para toda aplicação)
- ✅ **Configura opções de envio** (batching, flush interval)

**Analogia:** É como configurar o GPS do seu carro - você define o destino (Jaeger Agent), mas ainda não começou a dirigir.

### 2️⃣ Arquivo da Aplicação (`server.js`, `app.py`)

Este arquivo **usa** o tracer configurado para:

- ✅ **Criar spans** para operações importantes
- ✅ **Adicionar tags e logs** com informações de contexto
- ✅ **Propagar contexto** entre serviços (HTTP headers)
- ✅ **Finalizar spans** para enviar ao Jaeger

**Analogia:** É o ato de dirigir - você usa o GPS configurado para navegar e registrar sua jornada.

---

## 🔄 Fluxo Completo de Dados

Entenda como os dados fluem desde sua aplicação até o Jaeger UI:

```
┌─────────────────────────────────────────────────────────────────┐
│ 1. APLICAÇÃO (server.js / app.py)                               │
│    ┌─────────────────────────────────────────────────────────┐  │
│    │ const span = tracer.startSpan('get_users')              │  │
│    │ span.setTag('user.id', 123)                             │  │
│    │ span.finish()  ← Envia para buffer                      │  │
│    └─────────────────────────────────────────────────────────┘  │
└────────────────────────────┬────────────────────────────────────┘
                             │
                             ▼
┌─────────────────────────────────────────────────────────────────┐
│ 2. JAEGER CLIENT (tracing.js / tracing.py)                      │
│    ┌─────────────────────────────────────────────────────────┐  │
│    │ • Coleta spans em buffer                                │  │
│    │ • Aplica sampling (ex: 100% ou 10%)                     │  │
│    │ • Agrupa em batches                                     │  │
│    │ • Envia via UDP a cada 2 segundos                       │  │
│    └─────────────────────────────────────────────────────────┘  │
└────────────────────────────┬────────────────────────────────────┘
                             │
                             ▼ UDP porta 6832
┌─────────────────────────────────────────────────────────────────┐
│ 3. JAEGER AGENT (container local)                               │
│    ┌─────────────────────────────────────────────────────────┐  │
│    │ • Recebe spans via UDP (baixa latência)                 │  │
│    │ • Faz batching adicional                                │  │
│    │ • Envia para Collector via gRPC                         │  │
│    └─────────────────────────────────────────────────────────┘  │
└────────────────────────────┬────────────────────────────────────┘
                             │
                             ▼ gRPC
┌─────────────────────────────────────────────────────────────────┐
│ 4. JAEGER COLLECTOR (Instância 1)                               │
│    ┌─────────────────────────────────────────────────────────┐  │
│    │ • Valida spans recebidos                                │  │
│    │ • Processa e normaliza dados                            │  │
│    │ • Armazena no backend (Elasticsearch/Memory)            │  │
│    └─────────────────────────────────────────────────────────┘  │
└────────────────────────────┬────────────────────────────────────┘
                             │
                             ▼
┌─────────────────────────────────────────────────────────────────┐
│ 5. JAEGER UI (http://IP:16686)                                  │
│    ┌─────────────────────────────────────────────────────────┐  │
│    │ • Consulta spans armazenados                            │  │
│    │ • Monta visualização de traces                          │  │
│    │ • Exibe timeline e dependências                         │  │
│    └─────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────┘
```

---

## 📋 Comparação: Configuração vs Instrumentação

| Aspecto | `tracing.js` (Configuração) | `server.js` (Instrumentação) |
|---------|----------------------------|------------------------------|
| **Propósito** | Configurar **como** enviar dados | Criar e enviar **os dados** |
| **Executa quando?** | Uma vez no startup | A cada requisição/operação |
| **Responsabilidades** | • Conexão com agent<br>• Sampling<br>• Batching<br>• Flush interval | • Criar spans<br>• Adicionar tags<br>• Propagar contexto<br>• Finalizar spans |
| **Analogia** | Configurar o sistema de GPS | Usar o GPS durante a viagem |
| **Código típico** | `initTracer(config)`<br>`opentracing.initGlobalTracer()` | `tracer.startSpan()`<br>`span.setTag()`<br>`span.finish()` |

---

## 🎯 Exemplo Prático Completo

Vamos ver como os dois arquivos trabalham juntos em uma aplicação real:

### Passo 1: Configuração (`tracing.js`)

```javascript
// distributed-app/frontend/tracing.js
const jaeger = require('jaeger-client');
const opentracing = require('opentracing');

// 📋 CONFIGURAÇÃO: Define COMO enviar dados
const config = {
  serviceName: 'frontend-service',  // Nome do serviço no Jaeger
  
  sampler: {
    type: 'const',   // Tipo de sampling
    param: 1,        // 1 = 100% das requisições
  },
  
  reporter: {
    agentHost: 'jaeger-agent',  // 🎯 Onde está o agent
    agentPort: 6832,            // 🎯 Porta UDP
    logSpans: true,             // Log spans no console
    flushIntervalMs: 2000,      // Envia a cada 2 segundos
  },
};

// 🚀 INICIALIZAÇÃO: Cria o tracer
const tracer = jaeger.initTracer(config);
opentracing.initGlobalTracer(tracer);  // Disponibiliza globalmente

console.log('✅ Jaeger configurado e pronto para uso!');

module.exports = tracer;  // Exporta para uso na aplicação
```

**O que acontece aqui?**
- ✅ Jaeger Client é configurado para enviar dados para `jaeger-agent:6832`
- ✅ Sampling está em 100% (todas as requisições serão rastreadas)
- ✅ Spans serão enviados em batches a cada 2 segundos
- ✅ Tracer fica disponível globalmente via `opentracing.globalTracer()`

---

### Passo 2: Instrumentação (`server.js`)

```javascript
// distributed-app/frontend/server.js
const express = require('express');
const axios = require('axios');
const opentracing = require('opentracing');

// 📥 IMPORTAR: Usa o tracer configurado
const tracer = require('./tracing');

const app = express();
const BACKEND_URL = 'http://backend:5000';

// 🎯 MIDDLEWARE: Cria span para CADA requisição
app.use((req, res, next) => {
  // Extrair contexto de trace (se vier de outro serviço)
  const parentSpanContext = tracer.extract(
    opentracing.FORMAT_HTTP_HEADERS, 
    req.headers
  );
  
  // Criar span para esta requisição
  const span = tracer.startSpan(`${req.method} ${req.path}`, {
    childOf: parentSpanContext,  // Conecta com span pai (se existir)
    tags: {
      [opentracing.Tags.HTTP_METHOD]: req.method,
      [opentracing.Tags.HTTP_URL]: req.originalUrl,
      [opentracing.Tags.SPAN_KIND]: 'server',
    },
  });
  
  req.span = span;  // Disponibiliza para as rotas
  
  // Finalizar span quando resposta for enviada
  res.on('finish', () => {
    span.setTag(opentracing.Tags.HTTP_STATUS_CODE, res.statusCode);
    span.finish();  // 🚀 Envia para o Jaeger Agent
  });
  
  next();
});

// 🔧 ROTA: Instrumentação manual
app.get('/api/users', async (req, res) => {
  // ⚠️ IMPORTANTE: Criar span ANTES de qualquer processamento
  const span = tracer.startSpan('get_users', { 
    childOf: req.span  // Span filho do middleware
  });
  
  try {
    // Adicionar informações de contexto
    span.setTag('operation.name', 'get_users');
    span.setTag('backend.url', `${BACKEND_URL}/api/users`);
    
    // Simular processamento (200ms)
    await new Promise(resolve => setTimeout(resolve, 200));
    
    // 🔗 PROPAGAR CONTEXTO: Injetar trace nos headers
    const headers = {};
    tracer.inject(span, opentracing.FORMAT_HTTP_HEADERS, headers);
    
    // Chamar backend COM contexto propagado
    const response = await axios.get(`${BACKEND_URL}/api/users`, { 
      headers  // ← Headers contêm trace_id e span_id
    });
    
    // Adicionar informações do resultado
    span.setTag('http.status_code', response.status);
    span.setTag('users.count', response.data.length);
    span.log({ event: 'users_fetched', count: response.data.length });
    
    res.json(response.data);
    
  } catch (error) {
    // Marcar erro no span
    span.setTag(opentracing.Tags.ERROR, true);
    span.log({
      event: 'error',
      message: error.message,
      stack: error.stack,
    });
    
    res.status(500).json({ error: 'Failed to fetch users' });
  } finally {
    span.finish();  // 🚀 Envia span para o Jaeger Agent
  }
});

app.listen(3000, () => {
  console.log('🚀 Frontend rodando na porta 3000');
  console.log('🔍 Jaeger tracing ativo!');
});
```

**O que acontece aqui?**
1. ✅ **Middleware** cria span automático para cada requisição HTTP
2. ✅ **Rota** cria span filho para operação específica (`get_users`)
3. ✅ **Tags** adicionam contexto (URL, status, contagem)
4. ✅ **Context propagation** injeta trace_id nos headers HTTP
5. ✅ **Error handling** marca erros no span
6. ✅ **span.finish()** envia dados para o Jaeger Agent

---

## 🔍 Visualizando o Resultado no Jaeger

Após fazer uma requisição `GET /api/users`, você verá no Jaeger UI:

```
Trace: 5b2b4e5f8c7d6a9b (trace_id)
Duration: 450ms
Spans: 5

├─ frontend-service: GET /api/users (450ms)
│  └─ frontend-service: get_users (430ms)
│     └─ backend-service: GET /api/users (400ms)
│        ├─ backend-service: get_users (380ms)
│        │  ├─ backend-service: redis_get (20ms) ← Cache miss
│        │  └─ backend-service: postgres_query (300ms) ← Query DB
│        └─ backend-service: redis_set (15ms) ← Armazenar cache
```

**Informações visíveis:**
- ✅ Hierarquia completa (spans pai-filho)
- ✅ Duração de cada operação
- ✅ Tags: `http.status_code=200`, `users.count=10`
- ✅ Logs: `cache_lookup`, `query_completed`
- ✅ Erros (se houver)

---

## ⚠️ Erros Comuns e Como Evitar

### ❌ Erro 1: Criar span DEPOIS do processamento

```javascript
// ❌ ERRADO - Processamento não é capturado
app.get('/api/users', async (req, res) => {
  await new Promise(resolve => setTimeout(resolve, 200));  // Processamento
  const span = tracer.startSpan('get_users');  // Span criado tarde demais!
  // ...
});
```

```javascript
// ✅ CORRETO - Span captura tudo
app.get('/api/users', async (req, res) => {
  const span = tracer.startSpan('get_users');  // Criar PRIMEIRO
  await new Promise(resolve => setTimeout(resolve, 200));  // Processamento
  // ...
});
```

### ❌ Erro 2: Esquecer de propagar contexto

```javascript
// ❌ ERRADO - Backend não recebe contexto
const response = await axios.get(url);  // Sem headers!
```

```javascript
// ✅ CORRETO - Contexto propagado
const headers = {};
tracer.inject(span, opentracing.FORMAT_HTTP_HEADERS, headers);
const response = await axios.get(url, { headers });
```

### ❌ Erro 3: Não finalizar span

```javascript
// ❌ ERRADO - Span nunca é enviado
const span = tracer.startSpan('operation');
await doSomething();
// Esqueceu span.finish()!
```

```javascript
// ✅ CORRETO - Sempre usar try-finally
const span = tracer.startSpan('operation');
try {
  await doSomething();
} finally {
  span.finish();  // Garante envio mesmo com erro
}
```

---

## 📊 Checklist de Instrumentação

Use este checklist para garantir instrumentação correta:

- [ ] **Configuração (`tracing.js`)**
  - [ ] Jaeger Agent host e porta configurados
  - [ ] Sampling definido (100% dev, 1-10% prod)
  - [ ] Tracer inicializado e exportado
  - [ ] Graceful shutdown configurado

- [ ] **Instrumentação (`server.js`)**
  - [ ] Middleware cria span para cada requisição
  - [ ] Spans criados ANTES do processamento
  - [ ] Tags relevantes adicionadas (http.method, http.url)
  - [ ] Contexto propagado em chamadas externas
  - [ ] Erros marcados com `ERROR=true`
  - [ ] Spans finalizados com `span.finish()`
  - [ ] Try-finally usado para garantir finalização

- [ ] **Validação**
  - [ ] Spans aparecem no Jaeger UI
  - [ ] Hierarquia pai-filho correta
  - [ ] Duração captura operação completa
  - [ ] Tags e logs visíveis
  - [ ] Trace_id propagado entre serviços

---

## Instrumentação por Linguagem

### Node.js/JavaScript

#### Dependências Necessárias
```json
{
  "dependencies": {
    "jaeger-client": "^3.19.0",
    "opentracing": "^0.14.7"
  }
}
```

#### Configuração Básica
```javascript
// tracing.js
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

  const options = {
    logger: {
      info: msg => console.log('INFO ', msg),
      error: msg => console.log('ERROR', msg),
    },
  };

  const tracer = initJaegerTracer(config, options);
  opentracing.initGlobalTracer(tracer);
  
  return tracer;
}

module.exports = initTracer;
```

#### Instrumentação Manual
```javascript
const opentracing = require('opentracing');
const tracer = opentracing.globalTracer();

// Span simples
async function processOrder(orderId) {
  const span = tracer.startSpan('process_order');
  
  try {
    span.setTag('order.id', orderId);
    span.setTag('operation.name', 'process_order');
    
    const result = await doProcessing(orderId);
    
    span.setTag('order.status', result.status);
    span.setTag('order.total', result.total);
    
    return result;
  } catch (error) {
    span.setTag(opentracing.Tags.ERROR, true);
    span.log({
      'event': 'error',
      'error.object': error,
      'error.kind': error.name,
      'message': error.message,
      'stack': error.stack,
    });
    throw error;
  } finally {
    span.finish();
  }
}

// Span com contexto parent
async function callExternalAPI(url, parentSpan) {
  const span = tracer.startSpan('external_api_call', { childOf: parentSpan });
  
  span.setTag(opentracing.Tags.HTTP_METHOD, 'GET');
  span.setTag(opentracing.Tags.HTTP_URL, url);
  span.setTag(opentracing.Tags.COMPONENT, 'http-client');
  
  try {
    // Injetar contexto nos headers
    const headers = {};
    tracer.inject(span, opentracing.FORMAT_HTTP_HEADERS, headers);
    
    const response = await fetch(url, { headers });
    
    span.setTag(opentracing.Tags.HTTP_STATUS_CODE, response.status);
    span.setTag('http.response_size', response.headers.get('content-length'));
    
    return response.json();
  } catch (error) {
    span.setTag(opentracing.Tags.ERROR, true);
    span.log({
      'event': 'error',
      'error.object': error,
      'message': error.message,
    });
    throw error;
  } finally {
    span.finish();
  }
}
```

### Python/Flask

#### Dependências Necessárias
```python
# requirements.txt
jaeger-client==4.8.0
opentracing==2.4.0
Flask-OpenTracing==1.1.0
```

#### Configuração Básica
```python
# tracing.py
import os
import opentracing
from jaeger_client import Config

def initialize_tracing():
    config = Config(
        config={
            'sampler': {
                'type': os.getenv('JAEGER_SAMPLER_TYPE', 'const'),
                'param': float(os.getenv('JAEGER_SAMPLER_PARAM', '1')),
            },
            'local_agent': {
                'reporting_host': os.getenv('JAEGER_AGENT_HOST', 'localhost'),
                'reporting_port': int(os.getenv('JAEGER_AGENT_PORT', '6832')),
            },
            'logging': True,
        },
        service_name=os.getenv('JAEGER_SERVICE_NAME', 'backend-service'),
        validate=True,
    )
    
    tracer = config.initialize_tracer()
    opentracing.set_global_tracer(tracer)
    
    return tracer
```

#### Instrumentação Manual
```python
import opentracing
from opentracing.ext import tags

tracer = opentracing.global_tracer()

# Span com context manager
def get_user_orders(user_id):
    span = tracer.start_span("get_user_orders")
    span.set_tag("user.id", user_id)
    span.set_tag("operation.name", "get_user_orders")
    
    try:
        orders = db.session.query(Order).filter_by(user_id=user_id).all()
        
        span.set_tag("orders.count", len(orders))
        span.set_tag("db.table", "orders")
        
        return [order.to_dict() for order in orders]
        
    except Exception as e:
        span.set_tag(tags.ERROR, True)
        span.log_kv({
            'event': 'error',
            'error.object': e,
            'error.kind': e.__class__.__name__,
            'message': str(e),
        })
        raise
    finally:
        span.finish()

# Span aninhado
def process_payment(order_id, amount):
    parent_span = tracer.start_span("process_payment")
    parent_span.set_tag("order.id", order_id)
    parent_span.set_tag("payment.amount", amount)
    
    try:
        # Validação (child span)
        validation_span = tracer.start_span("validate_payment", child_of=parent_span)
        validation_span.set_tag("validation.type", "payment")
        
        try:
            if amount <= 0:
                validation_span.log_kv({"event": "Invalid amount", "amount": amount})
                raise ValueError("Invalid payment amount")
            
            validation_span.log_kv({"event": "Payment validated"})
        finally:
            validation_span.finish()
        
        # Processamento (child span)
        charge_span = tracer.start_span("charge_payment", child_of=parent_span)
        charge_span.set_tag("payment.processor", "stripe")
        
        try:
            # Simular chamada externa
            result = external_payment_api(amount)
            
            charge_span.set_tag("payment.transaction_id", result.transaction_id)
            charge_span.set_tag("payment.status", result.status)
            
            return result
        finally:
            charge_span.finish()
            
    finally:
        parent_span.finish()
```

## Instrumentação de Componentes

### Banco de Dados

#### PostgreSQL/SQLAlchemy
```python
# Manual para queries específicas
def get_user_with_tracing(user_id):
    span = tracer.start_span("db_get_user")
    span.set_tag("db.system", "postgresql")
    span.set_tag("db.name", "ecommerce")
    span.set_tag("db.table", "users")
    span.set_tag("db.operation", "SELECT")
    span.set_tag("user.id", user_id)
    
    try:
        user = User.query.get(user_id)
        
        if user:
            span.set_tag("db.rows_affected", 1)
        else:
            span.log_kv({"event": "User not found"})
            
        return user
    except Exception as e:
        span.set_tag(tags.ERROR, True)
        span.log_kv({
            'event': 'error',
            'error.object': e,
            'message': str(e),
        })
        raise
    finally:
        span.finish()
```

#### Redis
```python
def cache_get_with_tracing(key):
    span = tracer.start_span("cache_get")
    span.set_tag("cache.system", "redis")
    span.set_tag("cache.key", key)
    span.set_tag("cache.operation", "GET")
    
    try:
        value = redis_client.get(key)
        span.set_tag("cache.hit", value is not None)
        
        if value:
            span.log_kv({"event": "Cache hit"})
        else:
            span.log_kv({"event": "Cache miss"})
            
        return value
    except Exception as e:
        span.set_tag(tags.ERROR, True)
        span.log_kv({
            'event': 'error',
            'error.object': e,
            'message': str(e),
        })
        span.set_tag("cache.error", True)
        raise
    finally:
        span.finish()
```

### HTTP Clients

#### Axios (Node.js)
```javascript
async function callBackendAPI(endpoint, data) {
  const span = tracer.startSpan('backend_api_call');
  
  span.setTag(opentracing.Tags.HTTP_METHOD, 'POST');
  span.setTag(opentracing.Tags.HTTP_URL, `${BACKEND_URL}${endpoint}`);
  span.setTag(opentracing.Tags.COMPONENT, 'axios');
  
  try {
    // Injetar contexto nos headers
    const headers = { 'Content-Type': 'application/json' };
    tracer.inject(span, opentracing.FORMAT_HTTP_HEADERS, headers);
    
    const response = await axios.post(`${BACKEND_URL}${endpoint}`, data, {
      timeout: 5000,
      headers: headers
    });
    
    span.setTag(opentracing.Tags.HTTP_STATUS_CODE, response.status);
    span.setTag('http.response_size', JSON.stringify(response.data).length);
    
    return response.data;
  } catch (error) {
    span.setTag(opentracing.Tags.ERROR, true);
    
    if (error.response) {
      span.setTag(opentracing.Tags.HTTP_STATUS_CODE, error.response.status);
      span.setTag('error.type', 'http_error');
    } else {
      span.setTag('error.type', 'network_error');
    }
    
    span.log({
      'event': 'error',
      'error.object': error,
      'message': error.message,
    });
    
    throw error;
  } finally {
    span.finish();
  }
}
```

#### Requests (Python)
```python
def call_external_service(url, payload):
    span = tracer.start_span("external_service_call")
    span.set_tag(tags.HTTP_METHOD, "POST")
    span.set_tag(tags.HTTP_URL, url)
    span.set_tag(tags.COMPONENT, "requests")
    
    try:
        # Injetar contexto nos headers
        headers = {'Content-Type': 'application/json'}
        tracer.inject(span, opentracing.Format.HTTP_HEADERS, headers)
        
        response = requests.post(url, json=payload, timeout=10, headers=headers)
        
        span.set_tag(tags.HTTP_STATUS_CODE, response.status_code)
        span.set_tag("http.response_size", len(response.content))
        
        if response.status_code >= 400:
            span.log_kv({
                "event": "HTTP error",
                "status_code": response.status_code,
                "response_body": response.text[:500]  # Primeiros 500 chars
            })
        
        response.raise_for_status()
        return response.json()
        
    except requests.exceptions.Timeout:
        span.log_kv({"event": "Request timeout"})
        span.set_tag("error.type", "timeout")
        span.set_tag(tags.ERROR, True)
        raise
    except requests.exceptions.RequestException as e:
        span.set_tag(tags.ERROR, True)
        span.log_kv({
            'event': 'error',
            'error.object': e,
            'message': str(e),
        })
        span.set_tag("error.type", "request_error")
        raise
    finally:
        span.finish()
```

### Message Queues

#### RabbitMQ
```python
def publish_message_with_tracing(queue, message):
    span = tracer.start_span("message_publish")
    span.set_tag("messaging.system", "rabbitmq")
    span.set_tag("messaging.destination", queue)
    span.set_tag("messaging.operation", "publish")
    span.set_tag("messaging.message_size", len(message))
    
    try:
        # Injetar contexto na mensagem
        headers = {}
        tracer.inject(span, opentracing.Format.TEXT_MAP, headers)
        
        connection = pika.BlockingConnection(pika.URLParameters(rabbitmq_url))
        channel = connection.channel()
        
        channel.queue_declare(queue=queue, durable=True)
        
        channel.basic_publish(
            exchange='',
            routing_key=queue,
            body=message,
            properties=pika.BasicProperties(
                delivery_mode=2,
                headers=headers  # Contexto de trace
            )
        )
        
        connection.close()
        
        span.set_tag("messaging.success", True)
        span.log_kv({"event": "Message published successfully"})
        
    except Exception as e:
        span.set_tag(tags.ERROR, True)
        span.log_kv({
            'event': 'error',
            'error.object': e,
            'message': str(e),
        })
        span.set_tag("messaging.success", False)
        raise
    finally:
        span.finish()

def consume_message_with_tracing(queue, callback):
    def traced_callback(ch, method, properties, body):
        # Extrair contexto da mensagem
        headers = properties.headers or {}
        span_ctx = tracer.extract(opentracing.Format.TEXT_MAP, headers)
        
        span = tracer.start_span("message_consume", child_of=span_ctx)
        span.set_tag("messaging.system", "rabbitmq")
        span.set_tag("messaging.source", queue)
        span.set_tag("messaging.operation", "consume")
        span.set_tag("messaging.message_size", len(body))
        
        try:
            callback(body)
            span.set_tag("messaging.success", True)
            ch.basic_ack(delivery_tag=method.delivery_tag)
        except Exception as e:
            span.set_tag(tags.ERROR, True)
            span.log_kv({
                'event': 'error',
                'error.object': e,
                'message': str(e),
            })
            span.set_tag("messaging.success", False)
            ch.basic_nack(delivery_tag=method.delivery_tag, requeue=True)
        finally:
            span.finish()
    
    # Setup do consumer...
```

## Context Propagation

### HTTP Headers

#### Injeção (Cliente)
```javascript
// Node.js
const headers = {};
tracer.inject(span, opentracing.FORMAT_HTTP_HEADERS, headers);

const response = await axios.get(url, { headers });
```

```python
# Python
headers = {}
tracer.inject(span, opentracing.Format.HTTP_HEADERS, headers)

response = requests.get(url, headers=headers)
```

#### Extração (Servidor)
```javascript
// Node.js - Express middleware
app.use((req, res, next) => {
  const parentSpanContext = tracer.extract(opentracing.FORMAT_HTTP_HEADERS, req.headers);
  const span = tracer.startSpan(`${req.method} ${req.path}`, {
    childOf: parentSpanContext
  });
  
  req.span = span;
  next();
});
```

```python
# Python - Flask
from flask import request

@app.before_request
def extract_trace_context():
    span_ctx = tracer.extract(opentracing.Format.HTTP_HEADERS, request.headers)
    span = tracer.start_span(f"{request.method} {request.path}", child_of=span_ctx)
    request.span = span
```

### Message Queues

#### RabbitMQ Headers
```python
# Publisher
def publish_with_context(message, parent_span):
    headers = {}
    tracer.inject(parent_span, opentracing.Format.TEXT_MAP, headers)
    
    channel.basic_publish(
        exchange='',
        routing_key='queue',
        body=message,
        properties=pika.BasicProperties(headers=headers)
    )

# Consumer
def consume_with_context(ch, method, properties, body):
    headers = properties.headers or {}
    span_ctx = tracer.extract(opentracing.Format.TEXT_MAP, headers)
    
    span = tracer.start_span("process_message", child_of=span_ctx)
    try:
        # Process message with trace context
        process_message(body)
    finally:
        span.finish()
```

## Tags Semânticas

### HTTP
```python
span.set_tag(tags.HTTP_METHOD, "GET")
span.set_tag(tags.HTTP_URL, "https://api.example.com/users")
span.set_tag("http.scheme", "https")
span.set_tag("http.host", "api.example.com")
span.set_tag("http.target", "/users")
span.set_tag(tags.HTTP_STATUS_CODE, 200)
span.set_tag("http.user_agent", "MyApp/1.0")
```

### Database
```python
span.set_tag("db.system", "postgresql")
span.set_tag("db.name", "ecommerce")
span.set_tag("db.table", "users")
span.set_tag("db.operation", "SELECT")
span.set_tag("db.statement", "SELECT * FROM users WHERE id = ?")
span.set_tag("db.rows_affected", 1)
```

### Messaging
```python
span.set_tag("messaging.system", "rabbitmq")
span.set_tag("messaging.destination", "order_processing")
span.set_tag("messaging.operation", "publish")
span.set_tag("messaging.message_id", "msg_123")
```

### Custom Business Logic
```python
span.set_tag("user.id", "user_123")
span.set_tag("order.id", "order_456")
span.set_tag("order.total", 99.99)
span.set_tag("payment.method", "credit_card")
span.set_tag("inventory.available", True)
```

## Error Handling

### Exception Recording
```javascript
// Node.js
try {
  await riskyOperation();
} catch (error) {
  span.setTag(opentracing.Tags.ERROR, true);
  span.log({
    'event': 'error',
    'error.object': error,
    'error.kind': error.name,
    'message': error.message,
    'stack': error.stack,
  });
  throw error;
}
```

```python
# Python
try:
    risky_operation()
except Exception as e:
    span.set_tag(tags.ERROR, True)
    span.log_kv({
        'event': 'error',
        'error.object': e,
        'error.kind': e.__class__.__name__,
        'message': str(e),
    })
    raise
```

### Custom Events
```python
span.log_kv({"event": "User validation started"})
span.log_kv({"event": "Cache miss", "key": cache_key})
span.log_kv({"event": "Retry attempt", "attempt": 2, "max_retries": 3})
span.log_kv({"event": "Operation completed", "duration_ms": 150})
```

## Performance Considerations

### Sampling
```python
# Configuração de sampling
config = Config(
    config={
        'sampler': {
            'type': 'probabilistic',  # const, probabilistic, ratelimiting
            'param': 0.1,  # 10% sampling
        },
        # ...
    },
    # ...
)
```

### Batch Processing
```python
# Configuração de batch no reporter
config = Config(
    config={
        'reporter': {
            'batch_size': 10,
            'queue_size': 100,
            'flush_interval': 1,
        },
        # ...
    },
    # ...
)
```

## Testing

### Unit Tests
```javascript
// Mock do tracer para testes
const mockTracer = {
  startSpan: jest.fn().mockReturnValue({
    setTag: jest.fn(),
    log: jest.fn(),
    finish: jest.fn(),
  }),
};

// Teste da instrumentação
test('should create span for user operation', () => {
  const span = mockTracer.startSpan('get_user');
  getUserById(123);
  
  expect(span.setTag).toHaveBeenCalledWith('user.id', 123);
});
```

### Integration Tests
```python
# Teste de propagação de contexto
def test_trace_propagation():
    span = tracer.start_span("parent_span")
    span.set_tag("test.name", "propagation")
    
    try:
        # Simular chamada HTTP
        response = client.get('/api/users')
        
        # Verificar se contexto foi propagado
        assert response.headers.get('trace-id') is not None
    finally:
        span.finish()
```

---

## 🎓 Resumo para Alunos

### Estrutura de Arquivos

```
seu-projeto/
├── tracing.js          ← 📋 CONFIGURAÇÃO (executa 1x no startup)
│   ├── Define conexão com Jaeger Agent
│   ├── Configura sampling (100%, 10%, etc)
│   ├── Inicializa tracer global
│   └── Exporta tracer para uso
│
└── server.js           ← 🔧 INSTRUMENTAÇÃO (executa a cada requisição)
    ├── Importa tracer configurado
    ├── Cria spans para operações
    ├── Adiciona tags e logs
    ├── Propaga contexto entre serviços
    └── Finaliza spans (envia para Jaeger)
```

### Fluxo de Trabalho

```
1. CONFIGURAR (tracing.js)
   ↓
   const tracer = jaeger.initTracer(config);
   opentracing.initGlobalTracer(tracer);
   module.exports = tracer;

2. IMPORTAR (server.js)
   ↓
   const tracer = require('./tracing');

3. INSTRUMENTAR (server.js)
   ↓
   const span = tracer.startSpan('operation');
   span.setTag('key', 'value');
   span.finish();

4. VISUALIZAR (Jaeger UI)
   ↓
   http://IP:16686
```

### Regras de Ouro

1. **Sempre criar span ANTES do processamento**
   ```javascript
   const span = tracer.startSpan('operation');  // ← PRIMEIRO
   await doWork();  // ← DEPOIS
   ```

2. **Sempre usar try-finally**
   ```javascript
   const span = tracer.startSpan('operation');
   try {
     await doWork();
   } finally {
     span.finish();  // ← GARANTE envio
   }
   ```

3. **Sempre propagar contexto**
   ```javascript
   const headers = {};
   tracer.inject(span, opentracing.FORMAT_HTTP_HEADERS, headers);
   await axios.get(url, { headers });  // ← COM headers
   ```

4. **Sempre marcar erros**
   ```javascript
   catch (error) {
     span.setTag(opentracing.Tags.ERROR, true);
     span.log({ event: 'error', message: error.message });
   }
   ```

### Diferenças Principais

| `tracing.js` | `server.js` |
|--------------|-------------|
| Configuração | Uso |
| Executa 1x | Executa sempre |
| Define "como" | Define "o que" |
| `initTracer()` | `startSpan()` |
| Exporta tracer | Importa tracer |

### Comandos Úteis

```bash
# Reiniciar serviço após mudanças
docker-compose restart frontend

# Ver logs do Jaeger Agent
docker-compose logs -f jaeger-agent

# Testar endpoint
curl http://localhost/api/users

# Acessar Jaeger UI
http://IP_INSTANCIA_1:16686
```

### Troubleshooting

**Problema:** Spans não aparecem no Jaeger
- ✅ Verificar se `agentHost` e `agentPort` estão corretos
- ✅ Verificar se `span.finish()` está sendo chamado
- ✅ Verificar logs: `docker-compose logs frontend`

**Problema:** Spans aparecem separados (não conectados)
- ✅ Verificar se span é criado ANTES do processamento
- ✅ Verificar se contexto está sendo propagado (tracer.inject)
- ✅ Verificar se backend está extraindo contexto (tracer.extract)

**Problema:** Duração do span está errada
- ✅ Criar span ANTES de qualquer processamento
- ✅ Finalizar span DEPOIS de tudo (no finally)

---

## 📚 Recursos Adicionais

- [Documentação Jaeger](https://www.jaegertracing.io/docs/)
- [OpenTracing Specification](https://opentracing.io/specification/)
- [Guia de Tracing Distribuído](./tracing-guide.md)
- [Referência Rápida](./quick-reference-instrumentacao.md)