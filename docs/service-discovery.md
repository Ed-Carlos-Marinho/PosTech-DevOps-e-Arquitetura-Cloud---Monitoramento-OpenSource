# Service Discovery no Prometheus

Guia de configuração de Service Discovery para descoberta automática de targets (Node Exporter e cAdvisor).

---

## 📋 VISÃO GERAL

Service Discovery permite que o Prometheus descubra automaticamente novos targets sem precisar editar manualmente o arquivo de configuração. Isso é especialmente útil em ambientes dinâmicos onde instâncias são criadas e destruídas frequentemente.

---

## 🔍 OPÇÕES DE SERVICE DISCOVERY

### 1. EC2 Service Discovery (AWS)

Descobre automaticamente instâncias EC2 baseado em tags, security groups, etc.

#### Configuração no prometheus.yml

```yaml
scrape_configs:
  # Node Exporter via EC2 Discovery
  - job_name: 'node-exporter-ec2'
    ec2_sd_configs:
      - region: us-east-1
        port: 9100
        # Filtros opcionais
        filters:
          - name: tag:Environment
            values: [production]
          - name: instance-state-name
            values: [running]
    
    relabel_configs:
      # Usa IP privado ao invés de público
      - source_labels: [__meta_ec2_private_ip]
        target_label: __address__
        replacement: '${1}:9100'
      
      # Adiciona nome da instância como label
      - source_labels: [__meta_ec2_tag_Name]
        target_label: instance_name
      
      # Adiciona instance ID
      - source_labels: [__meta_ec2_instance_id]
        target_label: instance_id
      
      # Adiciona tipo de instância
      - source_labels: [__meta_ec2_instance_type]
        target_label: instance_type
      
      # Adiciona availability zone
      - source_labels: [__meta_ec2_availability_zone]
        target_label: availability_zone
      
      # Adiciona tags customizadas
      - source_labels: [__meta_ec2_tag_Environment]
        target_label: environment
      
      - source_labels: [__meta_ec2_tag_Team]
        target_label: team

  # cAdvisor via EC2 Discovery
  - job_name: 'cadvisor-ec2'
    ec2_sd_configs:
      - region: us-east-1
        port: 8080
        filters:
          - name: tag:Environment
            values: [production]
          - name: instance-state-name
            values: [running]
    
    relabel_configs:
      - source_labels: [__meta_ec2_private_ip]
        target_label: __address__
        replacement: '${1}:8080'
      
      - source_labels: [__meta_ec2_tag_Name]
        target_label: instance_name
      
      - source_labels: [__meta_ec2_instance_id]
        target_label: instance_id
```

#### Configuração de Credenciais AWS

**Opção 1: Variáveis de Ambiente**
```yaml
# docker-compose.yml
services:
  prometheus:
    environment:
      - AWS_ACCESS_KEY_ID=YOUR_ACCESS_KEY
      - AWS_SECRET_ACCESS_KEY=YOUR_SECRET_KEY
      - AWS_REGION=us-east-1
```

**Opção 2: IAM Role (Recomendado para EC2)**
```bash
# Anexar IAM Role à instância EC2 com política:
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "ec2:DescribeInstances",
        "ec2:DescribeAvailabilityZones"
      ],
      "Resource": "*"
    }
  ]
}
```

**Opção 3: Arquivo de Credenciais**
```yaml
# prometheus.yml
ec2_sd_configs:
  - region: us-east-1
    access_key: YOUR_ACCESS_KEY
    secret_key: YOUR_SECRET_KEY
    port: 9100
```

---

### 2. File-based Service Discovery (Mais Simples)

Usa arquivos JSON ou YAML para definir targets. Prometheus recarrega automaticamente quando o arquivo muda.

#### Configuração no prometheus.yml

