# Grafana Docker Compose

Stack completa de monitoramento com Grafana, Prometheus, Alertmanager e Zabbix usando Docker Compose, parte da Aula 03 do módulo Monitoramento OpenSource.

## Componentes da Stack

### Serviços Principais
- **grafana**: Plataforma de visualização e dashboards (porta 80)
- **prometheus**: Coleta de métricas modernas (porta 9090)
- **alertmanager**: Gerenciamento de alertas (porta 9093)
- **zabbix-server**: Monitoramento tradicional (porta 10051)
- **zabbix-web**: Interface web do Zabbix (porta 8081)
- **zabbix-db**: MySQL para Zabbix
- **zabbix-agent**: Agente local de monitoramento (porta 10050)

### Volumes Persistentes
- **grafana-data**: Dashboards, usuários e configurações do Grafana
- **grafana-config**: Configurações personalizadas do Grafana
- **prometheus-data**: Métricas e índices do Prometheus
- **alertmanager-data**: Estado e silenciamentos do Alertmanager
- **zabbix-db-data**: Dados do MySQL
- **zabbix-server-data**: Configurações do Zabbix Server

## Como usar

### 1. Iniciar a stack completa
```bash
# Subir todos os serviços
docker-compose up -d

# Verificar status
docker-compose ps

# Ver logs em tempo real
docker-compose logs -f
```

### 2. Acessar interfaces web
- **Grafana**: `http://SEU_IP:80`
  - Usuário: `admin`
  - Senha: `admin123`
- **Prometheus**: `http://SEU_IP:9090`
- **Alertmanager**: `http://SEU_IP:9093`
- **Zabbix**: `http://SEU_IP:8081`
  - Usuário: `Admin`
  - Senha: `zabbix`

### 3. Configurar Data Sources no Grafana

#### Prometheus Data Source
1. **Configuration** → **Data Sources** → **Add data source**
2. **Type**: Prometheus
3. **URL**: `http://prometheus:9090`
4. **Access**: Server (default)
5. **Save & Test**

#### Zabbix Data Source
1. Acesse o Grafana: `http://seu-servidor:80`
2. Login: `admin` / `admin123`
3. Vá em: **Configuration** → **Data Sources** → **Add data source**
4. Selecione: **Zabbix** (instalar plugin se necessário)
5. Configure:
   - **URL**: `http://zabbix-web:8080/api_jsonrpc.php`
   - **Username**: `Admin` (usuário padrão do Zabbix)
   - **Password**: `zabbix` (senha padrão do Zabbix)
6. **Save & Test**

**Nota importante**: Aguarde 1-2 minutos após iniciar a stack para que o Zabbix esteja completamente inicializado. Se receber erro "connection refused", verifique:
```bash
# Verificar se o Zabbix Web está rodando
docker-compose logs zabbix-web

# Verificar se o Zabbix Server está pronto
docker-compose logs zabbix-server | grep "server started"

# Testar conectividade do Grafana para o Zabbix
docker-compose exec grafana wget -O- http://zabbix-web:8080
```

#### Alertmanager Data Source
1. **Configuration** → **Data Sources** → **Add data source**
2. **Type**: Alertmanager
3. **URL**: `http://alertmanager:9093`
4. **Access**: Server (default)
5. **Save & Test**

### 4. Importar dashboards recomendados

Você pode buscar mais dashboards prontos em: https://grafana.com/grafana/dashboards

#### Para Prometheus
- **Node Exporter Full** (ID: 1860)
- **Docker Container & Host Metrics** (ID: 19724)
- **Prometheus Stats** (ID: 2)

#### Para Zabbix
- **Zabbix - Full Server Status** (ID: 5363)
- **Zabbix Server Dashboard** (ID: 8955)

#### Para Alertmanager
- **Alertmanager Overview** (ID: 9578)

### 5. Gerenciar serviços
```bash
# Parar serviços
docker-compose down

# Parar e remover volumes (CUIDADO: apaga dados)
docker-compose down -v

# Atualizar imagens
docker-compose pull
docker-compose up -d

# Reiniciar serviço específico
docker-compose restart grafana
```

## Configuração Avançada

