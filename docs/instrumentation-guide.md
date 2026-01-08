# Guia de Instrumentação Jaeger Nativo

Guia prático para instrumentar aplicações com Jaeger Client Libraries nativo para tracing distribuído na Aula 05.

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