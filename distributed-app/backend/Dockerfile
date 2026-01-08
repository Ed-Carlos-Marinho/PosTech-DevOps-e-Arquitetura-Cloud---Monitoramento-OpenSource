# =============================================================================
# DOCKERFILE - BACKEND SERVICE
# =============================================================================
# Backend service com Python Flask e instrumentação OpenTelemetry
# Aula 05 - PosTech DevOps e Arquitetura Cloud - Monitoramento OpenSource
# =============================================================================

FROM python:3.9-slim

# Definir diretório de trabalho
WORKDIR /app

# Instalar dependências do sistema
RUN apt-get update && apt-get install -y \
    gcc \
    && rm -rf /var/lib/apt/lists/*

# Copiar arquivo de dependências
COPY requirements.txt .

# Instalar dependências Python
RUN pip install --no-cache-dir -r requirements.txt

# Copiar código da aplicação
COPY . .

# Criar diretório de logs
RUN mkdir -p /app/logs

# Expor porta da aplicação
EXPOSE 5000

# Comando para iniciar a aplicação com instrumentação
CMD ["python", "app.py"]