```yaml
scrape_configs:
  # Node Exporter via File Discovery
  - job_name: 'node-exporter-file'
    file_sd_configs:
      - files:
          - '/etc/prometheus/targets/node-exporter-*.json'
          - '/etc/prometheus/targets/node-exporter-*.yml'
        refresh_interval: 30s  # Verifica mudanças a cada 30s

  # cAdvisor via File Discovery
  - job_name: 'cadvisor-file'
    file_sd_configs:
      - files:
          - '/etc/prometheus/targets/cadvisor-*.json'
          - '/etc/prometheus/targets/cadvisor-*.yml'
        refresh_interval: 30s
```

#### Exemplo de Arquivo JSON

**targets/node-exporter-prod.json**
```json
[
  {
    "targets": [
      "10.0.1.10:9100",
      "10.0.1.11:9100",
      "10.0.1.12:9100"
    ],
    "labels": {
      "environment": "production",
      "team": "backend",
      "datacenter": "us-east-1"
    }
  }
]
```

**targets/cadvisor-prod.json**
```json
[
  {
    "targets": [
      "10.0.1.10:8080",
      "10.0.1.11:8080",
      "10.0.1.12:8080"
    ],
    "labels": {
      "environment": "production",
      "team": "backend",
      "datacenter": "us-east-1"
    }
  }
]
```

#### Exemplo de Arquivo YAML

**targets/node-exporter-prod.yml**
```yaml
- targets:
    - 10.0.1.10:9100
    - 10.0.1.11:9100
    - 10.0.1.12:9100
  labels:
    environment: production
    team: backend
    datacenter: us-east-1
```

**targets/cadvisor-prod.yml**
```yaml
- targets:
    - 10.0.1.10:8080
    - 10.0.1.11:8080
    - 10.0.1.12:8080
  labels:
    environment: production
    team: backend
    datacenter: us-east-1
```

#### Configuração no docker-compose.yml

```yaml
services:
  prometheus:
    volumes:
      - ./prometheus.yml:/etc/prometheus/prometheus.yml
      - ./alert_rules.yml:/etc/prometheus/alert_rules.yml
      - ./targets:/etc/prometheus/targets  # Adicionar este volume
      - prometheus-data:/prometheus
```

---

### 3. Consul Service Discovery

Usa Consul para descoberta de serviços.

```yaml
scrape_configs:
  - job_name: 'node-exporter-consul'
    consul_sd_configs:
      - server: 'consul.example.com:8500'
        services: ['node-exporter']
    
    relabel_configs:
      - source_labels: [__meta_consul_service]
        target_label: job
      
      - source_labels: [__meta_consul_node]
        target_label: instance
      
      - source_labels: [__meta_consul_tags]
        target_label: tags

  - job_name: 'cadvisor-consul'
    consul_sd_configs:
      - server: 'consul.example.com:8500'
        services: ['cadvisor']
```

---

### 4. Docker Service Discovery

Descobre containers Docker automaticamente.

```yaml
scrape_configs:
  - job_name: 'docker-containers'
    docker_sd_configs:
      - host: unix:///var/run/docker.sock
    
    relabel_configs:
      # Apenas containers com label prometheus.scrape=true
      - source_labels: [__meta_docker_container_label_prometheus_scrape]
        action: keep
        regex: true
      
      # Usa porta definida no label
      - source_labels: [__meta_docker_container_label_prometheus_port]
        action: replace
        target_label: __address__
        regex: (.+)
        replacement: $1
      
      # Nome do container
      - source_labels: [__meta_docker_container_name]
        target_label: container_name
```

---

### 6. cAdvisor para Descobrir Containers Docker

O cAdvisor **automaticamente descobre e monitora todos os containers** rodando no host. Não é necessário configurar service discovery no Prometheus - basta apontar para o cAdvisor!

#### Como Funciona

1. **cAdvisor roda em cada host** e monitora o Docker daemon
2. **Descobre automaticamente** todos os containers em execução
3. **Expõe métricas** de todos os containers em um único endpoint
4. **Prometheus coleta** as métricas do cAdvisor (não dos containers diretamente)

