# 🎯 Exemplos Práticos de Instrumentação

Exemplos lado a lado mostrando a diferença entre código sem instrumentação e com instrumentação Jaeger.

---

## Exemplo 1: Endpoint Simples

### ❌ Sem Instrumentação

```javascript
app.get('/api/users', async (req, res) => {
  try {
    const users = await User.findAll();
    res.json(users);
  } catch (error) {
    console.error('Error:', error);
    res.status(500).json({ error: 'Failed to fetch users' });
  }
});
```

**Problemas:**
- ❌ Sem visibilidade de performance
- ❌ Sem rastreamento entre serviços
- ❌ Difícil debugar problemas em produção
- ❌ Sem métricas de latência

### ✅ Com Instrumentação

```javascript
app.get('/api/users', async (req, res) => {
  // Criar span ANTES de qualquer processamento
  const span = tracer.startSpan('get_users', { childOf: req.span });
  
  try {
    // Adicionar contexto
    span.setTag('operation.name', 'get_users');
    span.setTag('db.table', 'users');
    
    // Operação
    const users = await User.findAll();
    
    // Adicionar resultado
    span.setTag('users.count', users.length);
    span.log({ event: 'users_fetched', count: users.length });
    
    res.json(users);
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
    // Sempre finalizar
    span.finish();
  }
});
```

**Benefícios:**
- ✅ Visibilidade completa de performance
- ✅ Rastreamento entre serviços
- ✅ Debug facilitado com tags e logs
- ✅ Métricas automáticas de latência

---

## Exemplo 2: Chamada entre Serviços

### ❌ Sem Propagação de Contexto

```javascript
// Frontend
app.get('/api/users', async (req, res) => {
  const response = await axios.get('http://backend:5000/api/users');
  res.json(response.data);
});

// Backend
app.get('/api/users', async (req, res) => {
  const users = await User.findAll();
  res.json(users);
});
```

**Resultado no Jaeger:**
```
Trace 1: frontend-service GET /api/users (200ms)

Trace 2: backend-service GET /api/users (150ms)
```
❌ Dois traces separados - sem conexão!

### ✅ Com Propagação de Contexto

```javascript
// Frontend
app.get('/api/users', async (req, res) => {
  const span = tracer.startSpan('get_users', { childOf: req.span });
  
  try {
    // Injetar contexto nos headers
    const headers = {};
    tracer.inject(span, opentracing.FORMAT_HTTP_HEADERS, headers);
    
    // Fazer chamada COM headers
    const response = await axios.get('http://backend:5000/api/users', {
      headers  // ← Contexto propagado aqui
    });
    
    res.json(response.data);
  } finally {
    span.finish();
  }
});

// Backend
app.use((req, res, next) => {
  // Extrair contexto dos headers
  const parentSpanContext = tracer.extract(
    opentracing.FORMAT_HTTP_HEADERS,
    req.headers
  );
  
  // Criar span filho
  const span = tracer.startSpan(`${req.method} ${req.path}`, {
    childOf: parentSpanContext  // ← Conecta com frontend
  });
  
  req.span = span;
  res.on('finish', () => span.finish());
  next();
});

app.get('/api/users', async (req, res) => {
  const span = tracer.startSpan('get_users', { childOf: req.span });
  
  try {
    const users = await User.findAll();
    res.json(users);
  } finally {
    span.finish();
  }
});
```

**Resultado no Jaeger:**
```
Trace 1: (350ms total)
├─ frontend-service GET /api/users (350ms)
│  └─ frontend-service get_users (330ms)
│     └─ backend-service GET /api/users (300ms)
│        └─ backend-service get_users (280ms)
```
✅ Um trace unificado com hierarquia completa!

---

## Exemplo 3: Operação com Cache

### ❌ Sem Instrumentação

```javascript
app.get('/api/products', async (req, res) => {
  try {
    // Tentar cache
    const cached = await redis.get('products');
    if (cached) {
      return res.json(JSON.parse(cached));
    }
    
    // Buscar no banco
    const products = await Product.findAll();
    
    // Armazenar no cache
    await redis.setex('products', 300, JSON.stringify(products));
    
    res.json(products);
  } catch (error) {
    res.status(500).json({ error: 'Failed' });
  }
});
```

