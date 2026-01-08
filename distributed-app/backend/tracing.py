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
    
    # Configuração do Jaeger Client
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
            'reporter_batch_size': 10,
            'reporter_queue_size': 100,
            'reporter_flush_interval': 1,
        },
        service_name=os.getenv('JAEGER_SERVICE_NAME', 'backend-service'),
        validate=True,
    )
    
    # Inicializar tracer
    tracer = config.initialize_tracer()
    
    # Definir como tracer global
    opentracing.set_global_tracer(tracer)
    
    print("🔍 Jaeger tracing initialized for backend-service")
    print(f"📡 Agent: {config.local_agent['reporting_host']}:{config.local_agent['reporting_port']}")
    print(f"🎯 Sampling: {config.sampler['type']} ({config.sampler['param']})")
    
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