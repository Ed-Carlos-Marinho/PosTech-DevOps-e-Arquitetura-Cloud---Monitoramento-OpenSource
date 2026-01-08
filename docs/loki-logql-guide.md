# Guia Completo de LogQL e Correlação com Métricas

Guia prático para consultas LogQL no Loki e correlação com métricas do Prometheus no Grafana, parte da Aula 04 do módulo Monitoramento OpenSource.

## Introdução ao LogQL

LogQL é a linguagem de consulta do Loki, inspirada no PromQL do Prometheus, mas otimizada para logs. Permite filtrar, pesquisar e agregar dados de log de forma eficiente.

### Estrutura básica de uma consulta LogQL
```
{label_selector} |= "search_text" | parser | aggregation
```

## 1. Seletores de Labels (Label Selectors)

### Sintaxe básica
```logql
# Selecionar por job
{job="varlogs"}

# Selecionar por múltiplos labels
{job="varlogs", host="server-01"}

# Operadores de comparação
{job="varlogs", level!="debug"}        # Diferente de
{job=~"var.*"}                         # Regex match
{job!~"test.*"}                        # Regex não match
```

### Exemplos práticos
```logql
# Logs do sistema
{job="varlogs"}

# Logs de containers Docker
{job="docker"}

# Logs de um host específico
{host="monitored-host-01"}

# Logs de erro de qualquer fonte
{level="error"}

# Logs de containers stderr
{job="docker", stream="stderr"}
```

## 2. Filtros de Linha (Line Filters)

### Operadores de filtro
```logql
|=    # Contém (case-sensitive)
!=    # Não contém (case-sensitive)
|~    # Regex match
!~    # Regex não match
```

### Exemplos de filtros
```logql
# Logs contendo "error"
{job="varlogs"} |= "error"

# Logs não contendo "debug"
{job="varlogs"} != "debug"

# Logs com regex (case-insensitive)
{job="varlogs"} |~ "(?i)(error|fail|exception)"

# Logs de conexões SSH
{job="varlogs"} |= "sshd" |= "Accepted"

# Logs de falhas de autenticação
{job="varlogs"} |= "authentication failure"
```

## 3. Parsers (Extração de Dados)

### JSON Parser
```logql
# Para logs em formato JSON
{job="docker"} | json

# Extrair campos específicos
{job="docker"} | json level, message

# Usar campos extraídos como labels
{job="docker"} | json | level="error"
```

### Regex Parser
```logql
# Extrair campos com regex
{job="varlogs"} | regexp "(?P<timestamp>\\S+)\\s+(?P<host>\\S+)\\s+(?P<service>\\S+):"

# Usar campos extraídos
{job="varlogs"} | regexp "(?P<service>\\S+):" | service="systemd"
```

### Logfmt Parser
```logql
# Para logs no formato key=value
{job="app"} | logfmt

# Extrair campos específicos
{job="app"} | logfmt level, msg
```

## 4. Agregações e Funções

### Funções de contagem
```logql
# Contar linhas de log
count_over_time({job="varlogs"}[5m])

# Taxa de logs por segundo
rate({job="varlogs"}[5m])

# Soma de logs por label
sum by (host) (count_over_time({job="varlogs"}[5m]))
```

### Funções estatísticas
```logql
# Média de logs por minuto
avg_over_time(rate({job="varlogs"}[1m])[5m:1m])

# Máximo de logs em um período
max_over_time(count_over_time({job="varlogs"}[1m])[5m:1m])

# Percentil de logs
quantile_over_time(0.95, count_over_time({job="varlogs"}[1m])[5m:1m])
```

### Funções de agrupamento
```logql
# Top 10 hosts com mais logs
topk(10, sum by (host) (rate({job="varlogs"}[5m])))

# Bottom 5 serviços com menos logs
bottomk(5, sum by (service) (rate({job="varlogs"}[5m])))

# Agrupar por múltiplos labels
sum by (host, service) (rate({job="varlogs"}[5m]))
```

## 5. Consultas Avançadas

### Correlação temporal
```logql
# Logs de erro nos últimos 5 minutos
{job="varlogs"} |= "error" | __timestamp__ > now() - 5m

# Logs durante um período específico
{job="varlogs"} | __timestamp__ >= "2024-01-07T10:00:00Z" and __timestamp__ <= "2024-01-07T11:00:00Z"
```

