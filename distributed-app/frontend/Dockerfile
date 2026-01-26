# =============================================================================
# DOCKERFILE - FRONTEND SERVICE
# =============================================================================
# Frontend service com Node.js/Express e instrumentação OpenTelemetry
# Aula 05 - PosTech DevOps e Arquitetura Cloud - Monitoramento OpenSource
# =============================================================================

FROM node:18-alpine

# Definir diretório de trabalho
WORKDIR /app

# Copiar arquivos de dependências
COPY package*.json ./

# Instalar dependências
RUN npm install

# Copiar código da aplicação
COPY . .

# Criar diretório de logs
RUN mkdir -p /app/logs

# Expor porta da aplicação
EXPOSE 3000

# Comando para iniciar a aplicação com instrumentação
CMD ["node", "-r", "./tracing.js", "server.js"]