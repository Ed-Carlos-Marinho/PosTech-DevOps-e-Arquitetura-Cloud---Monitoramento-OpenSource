# =============================================================================
# BACKEND SERVICE - FLASK APPLICATION
# =============================================================================
# Aplicação Flask com instrumentação Jaeger nativa
# Aula 05 - PosTech DevOps e Arquitetura Cloud - Monitoramento OpenSource
# =============================================================================

import os
import time
import random
import structlog
from datetime import datetime
from flask import Flask, request, jsonify
from flask_cors import CORS
from flask_sqlalchemy import SQLAlchemy
import redis
import pika
import opentracing
from faker import Faker

# Importar configuração de tracing
from tracing import (
    initialize_tracing, 
    get_current_trace_id, 
    get_current_span_id,
    extract_span_context,
    inject_span_context,
    create_child_span
)

# Inicializar tracing antes de criar a aplicação
tracer = initialize_tracing()

# Configuração do logger estruturado
structlog.configure(
    processors=[
        structlog.stdlib.filter_by_level,
        structlog.stdlib.add_logger_name,
        structlog.stdlib.add_log_level,
        structlog.stdlib.PositionalArgumentsFormatter(),
        structlog.processors.TimeStamper(fmt="iso"),
        structlog.processors.StackInfoRenderer(),
        structlog.processors.format_exc_info,
        structlog.processors.UnicodeDecoder(),
        structlog.processors.JSONRenderer()
    ],
    context_class=dict,
    logger_factory=structlog.stdlib.LoggerFactory(),
    wrapper_class=structlog.stdlib.BoundLogger,
    cache_logger_on_first_use=True,
)

logger = structlog.get_logger()

# =============================================================================
# FLASK APPLICATION SETUP
# =============================================================================

app = Flask(__name__)
CORS(app)

# Configuração do banco de dados
app.config['SQLALCHEMY_DATABASE_URI'] = os.getenv(
    'DATABASE_URL', 
    'postgresql://postgres:postgres@localhost:5432/ecommerce'
)
app.config['SQLALCHEMY_TRACK_MODIFICATIONS'] = False

# Inicializar extensões
db = SQLAlchemy(app)

# Configuração do Redis
redis_client = redis.Redis.from_url(
    os.getenv('REDIS_URL', 'redis://localhost:6379/0'),
    decode_responses=True
)

# Configuração do RabbitMQ
rabbitmq_url = os.getenv('RABBITMQ_URL', 'amqp://guest:guest@localhost:5672/')

# Faker para dados de teste
fake = Faker()

# =============================================================================
# DATABASE MODELS
# =============================================================================

class User(db.Model):
    __tablename__ = 'users'
    
    id = db.Column(db.Integer, primary_key=True)
    name = db.Column(db.String(100), nullable=False)
    email = db.Column(db.String(120), unique=True, nullable=False)
    created_at = db.Column(db.DateTime, default=datetime.utcnow)
    
    def to_dict(self):
        return {
            'id': self.id,
            'name': self.name,
            'email': self.email,
            'created_at': self.created_at.isoformat()
        }

class Product(db.Model):
    __tablename__ = 'products'
    
    id = db.Column(db.Integer, primary_key=True)
    name = db.Column(db.String(100), nullable=False)
    price = db.Column(db.Float, nullable=False)
    category = db.Column(db.String(50), nullable=False)
    stock = db.Column(db.Integer, default=0)
    created_at = db.Column(db.DateTime, default=datetime.utcnow)
    
    def to_dict(self):
        return {
            'id': self.id,
            'name': self.name,
            'price': self.price,
            'category': self.category,
            'stock': self.stock,
            'created_at': self.created_at.isoformat()
        }

class Order(db.Model):
    __tablename__ = 'orders'
    
    id = db.Column(db.Integer, primary_key=True)
    user_id = db.Column(db.Integer, db.ForeignKey('users.id'), nullable=False)
    total_amount = db.Column(db.Float, nullable=False)
    status = db.Column(db.String(20), default='pending')
    created_at = db.Column(db.DateTime, default=datetime.utcnow)
    
    user = db.relationship('User', backref=db.backref('orders', lazy=True))
    
    def to_dict(self):
        return {
            'id': self.id,
            'user_id': self.user_id,
            'user_name': self.user.name if self.user else None,
            'total_amount': self.total_amount,
            'status': self.status,
            'created_at': self.created_at.isoformat()
        }

# =============================================================================
# MIDDLEWARE
# =============================================================================

@app.before_request
def before_request():
    """Middleware para adicionar informações de tracing aos logs"""
    trace_id = get_current_trace_id()
    span_id = get_current_span_id()
    
    # Adicionar trace_id e span_id ao contexto do logger
    if trace_id:
        structlog.contextvars.bind_contextvars(
            trace_id=trace_id,
            span_id=span_id
        )

# =============================================================================
# UTILITY FUNCTIONS
# =============================================================================

def simulate_processing_time(min_ms=50, max_ms=200):
    """Simula tempo de processamento para demonstrar latência"""
    delay = random.uniform(min_ms, max_ms) / 1000
    time.sleep(delay)
    return delay

