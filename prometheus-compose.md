# Prometheus Docker Compose

Stack do Prometheus para monitoramento moderno usando Docker Compose, parte da Aula 02 do módulo Monitoramento OpenSource.

## Componentes da Stack

### Serviços
- **prometheus**: Servidor principal de métricas (porta 9090)
- **alertmanager**: Gerenciamento de alertas (porta 9093)

### Volumes
- **prometheus-data**: Dados e séries temporais do Prometheus
- **alertmanager-data**: Dados do Alertmanager

## Como usar

### 1. Iniciar a stack
```bash
# Subir todos os serviços
docker-compose up -d

# Verificar status
docker-compose ps

# Ver logs em tempo real
docker-compose logs -f
```

### 2. Acessar interfaces web
- **Prometheus**: `http://SEU_IP:9090`
- **Alertmanager**: `http://SEU_IP:9093`

### 3. Gerenciar serviços
```bash
# Parar serviços
docker-compose down

# Parar e remover volumes (CUIDADO: apaga dados)
docker-compose down -v

# Atualizar imagens
docker-compose pull
docker-compose up -d

# Recarregar configuração do Prometheus
docker-compose restart prometheus
```

## Configuração inicial

### 1. Primeiro acesso
1. Acesse `http://SEU_IP:9090`
2. Vá em **Status** → **Targets** para verificar targets
3. Teste consultas básicas na aba **Graph**

### 2. Configurar targets
1. **Editar prometheus.yml** com IPs reais das instâncias
2. **Substituir** `IP_INSTANCIA_1` e `IP_INSTANCIA_2` pelos IPs privados
3. **Recarregar**: `docker-compose restart prometheus`

### 3. Verificar coleta de métricas
- **Status** → **Targets**: Todos devem estar "UP"
- **Graph**: Testar consultas como `up`, `node_cpu_seconds_total`
- **Alerts**: Verificar regras de alerta configuradas

## Arquivos de configuração

### prometheus.yml
Configuração principal do Prometheus:
- **Global settings**: Intervalos de scraping e avaliação
- **Rule files**: Arquivo de regras de alerta
- **Alerting**: Configuração do Alertmanager
- **Scrape configs**: Jobs de coleta de métricas

### alert_rules.yml
Regras de alerta configuradas:
- **HighCPUUsage**: CPU > 80% por 2 minutos
- **HighMemoryUsage**: Memória > 85% por 2 minutos
- **DiskSpaceLow**: Disco < 20% por 1 minuto
- **ServiceDown**: Serviço indisponível por 1 minuto

### alertmanager.yml
Configuração do Alertmanager:
- **Global**: Configurações SMTP
- **Route**: Roteamento de alertas
- **Receivers**: Destinos dos alertas (webhook, email)
- **Inhibit rules**: Regras de inibição de alertas

## Consultas PromQL úteis

### Métricas básicas
```promql
# Status de todos os targets
up

# Uso de CPU por instância
100 - (avg by(instance) (irate(node_cpu_seconds_total{mode="idle"}[5m])) * 100)

# Uso de memória por instância
(node_memory_MemTotal_bytes - node_memory_MemAvailable_bytes) / node_memory_MemTotal_bytes * 100

# Espaço em disco disponível
(node_filesystem_avail_bytes{mountpoint="/"} / node_filesystem_size_bytes{mountpoint="/"}) * 100
```

### Métricas de containers
```promql
# Uso de CPU por container
rate(container_cpu_usage_seconds_total[5m]) * 100

# Uso de memória por container
container_memory_usage_bytes / container_spec_memory_limit_bytes * 100

# Containers em execução
container_last_seen{name!=""}
```

### Agregações
```promql
# CPU médio de todas as instâncias
avg(100 - (avg by(instance) (irate(node_cpu_seconds_total{mode="idle"}[5m])) * 100))

# Total de memória usada no cluster
sum(node_memory_MemTotal_bytes - node_memory_MemAvailable_bytes)

# Número de instâncias ativas
count(up == 1)
```

## Portas utilizadas

- **9090**: Interface web Prometheus
- **9093**: Interface web Alertmanager
- **9100**: Node Exporter (nas instâncias monitoradas)
- **8080**: cAdvisor (nas instâncias monitoradas)

## Troubleshooting

### Prometheus não inicia
```bash
# Ver logs específicos
docker-compose logs prometheus

# Verificar configuração
docker-compose exec prometheus promtool check config /etc/prometheus/prometheus.yml

# Verificar regras de alerta
docker-compose exec prometheus promtool check rules /etc/prometheus/alert_rules.yml
```

### Targets não aparecem como UP
```bash
# Verificar conectividade
telnet IP_TARGET 9100
telnet IP_TARGET 8080

# Ver logs do Prometheus
docker-compose logs prometheus | grep -i error

# Verificar configuração de rede
docker-compose exec prometheus cat /etc/prometheus/prometheus.yml
```

### Alertmanager não recebe alertas
```bash
# Ver logs do Alertmanager
docker-compose logs alertmanager

# Verificar configuração
docker-compose exec alertmanager amtool config show

# Testar conectividade Prometheus → Alertmanager
docker-compose exec prometheus wget -qO- http://alertmanager:9093/-/healthy
```

### Recarregar configurações
```bash
# Recarregar configuração do Prometheus (sem restart)
curl -X POST http://localhost:9090/-/reload

# Recarregar configuração do Alertmanager
curl -X POST http://localhost:9093/-/reload

# Verificar se reload está habilitado
# Prometheus deve ter --web.enable-lifecycle
```

## Monitoramento de performance

### Métricas do próprio Prometheus
```promql
# Amostras ingeridas por segundo
rate(prometheus_tsdb_symbol_table_size_bytes[5m])

# Uso de memória do Prometheus
process_resident_memory_bytes{job="prometheus"}

# Duração das consultas
histogram_quantile(0.95, rate(prometheus_http_request_duration_seconds_bucket[5m]))

# Targets descobertos
prometheus_sd_discovered_targets
```

## Security Groups

Para funcionar corretamente, libere as portas:
- **9090**: Interface web Prometheus
- **9093**: Interface web Alertmanager
- **9100**: Node Exporter (comunicação entre instâncias)
- **8080**: cAdvisor (comunicação entre instâncias)