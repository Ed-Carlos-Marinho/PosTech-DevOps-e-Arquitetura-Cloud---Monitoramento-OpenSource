# 📖 Referência Rápida - Instrumentação Jaeger

Guia de consulta rápida para instrumentação Jaeger. Use como cola durante o desenvolvimento!

---

## 🎯 Dois Arquivos, Duas Funções

| Arquivo | Função | Quando Executa |
|---------|--------|----------------|
| **`tracing.js`** | 📋 Configuração | 1x no startup |
| **`server.js`** | 🔧 Instrumentação | A cada requisição |

---

## 📋 Template: `tracing.js` (Configuração)

```javascript
const jaeger = require('jaeger-client');
const opentracing = require('opentracing');

const config = {
  serviceName: 'meu-servico',           // Nome no Jaeger
  sampler: {
    type: 'const',                      // const, probabilistic, ratelimiting
    param: 1,                           // 1 = 100%, 0.1 = 10%
  },
  reporter: {
    agentHost: 'jaeger-agent',          // Host do agent
    agentPort: 6832,                    // Porta UDP
    logSpans: true,                     // Log no console
    flushIntervalMs: 2000,              // Envia a cada 2s
  },
};

const tracer = jaeger.initTracer(config);
opentracing.initGlobalTracer(tracer);

module.exports = tracer;
```

**Variáveis de Ambiente:**
```bash
JAEGER_SERVICE_NAME=meu-servico
JAEGER_AGENT_HOST=jaeger-agent
JAEGER_AGENT_PORT=6832
JAEGER_SAMPLER_TYPE=const
JAEGER_SAMPLER_PARAM=1
```

---

## 🔧 Template: `server.js` (Instrumentação)

### 1. Importar Tracer

```javascript
const tracer = require('./tracing');
const opentracing = require('opentracing');
```

### 2. Middleware (Span Automático)

```javascript
app.use((req, res, next) => {
  // Extrair contexto (se vier de outro serviço)
  const parentSpanContext = tracer.extract(
    opentracing.FORMAT_HTTP_HEADERS, 
    req.headers
  );
  
  // Criar span
  const span = tracer.startSpan(`${req.method} ${req.path}`, {
    childOf: parentSpanContext,
    tags: {
      [opentracing.Tags.HTTP_METHOD]: req.method,
      [opentracing.Tags.HTTP_URL]: req.originalUrl,
    },
  });
  
  req.span = span;
  
  // Finalizar quando resposta for enviada
  res.on('finish', () => {
    span.setTag(opentracing.Tags.HTTP_STATUS_CODE, res.statusCode);
    span.finish();
  });
  
  next();
});
```

### 3. Rota (Span Manual)

```javascript
app.get('/api/users', async (req, res) => {
  // ⚠️ Criar span ANTES de qualquer processamento
  const span = tracer.startSpan('get_users', { childOf: req.span });
  
  try {
    // Adicionar tags
    span.setTag('operation.name', 'get_users');
    span.setTag('backend.url', BACKEND_URL);
    
    // Seu código aqui
    await doSomething();
    
    // Propagar contexto para outro serviço
    const headers = {};
    tracer.inject(span, opentracing.FORMAT_HTTP_HEADERS, headers);
    const response = await axios.get(url, { headers });
    
    // Adicionar mais tags
    span.setTag('users.count', response.data.length);
    span.log({ event: 'success', count: response.data.length });
    
    res.json(response.data);
    
  } catch (error) {
    // Marcar erro
    span.setTag(opentracing.Tags.ERROR, true);
    span.log({
      event: 'error',
      message: error.message,
      stack: error.stack,
    });
    
    res.status(500).json({ error: 'Failed' });
  } finally {
    // ⚠️ SEMPRE finalizar
    span.finish();
  }
});
```

---

## 🔗 Context Propagation (Conectar Serviços)

### Cliente (Quem Chama)

```javascript
// Criar headers com contexto
const headers = {};
tracer.inject(span, opentracing.FORMAT_HTTP_HEADERS, headers);

// Fazer chamada COM headers
const response = await axios.get(url, { headers });
```