#### Arquitetura

```
┌─────────────────────────────────────────┐
│           Host / EC2 Instance           │
│                                         │
│  ┌──────────┐  ┌──────────┐            │
│  │Container1│  │Container2│  ← Docker  │
│  └──────────┘  └──────────┘            │
│       ↑              ↑                  │
│       └──────┬───────┘                  │
│              │                          │
│         ┌────▼─────┐                    │
│         │ cAdvisor │ ← Descobre todos   │
│         │  :8080   │   os containers    │
│         └────┬─────┘                    │
└──────────────┼──────────────────────────┘
               │
               ↓ Scrape
        ┌──────────────┐
        │  Prometheus  │
        └──────────────┘
```

#### Configuração no Prometheus

```yaml
scrape_configs:
  # cAdvisor descobre containers automaticamente
  - job_name: 'cadvisor'
    static_configs:
      - targets: 
          - 'host1:8080'  # cAdvisor no host 1
          - 'host2:8080'  # cAdvisor no host 2
    
    # Opcional: adicionar labels customizados
    relabel_configs:
      - source_labels: [__address__]
        regex: '([^:]+):.*'
        target_label: host
        replacement: '${1}'
```

#### Métricas Disponíveis

O cAdvisor expõe métricas de **todos os containers** automaticamente:

```promql
# Listar todos os containers descobertos
container_last_seen

# CPU por container
rate(container_cpu_usage_seconds_total{name!=""}[5m])

# Memória por container
container_memory_usage_bytes{name!=""}

# Rede por container
rate(container_network_receive_bytes_total{name!=""}[5m])

# I/O de disco por container
rate(container_fs_reads_bytes_total{name!=""}[5m])
```

#### Exemplo Completo: cAdvisor + Docker Compose

**docker-compose.yml no host monitorado:**

```yaml
version: '3.8'

services:
  # cAdvisor - Monitora containers
  cadvisor:
    image: gcr.io/cadvisor/cadvisor:latest
    container_name: cadvisor
    ports:
      - "8080:8080"
    volumes:
      - /:/rootfs:ro
      - /var/run:/var/run:ro
      - /sys:/sys:ro
      - /var/lib/docker/:/var/lib/docker:ro
      - /dev/disk/:/dev/disk:ro
    privileged: true
    devices:
      - /dev/kmsg
    restart: unless-stopped
  
  # Seus containers de aplicação
  app1:
    image: nginx:latest
    container_name: my-app-1
    ports:
      - "8081:80"
  
  app2:
    image: redis:latest
    container_name: my-app-2
    ports:
      - "6379:6379"
```

**prometheus.yml:**

```yaml
scrape_configs:
  - job_name: 'cadvisor'
    static_configs:
      - targets: ['10.0.1.10:8080', '10.0.1.11:8080']
        labels:
          environment: production
          datacenter: us-east-1
```

**Resultado:** Prometheus automaticamente coleta métricas de **todos os containers** (app1, app2, cadvisor, etc.) através do cAdvisor!

#### Filtrando Containers Específicos

```promql
# Apenas containers de aplicação (excluir cAdvisor, POD, etc.)
container_memory_usage_bytes{name!="", name!~"POD|k8s_.*"}

# Apenas containers com nome específico
container_cpu_usage_seconds_total{name="my-app-1"}

# Containers por imagem
container_memory_usage_bytes{image=~"nginx.*"}

# Excluir containers do sistema
container_memory_usage_bytes{name!="", name!~"cadvisor|prometheus|alertmanager"}
```

#### Queries Úteis para Containers

