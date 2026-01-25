# Dashboards do Grafana para Loki - Aula 04

## 🎯 Dashboard Recomendado

### ⭐ Dashboard 13639 - Loki & Promtail (RECOMENDADO)

**Este é o dashboard que funciona melhor para o projeto!**

**Importar**:
1. Acesse Grafana: http://IP_INSTANCIA_1
2. Menu lateral → Dashboards → Import
3. Digite: `13639`
4. Clique em "Load"
5. Selecione Data Source: **Loki**
6. Clique em "Import"

**Recursos**:
- ✅ Visão geral completa do Loki
- ✅ Métricas do Promtail (coleta de logs)
- ✅ Volume de logs por job
- ✅ Performance e latência
- ✅ Taxa de ingestão
- ✅ Erros de coleta
- ✅ Gráficos de série temporal
- ✅ Estatísticas detalhadas

**O que você verá**:
- Logs sendo coletados de: `test-app`, `nginx-access`, `log-generator`
- Taxa de logs por segundo
- Bytes enviados ao Loki
- Targets ativos do Promtail
- Latência de queries

---

## 🔍 Opções de Visualização

### 1. Explore (Mais Simples)

**Acesso**: Menu lateral → Explore (ícone 🧭)

**Passos**:
1. Selecione "Loki" como Data Source (ou "loki" se for o nome do seu datasource)
2. Use o **Label browser** para explorar os jobs disponíveis
3. Digite uma consulta LogQL ou use os filtros visuais
4. Clique em "Run query"

**Consultas Úteis**:
```logql
# Ver todos os logs da aplicação
{job="test-app"}

# Ver logs do Nginx
{job="nginx-access"}

# Ver apenas erros
{level="ERROR"}

# Filtrar por texto
{job="test-app"} |= "error"

# Taxa de logs
rate({job="test-app"}[5m])

# Todos os jobs disponíveis
{job=~".+"}
```

---

## 📊 2. Dashboard Customizado (Recomendado)

### Importar Dashboard Pronto

**Arquivo**: `grafana-dashboard-loki-logs.json`

**Passos**:
1. Acesse Grafana: http://IP_INSTANCIA_1
2. Login: admin / admin123
3. Menu lateral → Dashboards → Import
4. Clique em "Upload JSON file"
5. Selecione o arquivo `grafana-dashboard-loki-logs.json`
6. Clique em "Import"

**O que o dashboard inclui**:
- 📝 Logs da Aplicação Flask
- 🌐 Logs de Acesso do Nginx
- ❌ Logs de Erro do Nginx
- 📈 Taxa de Logs por Segundo (gráfico)
- 🚨 Todos os Logs de ERRO
- 🔄 Logs do Gerador

---

## 🌐 Outros Dashboards da Comunidade

### Dashboard 12019 - Loki Dashboard

**Importar**:
1. Dashboards → Import
2. Digite: `12019`
3. Load → Import

**Recursos**:
- Logs em tempo real
- Filtros avançados
- Estatísticas

**Nota**: Pode precisar de ajustes nas queries dependendo dos seus labels.

### Dashboard 15141 - Promtail

**Importar**:
1. Dashboards → Import
2. Digite: `15141`
3. Load → Import

**Recursos**:
- Monitoramento específico do Promtail
- Targets ativos
- Taxa de coleta
- Erros de coleta

**Nota**: Focado apenas no Promtail, não mostra os logs em si.

---

## 📊 Dashboard Customizado (Opcional)

Se você quiser criar seu próprio dashboard, use o arquivo `grafana-dashboard-loki-logs.json` como base.

**Importar**:
1. Dashboards → Import
2. Upload JSON file → `grafana-dashboard-loki-logs.json`
3. Selecione Data Source: Loki
4. Import

**Nota**: Este dashboard pode precisar de ajustes nas queries dependendo dos nomes dos seus jobs.

---

## 🎓 Resumo para Aula 04

### Dashboard Principal: 13639 ⭐
Use este dashboard como referência principal. Ele mostra:
- Volume de logs sendo coletados
- Performance do Loki
- Métricas do Promtail
- Visão geral da stack de observabilidade

