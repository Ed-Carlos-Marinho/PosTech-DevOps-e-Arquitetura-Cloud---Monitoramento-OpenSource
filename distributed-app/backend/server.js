// =============================================================================
// BACKEND SERVICE - EXPRESS SERVER
// =============================================================================
// Servidor Express com instrumentação Jaeger nativa
// =============================================================================

const express = require('express');
const cors = require('cors');
const winston = require('winston');
const opentracing = require('opentracing');
const { Pool } = require('pg');
const redis = require('redis');
const amqp = require('amqplib');
const { faker } = require('@faker-js/faker');

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
    new winston.transports.Console()
  ],
});

const app = express();
const PORT = process.env.PORT || 5000;

// Middleware
app.use(cors());
app.use(express.json());

// Database connection
const pool = new Pool({
  connectionString: process.env.DATABASE_URL || 'postgresql://postgres:postgres@postgres:5432/ecommerce',
});

// Redis client
const redisClient = redis.createClient({
  url: process.env.REDIS_URL || 'redis://redis:6379/0'
});

redisClient.connect().catch(console.error);

// RabbitMQ URL
const RABBITMQ_URL = process.env.RABBITMQ_URL || 'amqp://guest:guest@rabbitmq:5672/';

// =============================================================================
// MIDDLEWARE - Tracing
// =============================================================================