```promql
# Listar todos os containers ativos
count by(name, instance) (container_last_seen{name!=""})

# Top 5 containers por uso de CPU
topk(5, rate(container_cpu_usage_seconds_total{name!=""}[5m]))

# Top 5 containers por uso de memória
topk(5, container_memory_usage_bytes{name!=""})

# Containers usando mais de 80% do limite de memória
(container_memory_usage_bytes{name!=""} / container_spec_memory_limit_bytes{name!=""}) * 100 > 80

# Tráfego de rede por container
sum by(name) (rate(container_network_receive_bytes_total{name!=""}[5m]) + rate(container_network_transmit_bytes_total{name!=""}[5m]))

# Containers reiniciados recentemente
changes(container_last_seen{name!=""}[5m]) > 0
```

#### Alertas para Containers

```yaml
# alert_rules.yml
groups:
  - name: container_alerts
    rules:
      - alert: ContainerHighCPU
        expr: rate(container_cpu_usage_seconds_total{name!=""}[5m]) * 100 > 80
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: "Container {{ $labels.name }} high CPU"
          description: "Container {{ $labels.name }} on {{ $labels.instance }} is using {{ $value }}% CPU"
      
      - alert: ContainerHighMemory
        expr: (container_memory_usage_bytes{name!=""} / container_spec_memory_limit_bytes{name!=""}) * 100 > 80
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: "Container {{ $labels.name }} high memory"
          description: "Container {{ $labels.name }} is using {{ $value }}% of memory limit"
      
      - alert: ContainerDown
        expr: time() - container_last_seen{name!=""} > 60
        for: 1m
        labels:
          severity: critical
        annotations:
          summary: "Container {{ $labels.name }} is down"
          description: "Container {{ $labels.name }} on {{ $labels.instance }} has been down for more than 1 minute"
```

#### Vantagens do cAdvisor

✅ **Descoberta automática** - Não precisa configurar cada container  
✅ **Zero configuração** nos containers - Não precisa instrumentar aplicações  
✅ **Métricas detalhadas** - CPU, memória, rede, disco, etc.  
✅ **Suporte nativo** - Funciona com Docker, containerd, CRI-O  
✅ **Baixo overhead** - Impacto mínimo na performance  
✅ **Labels automáticos** - Nome, imagem, ID do container  

#### Limitações

❌ **Não monitora métricas de aplicação** - Apenas métricas de container (use exporters específicos para isso)  
❌ **Requer acesso ao Docker socket** - Precisa rodar com privilégios  
❌ **Não funciona para containers remotos** - Precisa rodar no mesmo host  

#### Combinando cAdvisor com Service Discovery

Você pode combinar cAdvisor com service discovery para descobrir **hosts** automaticamente:

```yaml
scrape_configs:
  # Descobre hosts via EC2, cAdvisor descobre containers
  - job_name: 'cadvisor-ec2'
    ec2_sd_configs:
      - region: us-east-1
        port: 8080
        filters:
          - name: tag:Monitoring
            values: [enabled]
    
    relabel_configs:
      - source_labels: [__meta_ec2_private_ip]
        target_label: __address__
        replacement: '${1}:8080'
      
      - source_labels: [__meta_ec2_tag_Name]
        target_label: host_name
```

**Resultado:** Prometheus descobre hosts automaticamente (via EC2 SD) e cAdvisor descobre containers automaticamente em cada host!

#### Dashboard Grafana para Containers

Dashboards prontos para cAdvisor:
- **ID 893** - Docker and System Monitoring
- **ID 11600** - Docker Container & Host Metrics
- **ID 14282** - Cadvisor exporter

Importar no Grafana:
1. Acesse Grafana → Dashboards → Import
2. Digite o ID do dashboard
3. Selecione o datasource do Prometheus
4. Clique em Import

---

### 5. Kubernetes Service Discovery

Para ambientes Kubernetes.

