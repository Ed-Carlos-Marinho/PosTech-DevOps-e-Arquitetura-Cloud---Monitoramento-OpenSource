// =============================================================================
// JAEGER TRACING CONFIGURATION - BACKEND SERVICE
// =============================================================================
// Configuração de instrumentação com Jaeger Client Library nativo
// =============================================================================

const jaeger = require('jaeger-client');
const opentracing = require('opentracing');

// Configuração do Jaeger Client
const config = {
  serviceName: process.env.JAEGER_SERVICE_NAME || 'backend-service',
  sampler: {
    type: process.env.JAEGER_SAMPLER_TYPE || 'const',
    param: parseFloat(process.env.JAEGER_SAMPLER_PARAM || '1'),
  },
  reporter: {
    agentHost: process.env.JAEGER_AGENT_HOST || 'localhost',
    agentPort: parseInt(process.env.JAEGER_AGENT_PORT || '6832'),
    logSpans: true,
    flushIntervalMs: 2000,
  },
};

const options = {
  tags: {
    'backend-service.version': '1.0.0',
    'deployment.environment': process.env.NODE_ENV || 'development',
  },
  logger: {
    info: (msg) => console.log('JAEGER INFO:', msg),
    error: (msg) => console.error('JAEGER ERROR:', msg),
  },
};

let tracer;
try {
  tracer = jaeger.initTracer(config, options);
  opentracing.initGlobalTracer(tracer);
  
  console.log('🔍 Jaeger tracing initialized for backend-service');
  console.log(`📡 Agent: ${config.reporter.agentHost}:${config.reporter.agentPort}`);
  console.log(`🎯 Sampling: ${config.sampler.type} (${config.sampler.param})`);
} catch (error) {
  console.error('❌ Failed to initialize Jaeger tracer:', error.message);
  tracer = new opentracing.Tracer();
  opentracing.initGlobalTracer(tracer);
}

process.on('SIGTERM', () => {
  if (tracer && typeof tracer.close === 'function') {
    tracer.close(() => {
      console.log('🔍 Jaeger tracer closed');
      process.exit(0);
    });
  } else {
    process.exit(0);
  }
});

module.exports = tracer;
