# =============================================================================
# JAEGER TRACING CONFIGURATION - BACKEND SERVICE
# =============================================================================
# Configuração de instrumentação com Jaeger Client Library nativo
# Aula 05 - PosTech DevOps e Arquitetura Cloud - Monitoramento OpenSource
# =============================================================================

import os
import opentracing
from jaeger_client import Config
from flask import request

def initialize_tracing():
    """
    Inicializa a configuração de tracing Jaeger para o backend service
    """
    
    # Obter configurações do ambiente
    jaeger_host = os.getenv('JAEGER_AGENT_HOST', 'localhost')
    jaeger_port = int(os.getenv('JAEGER_AGENT_PORT', '6832'))
    sampler_type = os.getenv('JAEGER_SAMPLER_TYPE', 'const')
    sampler_param = float(os.getenv('JAEGER_SAMPLER_PARAM', '1'))
    service_name = os.getenv('JAEGER_SERVICE_NAME', 'backend-service')
    
    # Configuração do Jaeger Client
    config = Config(
        config={
            'sampler': {
                'type': sampler_type,
                'param': sampler_param,
            },
            'local_agent': {
                'reporting_host': jaeger_host,
                'reporting_port': jaeger_port,
            },
            'logging': True,
            'reporter_batch_size': 10,
            'reporter_queue_size': 100,
            'reporter_flush_interval': 1,
        },
        service_name=service_name,
        validate=True,
    )
    
    # Inicializar tracer
    tracer = config.initialize_tracer()
    
    # Definir como tracer global
    opentracing.set_global_tracer(tracer)
    
    print("🔍 Jaeger tracing initialized for backend-service")
    print(f"📡 Agent: {jaeger_host}:{jaeger_port}")
    print(f"🎯 Sampling: {sampler_type} ({sampler_param})")
    
    return tracer

def get_current_trace_id():
    """
    Obtém o trace_id do span ativo atual
    """
    span = opentracing.tracer.active_span
    if span:
        return '{:x}'.format(span.context.trace_id)
    return None

def get_current_span_id():
    """
    Obtém o span_id do span ativo atual
    """
    span = opentracing.tracer.active_span
    if span:
        return '{:x}'.format(span.context.span_id)
    return None

def extract_span_context():
    """
    Extrai contexto de span dos headers HTTP da requisição Flask
    """
    try:
        span_ctx = opentracing.tracer.extract(
            opentracing.Format.HTTP_HEADERS,
            request.headers
        )
        return span_ctx
    except Exception:
        return None

def inject_span_context(span, headers):
    """
    Injeta contexto de span nos headers HTTP
    """
    try:
        opentracing.tracer.inject(
            span.context,
            opentracing.Format.HTTP_HEADERS,
            headers
        )
    except Exception:
        pass

def create_child_span(operation_name, parent_span=None):
    """
    Cria um span filho
    """
    if parent_span is None:
        parent_span = opentracing.tracer.active_span
    
    return opentracing.tracer.start_span(
        operation_name,
        child_of=parent_span
    )