### Servidor (Quem Recebe)

```javascript
// Extrair contexto dos headers
const parentSpanContext = tracer.extract(
  opentracing.FORMAT_HTTP_HEADERS, 
  req.headers
);

// Criar span filho
const span = tracer.startSpan('operation', {
  childOf: parentSpanContext  // ← Conecta com span pai
});
```

---

## 🏷️ Tags Comuns

### HTTP
```javascript
span.setTag(opentracing.Tags.HTTP_METHOD, 'GET');
span.setTag(opentracing.Tags.HTTP_URL, 'http://api.com/users');
span.setTag(opentracing.Tags.HTTP_STATUS_CODE, 200);
span.setTag('http.response_size', 1024);
```

### Database
```javascript
span.setTag('db.type', 'postgresql');
span.setTag('db.name', 'ecommerce');
span.setTag('db.table', 'users');
span.setTag('db.operation', 'SELECT');
span.setTag('db.rows_affected', 10);
```

### Cache
```javascript
span.setTag('cache.system', 'redis');
span.setTag('cache.key', 'users_list');
span.setTag('cache.hit', true);
span.setTag('cache.ttl', 300);
```

### Business Logic
```javascript
span.setTag('user.id', 'user_123');
span.setTag('order.id', 'order_456');
span.setTag('order.total', 99.99);
span.setTag('payment.method', 'credit_card');
```

### Erro
```javascript
span.setTag(opentracing.Tags.ERROR, true);
```

---

## 📝 Logs de Eventos

```javascript
// Evento simples
span.log({ event: 'cache_miss' });

// Evento com dados
span.log({ 
  event: 'user_validated', 
  user_id: 123,
  validation_time_ms: 50 
});

// Erro detalhado
span.log({
  event: 'error',
  'error.object': error,
  'error.kind': error.name,
  message: error.message,
  stack: error.stack,
});
```

---

## ⚠️ Checklist de Instrumentação

### Antes de Testar

- [ ] `tracing.js` configurado com host e porta corretos
- [ ] Tracer inicializado e exportado
- [ ] `server.js` importa tracer
- [ ] Middleware cria span para cada requisição
- [ ] Spans criados ANTES do processamento
- [ ] Contexto propagado em chamadas externas
- [ ] Spans finalizados com `span.finish()`
- [ ] Try-finally usado para garantir finalização

### Validação no Jaeger UI