### Análise de padrões
```logql
# Detectar picos de erro
increase(count_over_time({job="varlogs"} |= "error" [5m]))

# Comparar com período anterior
(
  count_over_time({job="varlogs"} |= "error" [5m])
  -
  count_over_time({job="varlogs"} |= "error" [5m] offset 1h)
)
```

### Filtros complexos
```logql
# Múltiplos filtros encadeados
{job="varlogs"} 
|= "systemd" 
|= "Started" 
!= "user@" 
|~ "\\.(service|timer)"

# Filtros condicionais
{job="docker"} 
| json 
| level="error" or level="fatal"
| message |~ "(?i)(timeout|connection)"
```

## 6. Correlação com Métricas do Prometheus

### Dashboards unificados

#### Painel de CPU + Logs de erro
```bash
# Métrica (Prometheus)
100 - (avg by(instance) (irate(node_cpu_seconds_total{mode="idle"}[5m])) * 100)

# Logs correlacionados (Loki)
{job="varlogs", host="$instance"} |= "error" | rate([5m])
```

#### Painel de Memory + Logs OOM
```bash
# Métrica (Prometheus)
(node_memory_MemTotal_bytes - node_memory_MemAvailable_bytes) / node_memory_MemTotal_bytes * 100

# Logs correlacionados (Loki)
{job="varlogs"} |~ "(?i)(oom|out of memory|memory)" | rate([5m])
```

#### Painel de Disk + Logs de I/O
```bash
# Métrica (Prometheus)
100 - (node_filesystem_avail_bytes / node_filesystem_size_bytes * 100)

# Logs correlacionados (Loki)
{job="varlogs"} |~ "(?i)(disk|i/o|filesystem)" | rate([5m])
```

### Variáveis compartilhadas

#### Configuração de variáveis no Grafana
```bash
# Variável: instance
Query: label_values(up, instance)
Type: Query

# Variável: job
Query: label_values({__name__=~".+"}, job)
Type: Query

# Variável: time_range
Type: Interval
Values: 5m,15m,30m,1h,6h,12h,1d
```

#### Uso das variáveis
```logql
# Em consultas Loki
{job="$job", host="$instance"}

# Em consultas Prometheus
up{instance="$instance", job="$job"}
```

## 7. Alertas Baseados em Logs

### Configuração no Prometheus (alert_rules.yml)
```yaml
groups:
  - name: log_alerts
    rules:
      - alert: HighErrorRate
        expr: |
          (
            sum(rate({job="varlogs"} |= "error" [5m])) by (host)
            /
            sum(rate({job="varlogs"}[5m])) by (host)
          ) > 0.1
        for: 2m
        labels:
          severity: warning
        annotations:
          summary: "High error rate in logs on {{ $labels.host }}"
          description: "Error rate is {{ $value | humanizePercentage }} on {{ $labels.host }}"

      - alert: ServiceDown
        expr: |
          count_over_time({job="varlogs"} |= "systemd" |= "Failed" [5m]) > 0
        for: 1m
        labels:
          severity: critical
        annotations:
          summary: "Service failure detected"
          description: "Service failure detected in logs on {{ $labels.host }}"
```

### Alertas no Grafana
```bash
# Configurar alerta no painel
1. Editar painel
2. Alert tab
3. Create Alert
4. Condition: IS ABOVE 10 (para taxa de erro > 10%)
5. Evaluation: every 1m for 2m
6. Notifications: escolher canal
```

## 8. Casos de Uso Práticos

### Troubleshooting de aplicações
```logql
# Encontrar erros de uma aplicação específica
{job="docker", container_name="app"} |= "error" | json | level="error"

# Analisar logs de startup
{job="varlogs"} |= "systemd" |= "Started" | regexp "Started (?P<service>.*)"

# Monitorar conexões de rede
{job="varlogs"} |~ "(?i)(connection|tcp|udp)" |= "established"
```

### Análise de segurança
```logql
# Tentativas de login falharam
{job="varlogs"} |= "sshd" |= "Failed password"

# Conexões suspeitas
{job="varlogs"} |= "sshd" |~ "(?i)(invalid|illegal|bad)"

# Mudanças de configuração
{job="varlogs"} |~ "(?i)(config|configuration)" |= "changed"
```