```yaml
scrape_configs:
  # Descoberta de Pods
  - job_name: 'kubernetes-pods'
    kubernetes_sd_configs:
      - role: pod
    
    relabel_configs:
      # Apenas pods com annotation prometheus.io/scrape=true
      - source_labels: [__meta_kubernetes_pod_annotation_prometheus_io_scrape]
        action: keep
        regex: true
      
      # Usa porta da annotation
      - source_labels: [__meta_kubernetes_pod_annotation_prometheus_io_port]
        action: replace
        target_label: __address__
        regex: ([^:]+)(?::\d+)?;(\d+)
        replacement: $1:$2
      
      # Path customizado
      - source_labels: [__meta_kubernetes_pod_annotation_prometheus_io_path]
        action: replace
        target_label: __metrics_path__
        regex: (.+)
      
      # Labels do pod
      - source_labels: [__meta_kubernetes_namespace]
        target_label: kubernetes_namespace
      
      - source_labels: [__meta_kubernetes_pod_name]
        target_label: kubernetes_pod_name

  # Descoberta de Services
  - job_name: 'kubernetes-services'
    kubernetes_sd_configs:
      - role: service
    
    relabel_configs:
      - source_labels: [__meta_kubernetes_service_annotation_prometheus_io_scrape]
        action: keep
        regex: true
```

---

## 🛠️ SCRIPT DE AUTOMAÇÃO

### Script para Gerar Arquivo de Targets Automaticamente

**generate-targets.sh**
```bash
#!/bin/bash

# Script para gerar arquivo de targets dinamicamente
# Útil para integrar com ferramentas de automação

OUTPUT_DIR="./targets"
mkdir -p "$OUTPUT_DIR"

# Descobrir instâncias EC2 via AWS CLI
echo "Descobrindo instâncias EC2..."

# Node Exporter targets
aws ec2 describe-instances \
  --region us-east-1 \
  --filters "Name=tag:Monitoring,Values=enabled" "Name=instance-state-name,Values=running" \
  --query 'Reservations[].Instances[].[PrivateIpAddress,Tags[?Key==`Name`].Value|[0],Tags[?Key==`Environment`].Value|[0]]' \
  --output text | \
  awk 'BEGIN {print "["; print "  {"; print "    \"targets\": ["}
       {printf "      \"%s:9100\"%s\n", $1, (NR==FNR?"":","); 
        labels[NR]=$2"|"$3}
       END {print "    ],"; 
            print "    \"labels\": {";
            print "      \"environment\": \"production\",";
            print "      \"job\": \"node-exporter\"";
            print "    }";
            print "  }";
            print "]"}' > "$OUTPUT_DIR/node-exporter-auto.json"

# cAdvisor targets
aws ec2 describe-instances \
  --region us-east-1 \
  --filters "Name=tag:Monitoring,Values=enabled" "Name=instance-state-name,Values=running" \
  --query 'Reservations[].Instances[].[PrivateIpAddress]' \
  --output text | \
  awk 'BEGIN {print "["; print "  {"; print "    \"targets\": ["}
       {printf "      \"%s:8080\"%s\n", $1, (NR==FNR?"":",");}
       END {print "    ],"; 
            print "    \"labels\": {";
            print "      \"environment\": \"production\",";
            print "      \"job\": \"cadvisor\"";
            print "    }";
            print "  }";
            print "]"}' > "$OUTPUT_DIR/cadvisor-auto.json"

echo "Targets gerados em $OUTPUT_DIR"
echo "Prometheus irá recarregar automaticamente em até 30 segundos"
```

**Executar periodicamente via cron:**
```bash
# Editar crontab
crontab -e

# Adicionar linha para executar a cada 5 minutos
*/5 * * * * /path/to/generate-targets.sh
```

---

## 📊 RELABEL CONFIGS ÚTEIS

### Exemplos de Relabeling

