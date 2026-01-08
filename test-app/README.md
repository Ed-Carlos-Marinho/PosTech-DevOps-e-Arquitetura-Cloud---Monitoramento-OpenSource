# Test Application - Aula 04

Aplicação de teste para geração de logs abundantes, parte da Aula 04 do módulo Monitoramento OpenSource.

## Componentes

### Aplicação Flask (`test-app.py`)
- Aplicação web que gera logs estruturados
- Endpoints para geração controlada de logs
- Atividade em background contínua
- Logs em múltiplos níveis (INFO, WARNING, ERROR)

### Nginx (`nginx.conf`)
- Proxy reverso para a aplicação
- Logs de acesso em formato detalhado e JSON
- Logs de erro separados
- Endpoints de teste para diferentes códigos HTTP

### Promtail (`promtail-app-config.yml`)
- Coleta logs da aplicação, Nginx e sistema
- Parsing específico para cada tipo de log
- Labels organizados por job, service, level
- Envio para Loki na Instância 1

### Log Generator
- Container adicional que gera logs continuamente
- Simula atividade de sistema em produção
- Logs em arquivo separado

## Como usar

### 1. Iniciar a stack
```bash
docker-compose -f docker-compose-app.yml up -d
```

### 2. Verificar status
```bash
docker-compose -f docker-compose-app.yml ps
```

### 3. Testar aplicação
```bash
# Página inicial
curl http://localhost/

# Gerar 50 logs
curl http://localhost/generate/50

# Teste de stress (30 segundos)
curl http://localhost/stress

# Forçar erro
curl http://localhost/error

# Health check
curl http://localhost/health
```

### 4. Ver logs
```bash
# Logs de todos os serviços
docker-compose -f docker-compose-app.yml logs -f

# Logs específicos
docker-compose -f docker-compose-app.yml logs -f test-app
docker-compose -f docker-compose-app.yml logs -f nginx
docker-compose -f docker-compose-app.yml logs -f promtail
```

### 5. Configurar Promtail
```bash
# Editar configuração
nano promtail-app-config.yml

# Substituir LOKI_SERVER_IP pelo IP real da Instância 1
sed -i 's/LOKI_SERVER_IP/10.0.1.100/' promtail-app-config.yml

# Reiniciar Promtail
docker-compose -f docker-compose-app.yml restart promtail
```

## Endpoints da Aplicação

- `GET /` - Página inicial com estatísticas
- `GET /generate/<count>` - Gera quantidade específica de logs
- `GET /health` - Health check
- `GET /stress` - Gera logs por 30 segundos (5 logs/segundo)
- `GET /error` - Força um erro para teste

## Tipos de Logs Gerados

### Aplicação Flask
- **INFO**: Operações normais, acessos, processamento
- **WARNING**: Operações lentas, avisos de performance
- **ERROR**: Falhas de conexão, timeouts, erros simulados

### Nginx
- **Access logs**: Todas as requisições HTTP com detalhes
- **Error logs**: Erros do servidor web
- **JSON logs**: Logs estruturados para parsing

### Log Generator
- **INFO**: Logs de atividade normal
- **WARNING**: Avisos aleatórios
- **ERROR**: Erros simulados (10% das vezes)

## Arquivos de Log

- `/app/logs/test-app.log` - Logs da aplicação Flask
- `/app/logs/generator.log` - Logs do gerador adicional
- `/var/log/nginx/access.log` - Logs de acesso do Nginx (formato detalhado)
- `/var/log/nginx/access-json.log` - Logs de acesso em JSON
- `/var/log/nginx/error.log` - Logs de erro do Nginx

## Troubleshooting

### Aplicação não inicia
```bash
# Ver logs da aplicação
docker-compose -f docker-compose-app.yml logs test-app

# Verificar se porta está livre
netstat -tlnp | grep :5000
```

### Nginx não conecta
```bash
# Ver logs do Nginx
docker-compose -f docker-compose-app.yml logs nginx

# Testar configuração
docker-compose -f docker-compose-app.yml exec nginx nginx -t
```

### Promtail não envia logs
```bash
# Ver logs do Promtail
docker-compose -f docker-compose-app.yml logs promtail

# Verificar métricas
curl http://localhost:9080/metrics

# Testar conectividade com Loki
docker-compose -f docker-compose-app.yml exec promtail wget -qO- http://LOKI_IP:3100/ready
```

## Desenvolvimento

### Modificar aplicação
1. Editar `test-app.py`
2. Rebuild: `docker-compose -f docker-compose-app.yml build test-app`
3. Restart: `docker-compose -f docker-compose-app.yml restart test-app`

### Adicionar dependências
1. Editar `requirements.txt`
2. Rebuild: `docker-compose -f docker-compose-app.yml build test-app`

### Modificar configuração Nginx
1. Editar `nginx.conf`
2. Restart: `docker-compose -f docker-compose-app.yml restart nginx`