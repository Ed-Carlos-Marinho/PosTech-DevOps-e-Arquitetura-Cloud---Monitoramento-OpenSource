// =============================================================================
// JAEGER TRACING CONFIGURATION - FRONTEND SERVICE
// =============================================================================
// Configuração de instrumentação com Jaeger Client Library nativo
// Aula 05 - PosTech DevOps e Arquitetura Cloud - Monitoramento OpenSource
// =============================================================================

const jaeger = require('jaeger-client');
const opentracing = require('opentracing');

// Configuração do Jaeger Client
const config = {
  serviceName: process.env.JAEGER_SERVICE_NAME || 'frontend-service',
  sampler: {
    type: process.env.JAEGER_SAMPLER_TYPE || 'const',
    param: parseFloat(process.env.JAEGER_SAMPLER_PARAM || '1'),
  },
  reporter: {
    // Configuração do Jaeger Agent
    agentHost: process.env.JAEGER_AGENT_HOST || 'localhost',
    agentPort: parseInt(process.env.JAEGER_AGENT_PORT || '6832'),
    
    // Configuração de logging
    logSpans: true,
    
    // Configuração de flush
    flushIntervalMs: 2000,
  },
};

// Opções adicionais
const options = {
  tags: {
    'frontend-service.version': '1.0.0',
    'deployment.environment': process.env.NODE_ENV || 'development',
  },
  metrics: {
    // Habilitar métricas do Jaeger
    factory: jaeger.PrometheusMetricsFactory,
  },
  logger: {
    info: (msg) => console.log('JAEGER INFO:', msg),
    error: (msg) => console.error('JAEGER ERROR:', msg),
  },
};

// Inicializar o tracer
const tracer = jaeger.initTracer(config, options);

// Definir como tracer global do OpenTracing
opentracing.initGlobalTracer(tracer);

console.log('🔍 Jaeger tracing initialized for frontend-service');
console.log(`📡 Agent: ${config.reporter.agentHost}:${config.reporter.agentPort}`);
console.log(`🎯 Sampling: ${config.sampler.type} (${config.sampler.param})`);

// Graceful shutdown
process.on('SIGTERM', () => {
  tracer.close(() => {
    console.log('🔍 Jaeger tracer closed');
    process.exit(0);
  });
});

// Exportar tracer para uso na aplicação
module.exports = tracer;