**Problemas:**
- ❌ Não sabe se cache está funcionando
- ❌ Não sabe tempo de cada operação
- ❌ Difícil identificar gargalos

### ✅ Com Instrumentação Detalhada

```javascript
app.get('/api/products', async (req, res) => {
  const span = tracer.startSpan('get_products', { childOf: req.span });
  
  try {
    span.setTag('operation.name', 'get_products');
    
    // Span para operação de cache GET
    const cacheGetSpan = tracer.startSpan('redis_get', { childOf: span });
    cacheGetSpan.setTag('cache.key', 'products');
    
    const cached = await redis.get('products');
    
    cacheGetSpan.setTag('cache.hit', cached !== null);
    cacheGetSpan.log({ event: 'cache_lookup', hit: cached !== null });
    cacheGetSpan.finish();
    
    if (cached) {
      span.setTag('cache.hit', true);
      span.log({ event: 'cache_hit' });
      return res.json(JSON.parse(cached));
    }
    
    // Cache miss - buscar no banco
    span.setTag('cache.hit', false);
    span.log({ event: 'cache_miss' });
    
    const dbSpan = tracer.startSpan('postgres_query', { childOf: span });
    dbSpan.setTag('db.table', 'products');
    dbSpan.setTag('db.operation', 'SELECT');
    
    const products = await Product.findAll();
    
    dbSpan.setTag('db.rows_returned', products.length);
    dbSpan.finish();
    
    // Span para operação de cache SET
    const cacheSetSpan = tracer.startSpan('redis_set', { childOf: span });
    cacheSetSpan.setTag('cache.key', 'products');
    cacheSetSpan.setTag('cache.ttl', 300);
    
    await redis.setex('products', 300, JSON.stringify(products));
    
    cacheSetSpan.log({ event: 'cache_stored' });
    cacheSetSpan.finish();
    
    span.setTag('products.count', products.length);
    res.json(products);
    
  } catch (error) {
    span.setTag(opentracing.Tags.ERROR, true);
    span.log({ event: 'error', message: error.message });
    res.status(500).json({ error: 'Failed' });
  } finally {
    span.finish();
  }
});
```

**Resultado no Jaeger:**
```
Trace: get_products (350ms)
├─ redis_get (10ms) [cache.hit=false]
├─ postgres_query (300ms) [db.rows_returned=50]
└─ redis_set (15ms) [cache.ttl=300]
```

**Benefícios:**
- ✅ Vê exatamente onde o tempo é gasto
- ✅ Monitora taxa de cache hit/miss
- ✅ Identifica queries lentas
- ✅ Valida se cache está funcionando

---

## Exemplo 4: Tratamento de Erros

### ❌ Sem Instrumentação Adequada

```javascript
app.post('/api/orders', async (req, res) => {
  try {
    const order = await createOrder(req.body);
    res.json(order);
  } catch (error) {
    console.error('Error:', error);
    res.status(500).json({ error: 'Failed' });
  }
});
```

**Problemas:**
- ❌ Erro só aparece no log
- ❌ Difícil correlacionar com requisição
- ❌ Sem contexto do que causou o erro

### ✅ Com Instrumentação de Erros

```javascript
app.post('/api/orders', async (req, res) => {
  const span = tracer.startSpan('create_order', { childOf: req.span });
  
  try {
    span.setTag('operation.name', 'create_order');
    span.setTag('order.user_id', req.body.user_id);
    span.setTag('order.total', req.body.total);
    
    // Validação
    const validationSpan = tracer.startSpan('validate_order', { childOf: span });
    try {
      if (!req.body.user_id) {
        throw new Error('Missing user_id');
      }
      validationSpan.setTag('validation.success', true);
    } catch (error) {
      validationSpan.setTag('validation.success', false);
      validationSpan.setTag(opentracing.Tags.ERROR, true);
      validationSpan.log({
        event: 'validation_error',
        message: error.message,
        field: 'user_id',
      });
      throw error;
    } finally {
      validationSpan.finish();
    }
    
    // Criar pedido
    const order = await createOrder(req.body);
    
    span.setTag('order.id', order.id);
    span.setTag('order.success', true);
    span.log({ event: 'order_created', order_id: order.id });
    
    res.json(order);
    
  } catch (error) {
    // Marcar erro no span principal
    span.setTag(opentracing.Tags.ERROR, true);
    span.setTag('error.type', error.name);
    span.log({
      event: 'error',
      'error.object': error,
      'error.kind': error.name,
      message: error.message,
      stack: error.stack,
      request_body: req.body,
    });
    
    res.status(500).json({ 
      error: 'Failed to create order',
      trace_id: span.context().toTraceId()  // Retorna trace_id para debug
    });
  } finally {
    span.finish();
  }
});
```

