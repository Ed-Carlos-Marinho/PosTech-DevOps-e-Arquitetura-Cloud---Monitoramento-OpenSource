#!/bin/bash
# =============================================================================
# SCRIPT DE GERAÇÃO DE TRÁFEGO
# =============================================================================
# Gera tráfego HTTP para criar logs no Nginx e na aplicação
# =============================================================================

echo "🚀 Gerando tráfego HTTP para criar logs..."
echo ""

# Verificar se a aplicação está respondendo
echo "1. Testando health check..."
curl -s http://localhost/health | jq . || curl -s http://localhost/health
echo ""

# Acessar página inicial várias vezes
echo "2. Acessando página inicial (10 requisições)..."
for i in {1..10}; do
    curl -s http://localhost/ > /dev/null
    echo -n "."
done
echo " ✅"

# Gerar logs de diferentes níveis
echo "3. Gerando logs INFO (50 entradas)..."
curl -s http://localhost/generate/50 > /dev/null
echo " ✅"

# Gerar logs de erro
echo "4. Gerando logs de ERRO..."
curl -s http://localhost/error > /dev/null
echo " ✅"

# Gerar logs com diferentes códigos HTTP
echo "5. Gerando diferentes códigos HTTP..."
curl -s http://localhost/load-test?code=404 > /dev/null
curl -s http://localhost/load-test?code=403 > /dev/null
curl -s http://localhost/load-test?code=500 > /dev/null
echo " ✅"

# Stress test (gera logs por 30 segundos em background)
echo "6. Iniciando stress test (30 segundos de logs contínuos)..."
curl -s http://localhost/stress > /dev/null &
echo " ✅"

echo ""
echo "✅ Tráfego gerado com sucesso!"
echo ""
echo "📊 Verificar logs:"
echo "   - Nginx access: docker exec nginx-proxy tail -20 /var/log/nginx/access.log"
echo "   - Nginx error: docker exec nginx-proxy tail -20 /var/log/nginx/error.log"
echo "   - Aplicação: docker exec test-app tail -20 /app/logs/test-app.log"
echo "   - Generator: docker exec log-generator tail -20 /app/logs/generator.log"
echo ""
echo "🔍 Verificar Promtail:"
echo "   - Targets: curl http://localhost:9080/targets"
echo "   - Métricas: curl http://localhost:9080/metrics | grep promtail_sent"
