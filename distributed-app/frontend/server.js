// =============================================================================
// FRONTEND SERVICE - EXPRESS SERVER
// =============================================================================
// Servidor Express com instrumentação Jaeger nativa
// Aula 05 - PosTech DevOps e Arquitetura Cloud - Monitoramento OpenSource
// =============================================================================

const express = require('express');
const axios = require('axios');
const cors = require('cors');
const winston = require('winston');
const opentracing = require('opentracing');

// Importar configuração de tracing
const tracer = require('./tracing');

// Configuração do logger
const logger = winston.createLogger({
  level: 'info',
  format: winston.format.combine(
    winston.format.timestamp(),
    winston.format.errors({ stack: true }),
    winston.format.json()
  ),
  transports: [
    new winston.transports.Console(),
    new winston.transports.File({ filename: '/app/logs/frontend.log' })
  ],
});

const app = express();
const PORT = process.env.PORT || 3000;
const BACKEND_URL = process.env.BACKEND_URL || 'http://localhost:5000';

// Middleware
app.use(cors());
app.use(express.json());
app.use(express.static('public'));

// Middleware para instrumentação Jaeger
app.use((req, res, next) => {
  // Extrair contexto de trace dos headers (se existir)
  const parentSpanContext = tracer.extract(opentracing.FORMAT_HTTP_HEADERS, req.headers);
  
  // Criar span para a requisição
  const span = tracer.startSpan(`${req.method} ${req.path}`, {
    childOf: parentSpanContext,
    tags: {
      [opentracing.Tags.HTTP_METHOD]: req.method,
      [opentracing.Tags.HTTP_URL]: req.originalUrl,
      [opentracing.Tags.SPAN_KIND]: opentracing.Tags.SPAN_KIND_RPC_SERVER,
      [opentracing.Tags.COMPONENT]: 'express',
    },
  });
  
  // Adicionar span ao request para uso posterior
  req.span = span;
  req.traceId = span.context().toTraceId();
  
  // Adicionar trace_id aos logs
  logger.defaultMeta = { trace_id: req.traceId };
  
  // Finalizar span quando resposta for enviada
  res.on('finish', () => {
    span.setTag(opentracing.Tags.HTTP_STATUS_CODE, res.statusCode);
    
    if (res.statusCode >= 400) {
      span.setTag(opentracing.Tags.ERROR, true);
      span.log({
        event: 'error',
        message: `HTTP ${res.statusCode}`,
      });
    }
    
    span.finish();
  });
  
  next();
});

// =============================================================================
// ROUTES - API ENDPOINTS
// =============================================================================

// Health check endpoint
app.get('/health', (req, res) => {
  logger.info('Health check requested', { endpoint: '/health' });
  
  req.span.setTag('health.status', 'healthy');
  req.span.log({ event: 'health_check', status: 'healthy' });
  
  res.json({ 
    status: 'healthy', 
    service: 'frontend-service',
    timestamp: new Date().toISOString(),
    trace_id: req.traceId
  });
});

// Home page
app.get('/', (req, res) => {
  logger.info('Home page requested', { endpoint: '/' });
  
  req.span.setTag('page.name', 'home');
  req.span.log({ event: 'page_view', page: 'home' });
  
  res.json({
    message: 'E-commerce Frontend Service',
    version: '1.0.0',
    endpoints: [
      'GET /api/users - List users',
      'GET /api/products - List products', 
      'GET /api/orders - List orders',
      'POST /api/orders - Create order',
      'GET /health - Health check'
    ],
    trace_id: req.traceId
  });
});

// =============================================================================
// API PROXY ENDPOINTS - Comunicação com backend
// =============================================================================