- [ ] Spans aparecem no Jaeger (http://IP:16686)
- [ ] Hierarquia pai-filho está correta
- [ ] Duração captura operação completa
- [ ] Tags estão visíveis
- [ ] Logs estão visíveis
- [ ] Trace_id propagado entre serviços

---

## 🐛 Troubleshooting

### Problema: Spans não aparecem

```bash
# 1. Verificar logs da aplicação
docker-compose logs frontend

# 2. Verificar logs do Jaeger Agent
docker-compose logs jaeger-agent

# 3. Verificar conectividade
docker exec frontend ping jaeger-agent

# 4. Verificar configuração
echo $JAEGER_AGENT_HOST
echo $JAEGER_AGENT_PORT
```

**Soluções:**
- ✅ Verificar `agentHost` e `agentPort` em `tracing.js`
- ✅ Verificar se `span.finish()` está sendo chamado
- ✅ Verificar se sampling não está em 0%

### Problema: Spans desconectados

**Causa:** Span criado DEPOIS do processamento

```javascript
// ❌ ERRADO
await doWork();
const span = tracer.startSpan('operation');

// ✅ CORRETO
const span = tracer.startSpan('operation');
await doWork();
```

**Causa:** Contexto não propagado

```javascript
// ❌ ERRADO
await axios.get(url);

// ✅ CORRETO
const headers = {};
tracer.inject(span, opentracing.FORMAT_HTTP_HEADERS, headers);
await axios.get(url, { headers });
```

### Problema: Duração errada

**Causa:** Span não captura operação completa

```javascript
// ❌ ERRADO - Processamento antes do span
await doWork();
const span = tracer.startSpan('operation');
span.finish();

// ✅ CORRETO - Span engloba tudo
const span = tracer.startSpan('operation');
await doWork();
span.finish();
```

---

## 🎯 Padrões de Uso

### Padrão 1: Operação Simples

```javascript
const span = tracer.startSpan('operation_name');
try {
  span.setTag('key', 'value');
  await doWork();
  span.log({ event: 'success' });
} catch (error) {
  span.setTag(opentracing.Tags.ERROR, true);
  span.log({ event: 'error', message: error.message });
  throw error;
} finally {
  span.finish();
}
```

### Padrão 2: Chamada Externa

```javascript
const span = tracer.startSpan('external_call', { childOf: parentSpan });
try {
  span.setTag(opentracing.Tags.HTTP_METHOD, 'GET');
  span.setTag(opentracing.Tags.HTTP_URL, url);
  
  const headers = {};
  tracer.inject(span, opentracing.FORMAT_HTTP_HEADERS, headers);
  
  const response = await axios.get(url, { headers });
  
  span.setTag(opentracing.Tags.HTTP_STATUS_CODE, response.status);
  return response.data;
} finally {
  span.finish();
}
```

### Padrão 3: Operação com Cache

```javascript
const span = tracer.startSpan('get_data', { childOf: parentSpan });
try {
  // Tentar cache
  const cached = await cacheGet(key, span);
  if (cached) {
    span.setTag('cache.hit', true);
    return cached;
  }
  
  // Cache miss - buscar no DB
  span.setTag('cache.hit', false);
  const data = await dbQuery(query, span);
  
  // Armazenar no cache
  await cacheSet(key, data, span);
  
  return data;
} finally {
  span.finish();
}
```

### Padrão 4: Operação Aninhada

```javascript
const parentSpan = tracer.startSpan('parent_operation');
try {
  // Operação 1
  const childSpan1 = tracer.startSpan('child_1', { childOf: parentSpan });
  try {
    await operation1();
  } finally {
    childSpan1.finish();
  }
  
  // Operação 2
  const childSpan2 = tracer.startSpan('child_2', { childOf: parentSpan });
  try {
    await operation2();
  } finally {
    childSpan2.finish();
  }
} finally {
  parentSpan.finish();
}
```

---

## 📊 Sampling Strategies

### Desenvolvimento (100%)
```javascript
sampler: {
  type: 'const',
  param: 1,  // 100% das requisições
}
```

### Produção - Probabilístico (10%)
```javascript
sampler: {
  type: 'probabilistic',
  param: 0.1,  // 10% das requisições
}
```

### Produção - Rate Limiting (100 req/s)
```javascript
sampler: {
  type: 'ratelimiting',
  param: 100,  // Máximo 100 traces por segundo
}
```

---

## 🔧 Comandos Úteis

```bash
# Reiniciar serviço
docker-compose restart frontend

# Ver logs em tempo real
docker-compose logs -f frontend

# Ver logs do Jaeger Agent
docker-compose logs -f jaeger-agent

# Testar endpoint
curl http://localhost/api/users

# Testar com trace_id customizado
curl -H "uber-trace-id: 123:456:0:1" http://localhost/api/users

# Acessar Jaeger UI
open http://IP_INSTANCIA_1:16686
```

---

## 📚 Recursos Adicionais

- [Documentação Jaeger](https://www.jaegertracing.io/docs/)
- [OpenTracing API](https://opentracing.io/docs/)
- [Guia Completo de Instrumentação](./instrumentation-guide.md)
- [Guia de Tracing Distribuído](./tracing-guide.md)
- [Exemplos Práticos](./exemplos-praticos-instrumentacao.md)

---

## 💡 Dicas Finais

1. **Sempre criar span ANTES do processamento**
2. **Sempre usar try-finally para garantir span.finish()**
3. **Sempre propagar contexto em chamadas externas**
4. **Sempre marcar erros com ERROR=true**
5. **Adicionar tags relevantes para debugging**
6. **Usar logs para eventos importantes**
7. **Testar no Jaeger UI após cada mudança**

---

**Boa instrumentação! 🚀**
