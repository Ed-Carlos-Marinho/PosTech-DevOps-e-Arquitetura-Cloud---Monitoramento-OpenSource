# Loki Docker Compose

Stack de observabilidade com Loki, Promtail, Grafana e Prometheus usando Docker Compose, parte da Aula 04 do módulo Monitoramento OpenSource.

## Componentes da Stack

### Serviços de Logs
- **loki**: Sistema de agregação de logs (porta 3100)
- **promtail**: Agente de coleta de logs (porta 9080)

### Serviços de Métricas
- **grafana**: Plataforma de visualização unificada (porta 3000)
- **prometheus**: Coleta de métricas básicas (porta 9090)

### Volumes Persistentes
- **loki-data**: Logs, índices e chunks do Loki
- **promtail-positions**: Posições de leitura dos arquivos de log
- **grafana-data**: Dashboards, usuários e configurações do Grafana
- **prometheus-data**: Métricas e índices do Prometheus

## Como usar

### 1. Iniciar a stack completa
```bash
# Subir todos os serviços
docker-compose up -d

# Verificar status
docker-compose ps

# Ver logs em tempo real
docker-compose logs -f

# Ver logs específicos do Loki
docker-compose logs -f loki

# Ver logs específicos do Promtail
docker-compose logs -f promtail
```

### 2. Acessar interfaces web
- **Grafana**: `http://SEU_IP:3000`
  - Usuário: `admin`
  - Senha: `admin123`
- **Loki**: `http://SEU_IP:3100` (API - não tem interface web)
- **Promtail**: `http://SEU_IP:9080/metrics` (métricas)
- **Prometheus**: `http://SEU_IP:9090`

### 3. Configurar Data Sources no Grafana

#### Loki Data Source
1. **Configuration** → **Data Sources** → **Add data source**
2. **Type**: Loki
3. **URL**: `http://loki:3100`
4. **Access**: Server (default)
5. **Save & Test**

#### Prometheus Data Source
1. **Configuration** → **Data Sources** → **Add data source**
2. **Type**: Prometheus
3. **URL**: `http://prometheus:9090`
4. **Access**: Server (default)
5. **Save & Test**

### 4. Importar dashboards recomendados

#### Para Loki
- **Loki Stack Monitoring** (ID: 14055)
- **Promtail** (ID: 15141)
- **Logs App** (built-in do Grafana)

#### Para Prometheus
- **Node Exporter Full** (ID: 1860)
- **Docker Container & Host Metrics** (ID: 179)
- **Prometheus Stats** (ID: 2)

### 5. Consultas LogQL básicas

#### Consultas simples
```logql
# Todos os logs do job varlogs
{job="varlogs"}

# Logs específicos do syslog
{filename="/var/log/syslog"}

# Logs de containers Docker
{job="docker"}

# Logs de erro
{job="varlogs"} |= "error"

# Logs de warning
{job="varlogs"} |= "warning"
```

#### Consultas com filtros
```logql
# Logs de um serviço específico
{job="varlogs",service="systemd"}

# Logs de stderr de containers
{job="docker",stream="stderr"}

# Logs contendo palavras específicas
{job="varlogs"} |~ "(?i)(error|fail|exception)"

# Logs excluindo palavras específicas
{job="varlogs"} != "debug"
```

#### Consultas com agregações
```logql
# Taxa de logs por segundo
rate({job="varlogs"}[5m])

# Contagem de logs por nível
sum by (level) (rate({job="varlogs"}[5m]))

# Top 10 serviços com mais logs
topk(10, sum by (service) (rate({job="varlogs"}[5m])))

# Logs de erro nos últimos 5 minutos
count_over_time({job="varlogs"} |= "error" [5m])
```

### 6. Correlação entre logs e métricas

#### Dashboards combinados
1. **Criar dashboard** com painéis de métricas e logs
2. **Usar variáveis** para filtrar por instância/serviço
3. **Sincronizar time range** entre painéis
4. **Adicionar links** entre painéis relacionados

#### Exemplo de correlação
```bash
# Painel 1: CPU usage (Prometheus)
100 - (avg by(instance) (irate(node_cpu_seconds_total{mode="idle"}[5m])) * 100)

# Painel 2: Logs de erro da mesma instância (Loki)
{job="varlogs",hostname="$instance"} |= "error"

# Painel 3: Memory usage (Prometheus)
(node_memory_MemTotal_bytes - node_memory_MemAvailable_bytes) / node_memory_MemTotal_bytes * 100

# Painel 4: Logs relacionados à memória (Loki)
{job="varlogs"} |~ "(?i)(memory|oom|out of memory)"
```

## Troubleshooting