def cache_get(key):
    """Busca dados no cache Redis com instrumentação"""
    span = tracer.start_span("cache_get")
    span.set_tag("cache.key", key)
    try:
        value = redis_client.get(key)
        span.set_tag("cache.hit", value is not None)
        return value
    except Exception as e:
        span.set_tag(opentracing.Tags.ERROR, True)
        span.log_kv({"event": "error", "message": str(e)})
        logger.error("Cache get error", key=key, error=str(e))
        return None
    finally:
        span.finish()

def cache_set(key, value, ttl=300):
    """Armazena dados no cache Redis com instrumentação"""
    span = tracer.start_span("cache_set")
    span.set_tag("cache.key", key)
    span.set_tag("cache.ttl", ttl)
    try:
        redis_client.setex(key, ttl, value)
        span.set_tag("cache.success", True)
    except Exception as e:
        span.set_tag(opentracing.Tags.ERROR, True)
        span.log_kv({"event": "error", "message": str(e)})
        span.set_tag("cache.success", False)
        logger.error("Cache set error", key=key, error=str(e))
    finally:
        span.finish()

def publish_message(queue, message):
    """Publica mensagem no RabbitMQ com instrumentação"""
    span = tracer.start_span("publish_message")
    span.set_tag("messaging.system", "rabbitmq")
    span.set_tag("messaging.destination", queue)
    try:
        connection = pika.BlockingConnection(pika.URLParameters(rabbitmq_url))
        channel = connection.channel()
        channel.queue_declare(queue=queue, durable=True)
        channel.basic_publish(
            exchange='',
            routing_key=queue,
            body=message,
            properties=pika.BasicProperties(delivery_mode=2)
        )
        connection.close()
        span.set_tag("messaging.success", True)
        logger.info("Message published", queue=queue, message=message)
    except Exception as e:
        span.set_tag(opentracing.Tags.ERROR, True)
        span.log_kv({"event": "error", "message": str(e)})
        span.set_tag("messaging.success", False)
        logger.error("Message publish error", queue=queue, error=str(e))
    finally:
        span.finish()

# =============================================================================
# API ENDPOINTS
# =============================================================================

@app.route('/health', methods=['GET'])
def health_check():
    """Health check endpoint"""
    logger.info("Health check requested")
    return jsonify({
        'status': 'healthy',
        'service': 'backend-service',
        'timestamp': datetime.utcnow().isoformat(),
        'trace_id': get_current_trace_id()
    })

@app.route('/api/users', methods=['GET'])
def get_users():
    """Busca lista de usuários com cache"""
    span = tracer.start_span("get_users")
    try:
        logger.info("Fetching users")
        
        # Simular tempo de processamento
        processing_time = simulate_processing_time(100, 300)
        span.set_tag("processing.time_ms", processing_time * 1000)
        
        # Tentar buscar no cache primeiro
        cached_users = cache_get("users_list")
        if cached_users:
            logger.info("Users found in cache")
            span.set_tag("cache.hit", True)
            return jsonify(eval(cached_users))
        
        # Buscar no banco de dados
        span.set_tag("cache.hit", False)
        users = User.query.all()
        users_data = [user.to_dict() for user in users]
        
        # Armazenar no cache
        cache_set("users_list", str(users_data), 60)
        
        span.set_tag("users.count", len(users_data))
        logger.info("Users fetched from database", count=len(users_data))
        
        return jsonify(users_data)
    except Exception as e:
        span.set_tag(opentracing.Tags.ERROR, True)
        span.log_kv({"event": "error", "message": str(e)})
        logger.error("Error fetching users", error=str(e))
        return jsonify({'error': 'Failed to fetch users'}), 500
    finally:
        span.finish()

@app.route('/api/products', methods=['GET'])
def get_products():
    """Busca lista de produtos com cache"""
    span = tracer.start_span("get_products")
    try:
        logger.info("Fetching products")
        
        # Simular tempo de processamento
        processing_time = simulate_processing_time(80, 250)
        span.set_tag("processing.time_ms", processing_time * 1000)
        
        # Tentar buscar no cache primeiro
        cached_products = cache_get("products_list")
        if cached_products:
            logger.info("Products found in cache")
            span.set_tag("cache.hit", True)
            return jsonify(eval(cached_products))
        
        # Buscar no banco de dados
        span.set_tag("cache.hit", False)
        products = Product.query.all()
        products_data = [product.to_dict() for product in products]
        
        # Armazenar no cache
        cache_set("products_list", str(products_data), 120)
        
        span.set_tag("products.count", len(products_data))
        logger.info("Products fetched from database", count=len(products_data))
        
        return jsonify(products_data)
    except Exception as e:
        span.set_tag(opentracing.Tags.ERROR, True)
        span.log_kv({"event": "error", "message": str(e)})
        logger.error("Error fetching products", error=str(e))
        return jsonify({'error': 'Failed to fetch products'}), 500
    finally:
        span.finish()