### 1. Configurar alertas no Grafana
1. **Alerting** → **Alert Rules** → **New rule**
2. Configurar query (Prometheus ou Zabbix)
3. Definir condições e thresholds
4. Configurar notificações

### 2. Criar dashboards personalizados
1. **Create** → **Dashboard**
2. **Add panel**
3. Configurar query e visualização
4. Salvar dashboard

### 3. Configurar variáveis dinâmicas
1. **Dashboard settings** → **Variables**
2. **Add variable**
3. Configurar query para popular variável
4. Usar `$variavel` nos painéis

## Integração entre Ferramentas

### Grafana como Frontend Unificado
- **Prometheus**: Métricas de containers, APIs, aplicações modernas
- **Zabbix**: Monitoramento de infraestrutura, SNMP, agentes tradicionais
- **Alertmanager**: Centralização de alertas de ambas as fontes

### Fluxo de Dados
1. **Coleta**: Prometheus (pull) + Zabbix (push/pull)
2. **Armazenamento**: Prometheus TSDB + Zabbix MySQL
3. **Alertas**: Prometheus Rules → Alertmanager → Notificações
4. **Visualização**: Grafana dashboards unificados

## Troubleshooting

### Grafana não inicia
```bash
# Ver logs do Grafana
docker-compose logs grafana

# Verificar permissões de volumes
docker-compose exec grafana ls -la /var/lib/grafana

# Reiniciar com configuração limpa
docker-compose down
docker volume rm $(docker volume ls -q | grep grafana)
docker-compose up -d grafana
```

### Data Sources não conectam
```bash
# Testar conectividade de rede
docker-compose exec grafana ping prometheus
docker-compose exec grafana ping zabbix-web

# Verificar se serviços estão rodando
docker-compose ps

# Ver logs dos serviços
docker-compose logs prometheus
docker-compose logs zabbix-server
```

### Dashboards não carregam dados
```bash
# Verificar targets no Prometheus
curl http://localhost:9090/api/v1/targets

# Testar query PromQL
curl 'http://localhost:9090/api/v1/query?query=up'

# Verificar hosts no Zabbix
# Acessar http://localhost:8081 → Configuration → Hosts
```

### Performance e recursos
```bash
# Monitorar uso de recursos
docker stats

# Ajustar retenção do Prometheus (no docker-compose.yml)
# --storage.tsdb.retention.time=200h

# Configurar limpeza do Zabbix
# ZBX_HOUSEKEEPINGFREQUENCY: 1
```

## Security Groups AWS

Para funcionar corretamente na AWS, libere as portas:
- **80**: Interface web do Grafana
- **9090**: Interface web do Prometheus
- **9093**: Interface web do Alertmanager
- **8080**: Code-server
- **8081**: Interface web do Zabbix
- **10051**: Zabbix Server (para agentes)
- **10050**: Zabbix Agent (do servidor para agentes)

## Backup e Restore

### Backup dos dados
```bash
# Backup dos volumes
docker run --rm -v grafana-data:/data -v $(pwd):/backup alpine tar czf /backup/grafana-backup.tar.gz -C /data .
docker run --rm -v prometheus-data:/data -v $(pwd):/backup alpine tar czf /backup/prometheus-backup.tar.gz -C /data .

# Backup do banco Zabbix
docker-compose exec zabbix-db mysqldump -u root -p zabbix > zabbix-backup.sql
```

### Restore dos dados
```bash
# Restore dos volumes
docker run --rm -v grafana-data:/data -v $(pwd):/backup alpine tar xzf /backup/grafana-backup.tar.gz -C /data
docker run --rm -v prometheus-data:/data -v $(pwd):/backup alpine tar xzf /backup/prometheus-backup.tar.gz -C /data

# Restore do banco Zabbix
docker-compose exec -T zabbix-db mysql -u root -p zabbix < zabbix-backup.sql
```

## Monitoramento da Stack

### Métricas importantes para monitorar
- **Grafana**: grafana_* metrics
- **Prometheus**: prometheus_* metrics
- **Zabbix**: zabbix_* metrics via Zabbix Agent
- **Containers**: container_* metrics via cAdvisor

### Alertas recomendados
- Serviços down (up == 0)
- Alto uso de CPU/memória dos containers
- Espaço em disco baixo
- Falhas de conectividade entre serviços