**Resultado no Jaeger (com erro):**
```
Trace: create_order (50ms) [ERROR=true]
└─ validate_order (5ms) [ERROR=true, validation.success=false]
   Logs:
   - event: validation_error
   - message: Missing user_id
   - field: user_id
```

**Benefícios:**
- ✅ Erro visível no Jaeger com contexto completo
- ✅ Stack trace disponível
- ✅ Fácil correlacionar com requisição
- ✅ Trace_id retornado para usuário

---

## Exemplo 5: Operações Paralelas

### ❌ Sem Visibilidade de Paralelismo

```javascript
app.get('/api/dashboard', async (req, res) => {
  try {
    const users = await getUsers();
    const orders = await getOrders();
    const products = await getProducts();
    
    res.json({ users, orders, products });
  } catch (error) {
    res.status(500).json({ error: 'Failed' });
  }
});
```

**Problema:** Operações sequenciais - lento!

### ✅ Com Paralelismo e Instrumentação

```javascript
app.get('/api/dashboard', async (req, res) => {
  const span = tracer.startSpan('get_dashboard', { childOf: req.span });
  
  try {
    span.setTag('operation.name', 'get_dashboard');
    span.log({ event: 'fetching_data_parallel' });
    
    // Executar em paralelo
    const [users, orders, products] = await Promise.all([
      getUsersWithTracing(span),
      getOrdersWithTracing(span),
      getProductsWithTracing(span),
    ]);
    
    span.setTag('users.count', users.length);
    span.setTag('orders.count', orders.length);
    span.setTag('products.count', products.length);
    span.log({ event: 'data_fetched_successfully' });
    
    res.json({ users, orders, products });
    
  } catch (error) {
    span.setTag(opentracing.Tags.ERROR, true);
    span.log({ event: 'error', message: error.message });
    res.status(500).json({ error: 'Failed' });
  } finally {
    span.finish();
  }
});

async function getUsersWithTracing(parentSpan) {
  const span = tracer.startSpan('get_users', { childOf: parentSpan });
  try {
    const users = await User.findAll();
    span.setTag('users.count', users.length);
    return users;
  } finally {
    span.finish();
  }
}

async function getOrdersWithTracing(parentSpan) {
  const span = tracer.startSpan('get_orders', { childOf: parentSpan });
  try {
    const orders = await Order.findAll();
    span.setTag('orders.count', orders.length);
    return orders;
  } finally {
    span.finish();
  }
}

async function getProductsWithTracing(parentSpan) {
  const span = tracer.startSpan('get_products', { childOf: parentSpan });
  try {
    const products = await Product.findAll();
    span.setTag('products.count', products.length);
    return products;
  } finally {
    span.finish();
  }
}
```

**Resultado no Jaeger:**
```
Trace: get_dashboard (350ms)
├─ get_users (300ms)      ┐
├─ get_orders (250ms)     ├─ Executam em paralelo
└─ get_products (200ms)   ┘
```

**Benefícios:**
- ✅ Vê claramente que operações são paralelas
- ✅ Identifica qual operação é mais lenta
- ✅ Pode otimizar a mais lenta primeiro
- ✅ Tempo total = tempo da operação mais lenta

---

## Exemplo 6: Retry Logic

### ❌ Sem Visibilidade de Retries

```javascript
async function callExternalAPI(url) {
  let attempts = 0;
  const maxAttempts = 3;
  
  while (attempts < maxAttempts) {
    try {
      const response = await axios.get(url);
      return response.data;
    } catch (error) {
      attempts++;
      if (attempts >= maxAttempts) throw error;
      await sleep(1000 * attempts);
    }
  }
}
```