app.use((req, res, next) => {
  // Extrair contexto de trace dos headers
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
  
  req.span = span;
  req.traceId = span.context().toTraceId();
  
  logger.defaultMeta = { trace_id: req.traceId };
  
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
// UTILITY FUNCTIONS
// =============================================================================

function simulateProcessing(minMs = 50, maxMs = 200) {
  const delay = Math.random() * (maxMs - minMs) + minMs;
  return new Promise(resolve => setTimeout(resolve, delay));
}

async function cacheGet(key, parentSpan) {
  const span = tracer.startSpan('redis_get', { childOf: parentSpan });
  span.setTag('db.type', 'redis');
  span.setTag('db.operation', 'get');
  span.setTag('cache.key', key);
  
  try {
    const value = await redisClient.get(key);
    span.setTag('cache.hit', value !== null);
    span.log({ event: 'cache_lookup', hit: value !== null });
    return value;
  } catch (error) {
    span.setTag('error', true);
    span.log({ event: 'error', message: error.message });
    logger.error('Cache get error', { key, error: error.message });
    return null;
  } finally {
    span.finish();
  }
}

async function cacheSet(key, value, ttl = 300, parentSpan) {
  const span = tracer.startSpan('redis_set', { childOf: parentSpan });
  span.setTag('db.type', 'redis');
  span.setTag('db.operation', 'set');
  span.setTag('cache.key', key);
  span.setTag('cache.ttl', ttl);
  
  try {
    await redisClient.setEx(key, ttl, value);
    span.setTag('cache.success', true);
    span.log({ event: 'cache_stored', ttl });
  } catch (error) {
    span.setTag('error', true);
    span.log({ event: 'error', message: error.message });
    logger.error('Cache set error', { key, error: error.message });
  } finally {
    span.finish();
  }
}

async function publishMessage(queue, message, parentSpan) {
  const span = tracer.startSpan('rabbitmq_publish', { childOf: parentSpan });
  span.setTag('messaging.system', 'rabbitmq');
  span.setTag('messaging.destination', queue);
  span.setTag('messaging.operation', 'publish');
  
  try {
    span.log({ event: 'connecting_to_rabbitmq' });
    const connection = await amqp.connect(RABBITMQ_URL);
    const channel = await connection.createChannel();
    await channel.assertQueue(queue, { durable: true });
    
    span.log({ event: 'publishing_message', queue });
    channel.sendToQueue(queue, Buffer.from(message), { persistent: true });
    
    await channel.close();
    await connection.close();
    
    span.setTag('messaging.success', true);
    span.log({ event: 'message_published', queue });
    logger.info('Message published', { queue, message });
  } catch (error) {
    span.setTag('error', true);
    span.log({ event: 'error', message: error.message });
    logger.error('Message publish error', { queue, error: error.message });
  } finally {
    span.finish();
  }
}

// =============================================================================
// ROUTES
// =============================================================================

app.get('/health', (req, res) => {
  logger.info('Health check requested');
  req.span.setTag('health.status', 'healthy');
  
  res.json({
    status: 'healthy',
    service: 'backend-service',
    timestamp: new Date().toISOString(),
    trace_id: req.traceId
  });
});

app.get('/api/users', async (req, res) => {
  const span = tracer.startSpan('get_users', { childOf: req.span });
  
  try {
    logger.info('Fetching users');
    
    await simulateProcessing(100, 300);
    span.setTag('processing.time_ms', 200);
    
    // Tentar buscar no cache
    const cached = await cacheGet('users_list', span);
    if (cached) {
      logger.info('Users found in cache');
      span.setTag('cache.hit', true);
      return res.json(JSON.parse(cached));
    }
    
    // Buscar no banco
    span.setTag('cache.hit', false);
    const dbSpan = tracer.startSpan('postgres_query', { childOf: span });
    dbSpan.setTag('db.type', 'postgresql');
    dbSpan.setTag('db.operation', 'select');
    dbSpan.setTag('db.table', 'users');
    dbSpan.log({ event: 'executing_query', query: 'SELECT * FROM users' });
    
    const result = await pool.query('SELECT * FROM users ORDER BY id');
    const users = result.rows;
    
    dbSpan.setTag('db.rows_returned', users.length);
    dbSpan.log({ event: 'query_completed', rows: users.length });
    dbSpan.finish();
    
    // Armazenar no cache
    await cacheSet('users_list', JSON.stringify(users), 60, span);
    
    span.setTag('users.count', users.length);
    logger.info('Users fetched from database', { count: users.length });
    
    res.json(users);
  } catch (error) {
    span.setTag('error', true);
    span.log({ event: 'error', message: error.message });
    logger.error('Error fetching users', { error: error.message });
    res.status(500).json({ error: 'Failed to fetch users' });
  } finally {
    span.finish();
  }
});

app.get('/api/products', async (req, res) => {
  const span = tracer.startSpan('get_products', { childOf: req.span });
  
  try {
    logger.info('Fetching products');
    
    await simulateProcessing(80, 250);
    
    const cached = await cacheGet('products_list', span);
    if (cached) {
      logger.info('Products found in cache');
      span.setTag('cache.hit', true);
      return res.json(JSON.parse(cached));
    }
    
    span.setTag('cache.hit', false);
    const dbSpan = tracer.startSpan('postgres_query', { childOf: span });
    dbSpan.setTag('db.type', 'postgresql');
    dbSpan.setTag('db.operation', 'select');
    dbSpan.setTag('db.table', 'products');
    
    const result = await pool.query('SELECT * FROM products ORDER BY id');
    const products = result.rows;
    
    dbSpan.setTag('db.rows_returned', products.length);
    dbSpan.finish();
    
    await cacheSet('products_list', JSON.stringify(products), 120, span);
    
    span.setTag('products.count', products.length);
    logger.info('Products fetched from database', { count: products.length });
    
    res.json(products);
  } catch (error) {
    span.setTag('error', true);
    span.log({ event: 'error', message: error.message });
    logger.error('Error fetching products', { error: error.message });
    res.status(500).json({ error: 'Failed to fetch products' });
  } finally {
    span.finish();
  }
});

app.get('/api/orders', async (req, res) => {
  const span = tracer.startSpan('get_orders', { childOf: req.span });
  
  try {
    logger.info('Fetching orders');
    
    await simulateProcessing(150, 400);
    
    const dbSpan = tracer.startSpan('postgres_query', { childOf: span });
    dbSpan.setTag('db.type', 'postgresql');
    dbSpan.setTag('db.operation', 'select');
    dbSpan.setTag('db.table', 'orders');
    
    const result = await pool.query(`
      SELECT o.*, u.name as user_name 
      FROM orders o 
      JOIN users u ON o.user_id = u.id 
      ORDER BY o.id
    `);
    const orders = result.rows;
    
    dbSpan.setTag('db.rows_returned', orders.length);
    dbSpan.finish();
    
    span.setTag('orders.count', orders.length);
    logger.info('Orders fetched from database', { count: orders.length });
    
    res.json(orders);
  } catch (error) {
    span.setTag('error', true);
    span.log({ event: 'error', message: error.message });
    logger.error('Error fetching orders', { error: error.message });
    res.status(500).json({ error: 'Failed to fetch orders' });
  } finally {
    span.finish();
  }
});

app.post('/api/orders', async (req, res) => {
  const span = tracer.startSpan('create_order', { childOf: req.span });
  
  try {
    const { user_id, total_amount } = req.body;
    
    logger.info('Creating new order', { user_id, total_amount });
    
    if (!user_id || !total_amount) {
      span.setTag('validation.success', false);
      return res.status(400).json({ error: 'Invalid order data' });
    }
    
    span.setTag('validation.success', true);
    span.setTag('order.user_id', user_id);
    span.setTag('order.total_amount', total_amount);
    
    await simulateProcessing(300, 800);
    
    const dbSpan = tracer.startSpan('postgres_insert', { childOf: span });
    dbSpan.setTag('db.type', 'postgresql');
    dbSpan.setTag('db.operation', 'insert');
    dbSpan.setTag('db.table', 'orders');
    
    const result = await pool.query(
      'INSERT INTO orders (user_id, total_amount, status) VALUES ($1, $2, $3) RETURNING *',
      [user_id, total_amount, 'pending']
    );
    const order = result.rows[0];
    
    dbSpan.setTag('db.order_id', order.id);
    dbSpan.finish();
    
    // Publicar mensagem
    await publishMessage('order_processing', `Order ${order.id} created`, span);
    
    // Invalidar cache
    const cacheSpan = tracer.startSpan('redis_delete', { childOf: span });
    cacheSpan.setTag('db.type', 'redis');
    cacheSpan.setTag('cache.key', 'orders_list');
    await redisClient.del('orders_list');
    cacheSpan.finish();
    
    span.setTag('order.id', order.id);
    span.setTag('order.success', true);
    
    logger.info('Order created successfully', { order_id: order.id });
    
    res.status(201).json(order);
  } catch (error) {
    span.setTag('error', true);
    span.log({ event: 'error', message: error.message });
    logger.error('Error creating order', { error: error.message });
    res.status(500).json({ error: 'Failed to create order' });
  } finally {
    span.finish();
  }
});

// =============================================================================
// DATABASE INITIALIZATION
// =============================================================================

async function initDatabase() {
  try {
    // Criar tabelas
    await pool.query(`
      CREATE TABLE IF NOT EXISTS users (
        id SERIAL PRIMARY KEY,
        name VARCHAR(100) NOT NULL,
        email VARCHAR(120) UNIQUE NOT NULL,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
      )
    `);
    
    await pool.query(`
      CREATE TABLE IF NOT EXISTS products (
        id SERIAL PRIMARY KEY,
        name VARCHAR(100) NOT NULL,
        price DECIMAL(10, 2) NOT NULL,
        category VARCHAR(50) NOT NULL,
        stock INTEGER DEFAULT 0,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
      )
    `);
    
    await pool.query(`
      CREATE TABLE IF NOT EXISTS orders (
        id SERIAL PRIMARY KEY,
        user_id INTEGER REFERENCES users(id),
        total_amount DECIMAL(10, 2) NOT NULL,
        status VARCHAR(20) DEFAULT 'pending',
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
      )
    `);
    
    // Verificar se já existem dados
    const userCount = await pool.query('SELECT COUNT(*) FROM users');
    
    if (parseInt(userCount.rows[0].count) === 0) {
      logger.info('Initializing database with sample data');
      
      // Inserir usuários
      for (let i = 0; i < 10; i++) {
        await pool.query(
          'INSERT INTO users (name, email) VALUES ($1, $2)',
          [faker.person.fullName(), faker.internet.email()]
        );
      }
      
      // Inserir produtos
      const categories = ['Electronics', 'Clothing', 'Books', 'Home', 'Sports'];
      for (let i = 0; i < 20; i++) {
        await pool.query(
          'INSERT INTO products (name, price, category, stock) VALUES ($1, $2, $3, $4)',
          [
            faker.commerce.productName(),
            parseFloat(faker.commerce.price({ min: 10, max: 500 })),
            categories[Math.floor(Math.random() * categories.length)],
            Math.floor(Math.random() * 100)
          ]
        );
      }
      
      // Inserir pedidos
      const statuses = ['pending', 'processing', 'completed'];
      for (let i = 0; i < 5; i++) {
        await pool.query(
          'INSERT INTO orders (user_id, total_amount, status) VALUES ($1, $2, $3)',
          [
            Math.floor(Math.random() * 10) + 1,
            parseFloat(faker.commerce.price({ min: 50, max: 1000 })),
            statuses[Math.floor(Math.random() * statuses.length)]
          ]
        );
      }
      
      logger.info('Database initialized with sample data');
    }
  } catch (error) {
    logger.error('Database initialization error', { error: error.message });
  }
}

// =============================================================================
// SERVER STARTUP
// =============================================================================

app.listen(PORT, async () => {
  logger.info('Backend service started', { port: PORT });
  console.log(`🚀 Backend service running on port ${PORT}`);
  console.log(`🗄️  Database: ${process.env.DATABASE_URL || 'postgresql://postgres:postgres@postgres:5432/ecommerce'}`);
  console.log(`🔴 Redis: ${process.env.REDIS_URL || 'redis://redis:6379/0'}`);
  console.log(`🐰 RabbitMQ: ${RABBITMQ_URL}`);
  console.log(`🔍 Jaeger tracing enabled`);
  
  await initDatabase();
});