### Monitoramento de performance
```logql
# Logs de timeout
{job="varlogs"} |~ "(?i)timeout" | rate([5m])

# Logs de latência alta
{job="app"} | json | duration > 1000

# Análise de throughput
sum(rate({job="nginx"} |= "GET" [5m])) by (status_code)
```

## 9. Otimização de Consultas

### Boas práticas
```logql
# ✅ Bom: usar labels específicos primeiro
{job="varlogs", host="server-01"} |= "error"

# ❌ Ruim: filtro muito genérico
{} |= "error"

# ✅ Bom: usar regex eficiente
{job="varlogs"} |~ "error|fail|exception"

# ❌ Ruim: múltiplos filtros separados
{job="varlogs"} |= "error" or {job="varlogs"} |= "fail"
```

### Limitação de resultados
```logql
# Limitar número de linhas
{job="varlogs"} | limit 1000

# Usar time range apropriado
{job="varlogs"}[5m]  # Últimos 5 minutos

# Agregar quando possível
sum(rate({job="varlogs"}[5m])) by (host)
```

## 10. Debugging de Consultas

### Verificar labels disponíveis
```logql
# Ver todos os labels
{__name__=~".+"}

# Ver valores de um label específico
{job=~".+"}
```

### Testar consultas incrementalmente
```logql
# Passo 1: verificar seletor básico
{job="varlogs"}

# Passo 2: adicionar filtro
{job="varlogs"} |= "error"

# Passo 3: adicionar parser
{job="varlogs"} |= "error" | regexp "(?P<level>\\w+)"

# Passo 4: adicionar agregação
sum(rate({job="varlogs"} |= "error" [5m]))
```

### Usar métricas do Loki
```bash
# Verificar ingestão
curl http://localhost:3100/metrics | grep loki_ingester_streams

# Verificar consultas
curl http://localhost:3100/metrics | grep loki_query_duration_seconds
```

## 11. Integração com Grafana

### Configuração de painéis
```bash
# Painel de logs (Logs panel)
Query: {job="varlogs"} |= "error"
Options: 
  - Show time: true
  - Wrap lines: true
  - Prettify JSON: true

# Painel de estatísticas (Stat panel)
Query: sum(count_over_time({job="varlogs"} |= "error" [24h]))
Options:
  - Unit: short
  - Color mode: value
```

### Templates de dashboard
```json
{
  "dashboard": {
    "title": "Logs + Metrics Correlation",
    "panels": [
      {
        "title": "CPU Usage",
        "type": "graph",
        "targets": [
          {
            "expr": "100 - (avg by(instance) (irate(node_cpu_seconds_total{mode=\"idle\"}[5m])) * 100)",
            "datasource": "Prometheus"
          }
        ]
      },
      {
        "title": "Error Logs",
        "type": "logs",
        "targets": [
          {
            "expr": "{job=\"varlogs\", host=\"$instance\"} |= \"error\"",
            "datasource": "Loki"
          }
        ]
      }
    ]
  }
}
```

## 12. Troubleshooting Comum

### Consultas não retornam dados
```bash
# Verificar se labels existem
{job=~".+"}

# Verificar time range
{job="varlogs"}[1h]

# Verificar se Promtail está enviando dados
curl http://localhost:9080/metrics | grep promtail_sent_entries_total
```

### Performance lenta
```bash
# Usar labels mais específicos
{job="varlogs", filename="/var/log/syslog"}

# Reduzir time range
{job="varlogs"}[5m]  # ao invés de [24h]

# Usar agregações
sum(rate({job="varlogs"}[5m])) by (host)  # ao invés de dados brutos
```

### Parsing não funciona
```bash
# Testar regex online (regex101.com)
# Verificar escape de caracteres especiais
# Usar raw strings quando possível

# Exemplo correto:
{job="varlogs"} | regexp "(?P<timestamp>\\S+)\\s+(?P<host>\\S+)"
```

Este guia fornece uma base sólida para trabalhar com LogQL e correlacionar logs com métricas no Grafana, permitindo uma observabilidade completa da infraestrutura.