**Problemas:**
- ❌ Não sabe quantos retries aconteceram
- ❌ Não sabe por que falhou
- ❌ Difícil debugar problemas intermitentes

### ✅ Com Instrumentação de Retries

```javascript
async function callExternalAPIWithTracing(url, parentSpan) {
  const span = tracer.startSpan('external_api_call', { childOf: parentSpan });
  
  try {
    span.setTag('http.url', url);
    span.setTag('retry.max_attempts', 3);
    
    let attempts = 0;
    const maxAttempts = 3;
    
    while (attempts < maxAttempts) {
      attempts++;
      
      const attemptSpan = tracer.startSpan(`attempt_${attempts}`, { childOf: span });
      attemptSpan.setTag('retry.attempt', attempts);
      
      try {
        attemptSpan.log({ event: 'attempt_start', attempt: attempts });
        
        const response = await axios.get(url, { timeout: 5000 });
        
        attemptSpan.setTag('http.status_code', response.status);
        attemptSpan.setTag('retry.success', true);
        attemptSpan.log({ event: 'attempt_success', attempt: attempts });
        attemptSpan.finish();
        
        span.setTag('retry.attempts_used', attempts);
        span.setTag('retry.success', true);
        span.log({ event: 'api_call_success', attempts_used: attempts });
        
        return response.data;
        
      } catch (error) {
        attemptSpan.setTag(opentracing.Tags.ERROR, true);
        attemptSpan.setTag('retry.success', false);
        attemptSpan.log({
          event: 'attempt_failed',
          attempt: attempts,
          error: error.message,
          will_retry: attempts < maxAttempts,
        });
        attemptSpan.finish();
        
        if (attempts >= maxAttempts) {
          span.setTag('retry.attempts_used', attempts);
          span.setTag('retry.success', false);
          span.setTag(opentracing.Tags.ERROR, true);
          span.log({ event: 'all_attempts_failed', total_attempts: attempts });
          throw error;
        }
        
        // Backoff exponencial
        const delay = 1000 * attempts;
        span.log({ event: 'retry_delay', delay_ms: delay, next_attempt: attempts + 1 });
        await sleep(delay);
      }
    }
  } finally {
    span.finish();
  }
}
```

**Resultado no Jaeger (com 2 falhas e 1 sucesso):**
```
Trace: external_api_call (3.5s) [retry.attempts_used=3, retry.success=true]
├─ attempt_1 (1s) [ERROR=true, retry.success=false]
│  Logs:
│  - event: attempt_start, attempt: 1
│  - event: attempt_failed, error: "timeout", will_retry: true
│
├─ attempt_2 (1s) [ERROR=true, retry.success=false]
│  Logs:
│  - event: attempt_start, attempt: 2
│  - event: attempt_failed, error: "timeout", will_retry: true
│
└─ attempt_3 (500ms) [retry.success=true]
   Logs:
   - event: attempt_start, attempt: 3
   - event: attempt_success, attempt: 3
```

**Benefícios:**
- ✅ Vê exatamente quantos retries aconteceram
- ✅ Vê por que cada tentativa falhou
- ✅ Vê tempo de backoff entre tentativas
- ✅ Identifica problemas intermitentes

---

## 🎯 Resumo de Benefícios

| Sem Instrumentação | Com Instrumentação |
|-------------------|-------------------|
| ❌ Sem visibilidade | ✅ Visibilidade completa |
| ❌ Logs dispersos | ✅ Contexto unificado |
| ❌ Debug difícil | ✅ Debug facilitado |
| ❌ Sem métricas | ✅ Métricas automáticas |
| ❌ Traces separados | ✅ Traces conectados |
| ❌ Sem hierarquia | ✅ Hierarquia clara |
| ❌ Difícil otimizar | ✅ Fácil identificar gargalos |

---

## 📚 Próximos Passos

1. Leia o [Guia Completo de Instrumentação](./instrumentation-guide.md)
2. Use a [Referência Rápida](./quick-reference-instrumentacao.md) durante desenvolvimento
3. Veja a [Correção de Propagação](./fix-trace-propagation.md) para troubleshooting
4. Pratique com os exemplos acima
5. Teste no Jaeger UI e veja os resultados!

**Boa instrumentação! 🚀**