// Get users from backend
app.get('/api/users', async (req, res) => {
  // Criar o span ANTES de qualquer processamento
  const span = tracer.startSpan('get_users', { childOf: req.span });
  
  try {
    logger.info('Fetching users from backend', { endpoint: '/api/users' });
    
    // Configurar tags do span
    span.setTag('operation.name', 'get_users');
    span.setTag('backend.service', 'backend-service');
    span.setTag('backend.url', `${BACKEND_URL}/api/users`);
    
    // Simular processamento no frontend (200ms)
    await new Promise(resolve => setTimeout(resolve, 200));
    
    // Preparar headers com contexto de trace
    const headers = {};
    tracer.inject(span, opentracing.FORMAT_HTTP_HEADERS, headers);
    headers['X-Trace-Id'] = req.traceId;
    
    span.log({ event: 'backend_call_start', url: `${BACKEND_URL}/api/users` });
    
    const response = await axios.get(`${BACKEND_URL}/api/users`, {
      timeout: 5000,
      headers: headers
    });
    
    span.setTag('http.status_code', response.status);
    span.setTag('users.count', response.data.length);
    span.log({ 
      event: 'backend_call_success', 
      status: response.status,
      count: response.data.length 
    });
    
    logger.info('Users fetched successfully', { 
      count: response.data.length,
      status: response.status 
    });
    
    res.json(response.data);
    
  } catch (error) {
    logger.error('Error fetching users', { 
      error: error.message,
      stack: error.stack 
    });
    
    span.setTag(opentracing.Tags.ERROR, true);
    span.log({
      event: 'error',
      'error.object': error,
      'error.kind': error.name,
      message: error.message,
      stack: error.stack,
    });
    
    res.status(500).json({ 
      error: 'Failed to fetch users',
      trace_id: req.traceId
    });
  } finally {
    span.finish();
  }
});

// Get products from backend
app.get('/api/products', async (req, res) => {
  // Criar o span ANTES de qualquer processamento
  const span = tracer.startSpan('get_products', { childOf: req.span });
  
  try {
    logger.info('Fetching products from backend', { endpoint: '/api/products' });
    
    span.setTag('operation.name', 'get_products');
    span.setTag('backend.service', 'backend-service');
    span.setTag('backend.url', `${BACKEND_URL}/api/products`);
    
    // Simular processamento no frontend (150ms)
    await new Promise(resolve => setTimeout(resolve, 150));
    
    // Preparar headers com contexto de trace
    const headers = {};
    tracer.inject(span, opentracing.FORMAT_HTTP_HEADERS, headers);
    headers['X-Trace-Id'] = req.traceId;
    
    span.log({ event: 'backend_call_start', url: `${BACKEND_URL}/api/products` });
    
    const response = await axios.get(`${BACKEND_URL}/api/products`, {
      timeout: 5000,
      headers: headers
    });
    
    span.setTag('http.status_code', response.status);
    span.setTag('products.count', response.data.length);
    span.log({ 
      event: 'backend_call_success', 
      status: response.status,
      count: response.data.length 
    });
    
    logger.info('Products fetched successfully', { 
      count: response.data.length,
      status: response.status 
    });
    
    res.json(response.data);
    
  } catch (error) {
    logger.error('Error fetching products', { 
      error: error.message,
      stack: error.stack 
    });
    
    span.setTag(opentracing.Tags.ERROR, true);
    span.log({
      event: 'error',
      'error.object': error,
      'error.kind': error.name,
      message: error.message,
      stack: error.stack,
    });
    
    res.status(500).json({ 
      error: 'Failed to fetch products',
      trace_id: req.traceId
    });
  } finally {
    span.finish();
  }
});

// Get orders from backend
app.get('/api/orders', async (req, res) => {
  // Criar o span ANTES de qualquer processamento
  const span = tracer.startSpan('get_orders', { childOf: req.span });
  
  try {
    logger.info('Fetching orders from backend', { endpoint: '/api/orders' });
    
    span.setTag('operation.name', 'get_orders');
    span.setTag('backend.service', 'backend-service');
    span.setTag('backend.url', `${BACKEND_URL}/api/orders`);
    
    // Simular processamento no frontend (250ms)
    await new Promise(resolve => setTimeout(resolve, 250));
    
    // Preparar headers com contexto de trace
    const headers = {};
    tracer.inject(span, opentracing.FORMAT_HTTP_HEADERS, headers);
    headers['X-Trace-Id'] = req.traceId;
    
    span.log({ event: 'backend_call_start', url: `${BACKEND_URL}/api/orders` });
    
    const response = await axios.get(`${BACKEND_URL}/api/orders`, {
      timeout: 5000,
      headers: headers
    });
    
    span.setTag('http.status_code', response.status);
    span.setTag('orders.count', response.data.length);
    span.log({ 
      event: 'backend_call_success', 
      status: response.status,
      count: response.data.length 
    });
    
    logger.info('Orders fetched successfully', { 
      count: response.data.length,
      status: response.status 
    });
    
    res.json(response.data);
    
  } catch (error) {
    logger.error('Error fetching orders', { 
      error: error.message,
      stack: error.stack 
    });
    
    span.setTag(opentracing.Tags.ERROR, true);
    span.log({
      event: 'error',
      'error.object': error,
      'error.kind': error.name,
      message: error.message,
      stack: error.stack,
    });
    
    res.status(500).json({ 
      error: 'Failed to fetch orders',
      trace_id: req.traceId
    });
  } finally {
    span.finish();
  }
});

