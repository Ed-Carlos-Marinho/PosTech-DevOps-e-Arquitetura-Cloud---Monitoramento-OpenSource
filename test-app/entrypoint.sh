#!/bin/sh
# =============================================================================
# ENTRYPOINT SCRIPT - TEST APPLICATION
# =============================================================================
# Garante que o diretório de logs existe antes de iniciar a aplicação
# =============================================================================

# Criar diretório de logs se não existir
mkdir -p /app/logs

# Criar arquivo de log vazio se não existir
touch /app/logs/test-app.log

# Verificar permissões
ls -la /app/logs/

# Iniciar aplicação
exec python test-app.py