### Loki não inicia
```bash
# Ver logs do Loki
docker-compose logs loki

# Verificar configuração
docker-compose exec loki cat /etc/loki/local-config.yaml

# Verificar permissões de volumes
docker-compose exec loki ls -la /loki

# Reiniciar com configuração limpa
docker-compose down
docker volume rm $(docker volume ls -q | grep loki)
docker-compose up -d loki
```

### Promtail não coleta logs
```bash
# Ver logs do Promtail
docker-compose logs promtail

# Verificar configuração
docker-compose exec promtail cat /etc/promtail/config.yml

# Verificar posições de arquivos
docker-compose exec promtail cat /tmp/positions/positions.yaml

# Testar conectividade com Loki
docker-compose exec promtail wget -qO- http://loki:3100/ready
```

### Logs não aparecem no Grafana
```bash
# Verificar Data Source Loki no Grafana
# Configuration → Data Sources → Loki → Test

# Testar consulta LogQL simples
{job="varlogs"}

# Verificar se Promtail está enviando logs
curl http://localhost:9080/metrics | grep promtail_sent_entries_total

# Verificar se Loki está recebendo logs
curl http://localhost:3100/metrics | grep loki_ingester_streams
```

### Performance e recursos
```bash
# Monitorar uso de recursos
docker stats

# Verificar tamanho dos dados do Loki
du -sh /var/lib/docker/volumes/*loki*

# Ajustar retenção do Loki (no loki-config.yml)
# retention_period: 744h (31 dias)

# Configurar compactação mais frequente
# compaction_interval: 10m
```

## Configuração avançada

### 1. Alertas baseados em logs
```yaml
# No arquivo alert_rules.yml, adicionar:
- alert: HighErrorRate
  expr: |
    (
      sum(rate({job="varlogs"} |= "error" [5m])) by (instance)
      /
      sum(rate({job="varlogs"}[5m])) by (instance)
    ) > 0.1
  for: 2m
  labels:
    severity: warning
  annotations:
    summary: "High error rate in logs"
    description: "Error rate is above 10% on {{ $labels.instance }}"
```

### 2. Parsing customizado no Promtail
```yaml
# Adicionar ao promtail-config.yml:
pipeline_stages:
  - regex:
      expression: '^(?P<timestamp>\S+)\s+(?P<level>\S+)\s+(?P<message>.*)'
  - labels:
      level: level
  - timestamp:
      source: timestamp
      format: RFC3339
```

### 3. Labels dinâmicos
```yaml
# Extrair informações do path do arquivo:
- regex:
    expression: '/var/log/(?P<service>\w+)\.log'
    source: __path__
- labels:
    service: service
```

## Security Groups AWS

Para funcionar corretamente na AWS, libere as portas:
- **3000**: Interface web do Grafana
- **3100**: API do Loki (entre Promtail e Loki)
- **9080**: Métricas do Promtail
- **9090**: Interface web do Prometheus

## Backup e Restore

### Backup dos dados
```bash
# Backup dos volumes de logs
docker run --rm -v loki-data:/data -v $(pwd):/backup alpine tar czf /backup/loki-backup.tar.gz -C /data .
docker run --rm -v promtail-positions:/data -v $(pwd):/backup alpine tar czf /backup/promtail-positions-backup.tar.gz -C /data .

# Backup das configurações
cp loki-config.yml loki-config-backup.yml
cp promtail-config.yml promtail-config-backup.yml
```

### Restore dos dados
```bash
# Restore dos volumes
docker run --rm -v loki-data:/data -v $(pwd):/backup alpine tar xzf /backup/loki-backup.tar.gz -C /data
docker run --rm -v promtail-positions:/data -v $(pwd):/backup alpine tar xzf /backup/promtail-positions-backup.tar.gz -C /data
```

## Monitoramento da Stack de Logs

### Métricas importantes para monitorar
- **Loki**: loki_ingester_streams, loki_ingester_chunks_*
- **Promtail**: promtail_sent_entries_total, promtail_read_*
- **Grafana**: grafana_* metrics para dashboards de logs

### Alertas recomendados
- Promtail não consegue enviar logs para Loki
- Loki com alta latência de ingestão
- Espaço em disco baixo para dados do Loki
- Taxa alta de logs de erro
- Falhas de parsing no Promtail

## Observabilidade Completa

### Correlação logs + métricas
1. **Usar time range sincronizado** entre painéis
2. **Variáveis compartilhadas** (instance, service, etc.)
3. **Links entre dashboards** para navegação
4. **Annotations** para marcar eventos importantes
5. **Alertas combinados** baseados em logs e métricas

### Exemplo de dashboard unificado
- **Painel 1**: CPU/Memory usage (Prometheus)
- **Painel 2**: Error logs (Loki)
- **Painel 3**: Request rate (Prometheus)
- **Painel 4**: Access logs (Loki)
- **Painel 5**: Disk usage (Prometheus)
- **Painel 6**: System logs (Loki)