// Create order
app.post('/api/orders', async (req, res) => {
  // Criar o span ANTES de qualquer processamento
  const span = tracer.startSpan('create_order', { childOf: req.span });
  
  try {
    logger.info('Creating new order', { 
      endpoint: '/api/orders',
      orderData: req.body 
    });
    
    span.setTag('operation.name', 'create_order');
    span.setTag('backend.service', 'backend-service');
    span.setTag('backend.url', `${BACKEND_URL}/api/orders`);
    span.setTag('order.user_id', req.body.user_id);
    span.setTag('order.product_count', req.body.products?.length || 0);
    
    // Simular validação no frontend (300ms)
    await new Promise(resolve => setTimeout(resolve, 300));
    
    // Preparar headers com contexto de trace
    const headers = {};
    tracer.inject(span, opentracing.FORMAT_HTTP_HEADERS, headers);
    headers['Content-Type'] = 'application/json';
    headers['X-Trace-Id'] = req.traceId;
    
    span.log({ 
      event: 'backend_call_start', 
      url: `${BACKEND_URL}/api/orders`,
      order_data: req.body 
    });
    
    const response = await axios.post(`${BACKEND_URL}/api/orders`, req.body, {
      timeout: 10000,
      headers: headers
    });
    
    span.setTag('http.status_code', response.status);
    span.setTag('order.id', response.data.id);
    span.log({ 
      event: 'backend_call_success', 
      status: response.status,
      order_id: response.data.id 
    });
    
    logger.info('Order created successfully', { 
      orderId: response.data.id,
      status: response.status 
    });
    
    res.status(201).json(response.data);
    
  } catch (error) {
    logger.error('Error creating order', { 
      error: error.message,
      stack: error.stack,
      orderData: req.body
    });
    
    span.setTag(opentracing.Tags.ERROR, true);
    span.log({
      event: 'error',
      'error.object': error,
      'error.kind': error.name,
      message: error.message,
      stack: error.stack,
      order_data: req.body,
    });
    
    res.status(500).json({ 
      error: 'Failed to create order',
      trace_id: req.traceId
    });
  } finally {
    span.finish();
  }
});

// =============================================================================
// ERROR HANDLING
// =============================================================================

// 404 handler
app.use('*', (req, res) => {
  logger.warn('Route not found', { 
    method: req.method,
    url: req.originalUrl 
  });
  
  req.span.setTag('http.route_found', false);
  req.span.log({ event: 'route_not_found', url: req.originalUrl });
  
  res.status(404).json({ 
    error: 'Route not found',
    trace_id: req.traceId
  });
});

// Global error handler
app.use((error, req, res, next) => {
  logger.error('Unhandled error', { 
    error: error.message,
    stack: error.stack 
  });
  
  if (req.span) {
    req.span.setTag(opentracing.Tags.ERROR, true);
    req.span.log({
      event: 'error',
      'error.object': error,
      'error.kind': error.name,
      message: error.message,
      stack: error.stack,
    });
  }
  
  res.status(500).json({ 
    error: 'Internal server error',
    trace_id: req.traceId
  });
});

// =============================================================================
// SERVER STARTUP
// =============================================================================

app.listen(PORT, () => {
  logger.info('Frontend service started', { 
    port: PORT,
    backendUrl: BACKEND_URL,
    nodeEnv: process.env.NODE_ENV 
  });
  console.log(`🚀 Frontend service running on port ${PORT}`);
  console.log(`🔗 Backend URL: ${BACKEND_URL}`);
  console.log(`🔍 Jaeger tracing enabled`);
});