@app.route('/api/orders', methods=['GET'])
def get_orders():
    """Busca lista de pedidos"""
    span = tracer.start_span("get_orders")
    try:
        logger.info("Fetching orders")
        
        # Simular tempo de processamento
        processing_time = simulate_processing_time(150, 400)
        span.set_tag("processing.time_ms", processing_time * 1000)
        
        orders = Order.query.all()
        orders_data = [order.to_dict() for order in orders]
        
        span.set_tag("orders.count", len(orders_data))
        logger.info("Orders fetched from database", count=len(orders_data))
        
        return jsonify(orders_data)
    except Exception as e:
        span.set_tag(opentracing.Tags.ERROR, True)
        span.log_kv({"event": "error", "message": str(e)})
        logger.error("Error fetching orders", error=str(e))
        return jsonify({'error': 'Failed to fetch orders'}), 500
    finally:
        span.finish()

@app.route('/api/orders', methods=['POST'])
def create_order():
    """Cria um novo pedido"""
    span = tracer.start_span("create_order")
    try:
        data = request.get_json()
        
        logger.info("Creating new order", order_data=data)
        
        # Validar dados
        if not data or 'user_id' not in data or 'total_amount' not in data:
            span.set_tag("validation.success", False)
            logger.error("Invalid order data", data=data)
            return jsonify({'error': 'Invalid order data'}), 400
        
        span.set_tag("validation.success", True)
        span.set_tag("order.user_id", data['user_id'])
        span.set_tag("order.total_amount", data['total_amount'])
        
        # Simular tempo de processamento mais longo para criação
        processing_time = simulate_processing_time(300, 800)
        span.set_tag("processing.time_ms", processing_time * 1000)
        
        try:
            # Criar pedido
            order = Order(
                user_id=data['user_id'],
                total_amount=data['total_amount'],
                status='pending'
            )
            
            db.session.add(order)
            db.session.commit()
            
            # Publicar mensagem para processamento assíncrono
            publish_message('order_processing', f'Order {order.id} created')
            
            # Invalidar cache de pedidos
            redis_client.delete("orders_list")
            
            span.set_tag("order.id", order.id)
            span.set_tag("order.success", True)
            
            logger.info("Order created successfully", order_id=order.id)
            
            return jsonify(order.to_dict()), 201
            
        except Exception as e:
            db.session.rollback()
            span.set_tag(opentracing.Tags.ERROR, True)
            span.log_kv({"event": "error", "message": str(e)})
            span.set_tag("order.success", False)
            logger.error("Error creating order", error=str(e), data=data)
            return jsonify({'error': 'Failed to create order'}), 500
    finally:
        span.finish()

# =============================================================================
# ERROR HANDLERS
# =============================================================================

@app.errorhandler(404)
def not_found(error):
    logger.warning("Route not found", path=request.path, method=request.method)
    return jsonify({'error': 'Route not found'}), 404

@app.errorhandler(500)
def internal_error(error):
    logger.error("Internal server error", error=str(error))
    return jsonify({'error': 'Internal server error'}), 500

# =============================================================================
# DATABASE INITIALIZATION
# =============================================================================

def init_database():
    """Inicializa o banco de dados com dados de exemplo"""
    with app.app_context():
        db.create_all()
        
        # Verificar se já existem dados
        if User.query.count() == 0:
            logger.info("Initializing database with sample data")
            
            # Criar usuários de exemplo
            users = []
            for _ in range(10):
                user = User(
                    name=fake.name(),
                    email=fake.email()
                )
                users.append(user)
                db.session.add(user)
            
            # Criar produtos de exemplo
            categories = ['Electronics', 'Clothing', 'Books', 'Home', 'Sports']
            products = []
            for _ in range(20):
                product = Product(
                    name=fake.catch_phrase(),
                    price=round(random.uniform(10, 500), 2),
                    category=random.choice(categories),
                    stock=random.randint(0, 100)
                )
                products.append(product)
                db.session.add(product)
            
            db.session.commit()
            
            # Criar alguns pedidos de exemplo
            for _ in range(5):
                order = Order(
                    user_id=random.choice(users).id,
                    total_amount=round(random.uniform(50, 1000), 2),
                    status=random.choice(['pending', 'processing', 'completed'])
                )
                db.session.add(order)
            
            db.session.commit()
            logger.info("Database initialized with sample data")

# =============================================================================
# APPLICATION STARTUP
# =============================================================================

if __name__ == '__main__':
    # Inicializar banco de dados
    init_database()
    
    # Configurar logging
    import logging
    logging.basicConfig(
        level=logging.INFO,
        format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
        handlers=[
            logging.StreamHandler(),
            logging.FileHandler('/app/logs/backend.log')
        ]
    )
    
    logger.info("Backend service starting", 
                port=5000, 
                database_url=app.config['SQLALCHEMY_DATABASE_URI'])
    
    print("🚀 Backend service starting on port 5000")
    print(f"🗄️  Database: {app.config['SQLALCHEMY_DATABASE_URI']}")
    print(f"🔴 Redis: {os.getenv('REDIS_URL', 'redis://localhost:6379/0')}")
    print(f"🐰 RabbitMQ: {rabbitmq_url}")
    
    app.run(host='0.0.0.0', port=5000, debug=False)