### Para Consultas Específicas: Explore
Use o Explore para queries LogQL customizadas:
- `{job="test-app"}` - Logs da aplicação
- `{job="nginx-access"}` - Logs do Nginx
- `{level="ERROR"}` - Apenas erros

---

## 📚 Recursos

### Básicas
```logql
# Todos os logs de um job
{job="test-app"}

# Logs de múltiplos jobs
{job=~"test-app|nginx-access"}

# Logs com label específico
{job="test-app", level="INFO"}
```

### Filtros de Texto
```logql
# Contém "error"
{job="test-app"} |= "error"

# Não contém "health"
{job="nginx-access"} != "health"

# Regex
{job="test-app"} |~ "error|warning"
```

### Métricas
```logql
# Taxa de logs por segundo
rate({job="test-app"}[5m])

# Contagem de logs
count_over_time({job="test-app"}[5m])

# Bytes por segundo
bytes_rate({job="test-app"}[5m])
```

### Agregações
```logql
# Soma por job
sum(rate({job=~".+"}[5m])) by (job)

# Contagem de erros
sum(count_over_time({level="ERROR"}[5m]))

# Top 5 status codes
topk(5, sum by (status_code) (rate({job="nginx-access"}[5m])))
```

### Parsing
```logql
# Extrair campos JSON
{job="test-app"} | json

# Extrair com regex
{job="nginx-access"} | regexp "(?P<method>\\w+) (?P<path>\\S+)"

# Filtrar após parsing
{job="test-app"} | json | level="ERROR"
```

---

## 🎨 5. Criar Dashboard Customizado

### Passo a Passo

1. **Criar Dashboard**:
   - Dashboards → New Dashboard
   - Add new panel

2. **Configurar Query**:
   - Data Source: Loki
   - Query: `{job="test-app"}`

3. **Escolher Visualização**:
   - **Logs**: Para ver logs em formato de lista
   - **Time series**: Para gráficos de taxa/volume
   - **Stat**: Para contadores
   - **Table**: Para tabelas

4. **Configurar Opções**:
   - Title: Nome do painel
   - Description: Descrição
   - Time range: Período de tempo

5. **Salvar**:
   - Clique em "Apply"
   - Clique em "Save dashboard"

---

## 📝 6. Dicas de Uso

### Performance
- Use filtros de label primeiro: `{job="test-app"}` antes de filtros de texto
- Limite o período de tempo para consultas pesadas
- Use `rate()` em vez de `count_over_time()` quando possível

### Correlação
- Use variáveis de dashboard para filtrar múltiplos painéis
- Sincronize o tempo entre painéis
- Use links entre dashboards

### Alertas
- Configure alertas baseados em logs
- Use `count_over_time()` para detectar anomalias
- Combine com métricas do Prometheus

---

## 🚀 Próximos Passos

1. ✅ **Importar dashboard 13639** (principal)
2. ✅ Explorar consultas LogQL no Explore
3. ✅ Testar filtros e agregações
4. ✅ Criar alertas baseados em logs (opcional)
5. ✅ Correlacionar logs com métricas do Prometheus

---

## � Dicas de Uso

### Para Aula 04
- **Use o dashboard 13639** como referência principal
- **Use o Explore** para consultas específicas e aprendizado de LogQL
- **Correlacione** logs com métricas do Prometheus no mesmo período

### Jobs Disponíveis no Projeto
- `test-app` - Aplicação Flask de teste
- `nginx-access` - Logs de acesso HTTP do Nginx
- `log-generator` - Gerador automático de logs
- `docker-observability` - Logs dos containers de observabilidade
- `syslog` - Logs do sistema operacional

---

## 📚 Recursos

- [Documentação LogQL](https://grafana.com/docs/loki/latest/logql/)
- [Grafana Dashboards](https://grafana.com/grafana/dashboards/)
- [Loki Best Practices](https://grafana.com/docs/loki/latest/best-practices/)