```yaml
relabel_configs:
  # Manter apenas targets com label específico
  - source_labels: [__meta_ec2_tag_Monitoring]
    action: keep
    regex: enabled

  # Remover targets com label específico
  - source_labels: [__meta_ec2_tag_Environment]
    action: drop
    regex: development

  # Renomear label
  - source_labels: [__meta_ec2_tag_Name]
    target_label: instance_name

  # Combinar múltiplos labels
  - source_labels: [__meta_ec2_tag_Environment, __meta_ec2_tag_Team]
    separator: '-'
    target_label: env_team

  # Usar regex para extrair parte do valor
  - source_labels: [__meta_ec2_tag_Name]
    regex: '(.*)-server-.*'
    target_label: service
    replacement: '${1}'

  # Adicionar label fixo
  - target_label: cluster
    replacement: production

  # Modificar endereço do target
  - source_labels: [__meta_ec2_private_ip]
    target_label: __address__
    replacement: '${1}:9100'

  # Modificar path de métricas
  - target_label: __metrics_path__
    replacement: /custom/metrics
```

---

## 🔍 VERIFICANDO SERVICE DISCOVERY

### Via Prometheus UI

1. Acesse: `http://localhost:9090/targets`
2. Veja todos os targets descobertos
3. Verifique labels aplicados

### Via Prometheus UI - Service Discovery

1. Acesse: `http://localhost:9090/service-discovery`
2. Veja todos os targets descobertos antes do relabeling
3. Útil para debug

### Via API

```bash
# Listar todos os targets
curl http://localhost:9090/api/v1/targets

# Listar apenas targets ativos
curl http://localhost:9090/api/v1/targets?state=active

# Ver configuração de service discovery
curl http://localhost:9090/api/v1/status/config
```

---

## 🎯 EXEMPLO COMPLETO PARA SEU AMBIENTE

### prometheus.yml com File-based Discovery

```yaml
global:
  scrape_interval: 15s
  evaluation_interval: 15s

rule_files:
  - "alert_rules.yml"

alerting:
  alertmanagers:
    - static_configs:
        - targets:
          - alertmanager:9093

scrape_configs:
  - job_name: 'prometheus'
    static_configs:
      - targets: ['localhost:9090']
  
  # Node Exporter com File Discovery
  - job_name: 'node-exporter'
    file_sd_configs:
      - files:
          - '/etc/prometheus/targets/node-exporter-*.json'
        refresh_interval: 30s
    
    relabel_configs:
      - source_labels: [__address__]
        target_label: instance
  
  # cAdvisor com File Discovery
  - job_name: 'cadvisor'
    file_sd_configs:
      - files:
          - '/etc/prometheus/targets/cadvisor-*.json'
        refresh_interval: 30s
    
    relabel_configs:
      - source_labels: [__address__]
        target_label: instance
```

### Estrutura de Diretórios

```
.
├── prometheus.yml
├── alert_rules.yml
├── alertmanager.yml
├── docker-compose.yml
└── targets/
    ├── node-exporter-prod.json
    ├── node-exporter-dev.json
    ├── cadvisor-prod.json
    └── cadvisor-dev.json
```

---

## 💡 BOAS PRÁTICAS

1. **Use File-based Discovery** para começar - é mais simples e flexível
2. **Use EC2 Discovery** se tiver muitas instâncias dinâmicas na AWS
3. **Sempre use relabel_configs** para adicionar labels úteis
4. **Teste as configurações** antes de aplicar em produção
5. **Monitore o próprio Prometheus** para ver se o discovery está funcionando
6. **Use filtros** para evitar descobrir targets desnecessários
7. **Documente os labels** usados para facilitar queries
8. **Automatize a geração de targets** com scripts
9. **Use refresh_interval adequado** - não muito curto para não sobrecarregar
10. **Valide os arquivos JSON/YAML** antes de usar

---

## 🚀 PRÓXIMOS PASSOS

1. Escolher método de discovery (File-based ou EC2)
2. Criar estrutura de diretórios
3. Configurar prometheus.yml
4. Criar arquivos de targets
5. Atualizar docker-compose.yml
6. Testar e validar
7. Automatizar com scripts (opcional)

---

**Autor**: PosTech DevOps e Arquitetura Cloud  
**Aula**: 02 - Monitoramento OpenSource  
**Data**: 2024
