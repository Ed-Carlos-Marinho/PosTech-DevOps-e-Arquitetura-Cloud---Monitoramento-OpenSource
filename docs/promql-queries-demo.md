# PromQL Queries - Demonstração com Node Exporter

Guia prático de queries PromQL para demonstração e monitoramento usando métricas do Node Exporter.

---

## 📊 MÉTRICAS DE CPU

### CPU Usage (Uso de CPU)

**⚠️ Por que usar `100 -` no início?**

O Node Exporter mede o tempo que a CPU passa em modo **"idle"** (ociosa/parada).
Para saber o **uso real** da CPU, precisamos inverter esse valor:

```
CPU Usage (uso) = 100% - CPU Idle (ociosa)

Exemplo:
- Se CPU está 80% idle (ociosa) → Uso real = 100 - 80 = 20%
- Se CPU está 10% idle (ociosa) → Uso real = 100 - 10 = 90%
```

**Queries:**
```promql
# Uso de CPU por modo (idle, system, user, etc.)
node_cpu_seconds_total

# Uso total de CPU (em %)
# Explicação: 100 - (% idle) = % em uso
100 - (avg by(instance) (irate(node_cpu_seconds_total{mode="idle"}[5m])) * 100)

# Uso de CPU por core
100 - (avg by(instance, cpu) (irate(node_cpu_seconds_total{mode="idle"}[5m])) * 100)

# Uso de CPU em modo user (aplicações)
irate(node_cpu_seconds_total{mode="user"}[5m]) * 100

# Uso de CPU em modo system (kernel)
irate(node_cpu_seconds_total{mode="system"}[5m]) * 100

# Uso de CPU em modo iowait (esperando I/O)
irate(node_cpu_seconds_total{mode="iowait"}[5m]) * 100

# Número de CPUs por instância
count(node_cpu_seconds_total{mode="idle"}) by (instance)

# Top 5 instâncias com maior uso de CPU
topk(5, 100 - (avg by(instance) (irate(node_cpu_seconds_total{mode="idle"}[5m])) * 100))
```

---

## 💾 MÉTRICAS DE MEMÓRIA

### Memory Usage (Uso de Memória)
```promql
# Memória total (em bytes)
node_memory_MemTotal_bytes

# Memória disponível (em bytes)
node_memory_MemAvailable_bytes

# Memória usada (em bytes)
node_memory_MemTotal_bytes - node_memory_MemAvailable_bytes

# Uso de memória (em %)
(node_memory_MemTotal_bytes - node_memory_MemAvailable_bytes) / node_memory_MemTotal_bytes * 100

# Memória livre (em %)
node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes * 100

# Memória em cache
node_memory_Cached_bytes

# Memória em buffer
node_memory_Buffers_bytes

# Memória usada por aplicações (excluindo cache/buffer)
node_memory_MemTotal_bytes - node_memory_MemFree_bytes - node_memory_Buffers_bytes - node_memory_Cached_bytes

# Swap total
node_memory_SwapTotal_bytes

# Swap usado
node_memory_SwapTotal_bytes - node_memory_SwapFree_bytes

# Uso de Swap (em %)
(node_memory_SwapTotal_bytes - node_memory_SwapFree_bytes) / node_memory_SwapTotal_bytes * 100
```

---

## 💿 MÉTRICAS DE DISCO

### Disk Space (Espaço em Disco)
```promql
# Espaço total em disco (em bytes)
node_filesystem_size_bytes{mountpoint="/"}

# Espaço disponível (em bytes)
node_filesystem_avail_bytes{mountpoint="/"}

# Espaço usado (em bytes)
node_filesystem_size_bytes{mountpoint="/"} - node_filesystem_avail_bytes{mountpoint="/"}

# Uso de disco (em %)
(node_filesystem_size_bytes{mountpoint="/"} - node_filesystem_avail_bytes{mountpoint="/"}) / node_filesystem_size_bytes{mountpoint="/"} * 100

# Espaço livre (em %)
node_filesystem_avail_bytes{mountpoint="/"} / node_filesystem_size_bytes{mountpoint="/"} * 100

# Todos os filesystems com uso acima de 80%
(node_filesystem_size_bytes - node_filesystem_avail_bytes) / node_filesystem_size_bytes * 100 > 80

# Espaço disponível em GB
node_filesystem_avail_bytes{mountpoint="/"} / 1024 / 1024 / 1024

# Inodes totais
node_filesystem_files{mountpoint="/"}

# Inodes livres
node_filesystem_files_free{mountpoint="/"}

# Uso de inodes (em %)
(node_filesystem_files{mountpoint="/"} - node_filesystem_files_free{mountpoint="/"}) / node_filesystem_files{mountpoint="/"} * 100
```

### Disk I/O (Entrada/Saída de Disco)
```promql
# Taxa de leitura do disco (bytes/s)
rate(node_disk_read_bytes_total[5m])

# Taxa de escrita do disco (bytes/s)
rate(node_disk_written_bytes_total[5m])

# Total de I/O (leitura + escrita) em MB/s
(rate(node_disk_read_bytes_total[5m]) + rate(node_disk_written_bytes_total[5m])) / 1024 / 1024

# Operações de leitura por segundo
rate(node_disk_reads_completed_total[5m])

# Operações de escrita por segundo
rate(node_disk_writes_completed_total[5m])

# Tempo médio de leitura (latência)
rate(node_disk_read_time_seconds_total[5m]) / rate(node_disk_reads_completed_total[5m])

# Tempo médio de escrita (latência)
rate(node_disk_write_time_seconds_total[5m]) / rate(node_disk_writes_completed_total[5m])

# I/O em progresso
node_disk_io_now
```

---

## 🌐 MÉTRICAS DE REDE

### Network Traffic (Tráfego de Rede)
```promql
# Taxa de recebimento (bytes/s)
rate(node_network_receive_bytes_total{device!="lo"}[5m])

# Taxa de transmissão (bytes/s)
rate(node_network_transmit_bytes_total{device!="lo"}[5m])

# Tráfego total (recebido + transmitido) em MB/s
(rate(node_network_receive_bytes_total{device!="lo"}[5m]) + rate(node_network_transmit_bytes_total{device!="lo"}[5m])) / 1024 / 1024

# Pacotes recebidos por segundo
rate(node_network_receive_packets_total{device!="lo"}[5m])

# Pacotes transmitidos por segundo
rate(node_network_transmit_packets_total{device!="lo"}[5m])

# Erros de recebimento
rate(node_network_receive_errs_total[5m])

# Erros de transmissão
rate(node_network_transmit_errs_total[5m])

# Pacotes descartados (dropped) no recebimento
rate(node_network_receive_drop_total[5m])

# Pacotes descartados (dropped) na transmissão
rate(node_network_transmit_drop_total[5m])

# Bandwidth total usado por interface
sum by(device, instance) (rate(node_network_receive_bytes_total[5m]) + rate(node_network_transmit_bytes_total[5m]))
```

---

## 🐳 MÉTRICAS DE CONTAINERS (CADVISOR)

### Container Discovery (Descoberta de Containers)
```promql
# Listar todos os containers descobertos
container_last_seen{name!=""}

# Listar apenas os NOMES dos containers (retorna 1 para cada)
count(container_last_seen{name!=""}) by (name)

# Listar nomes dos containers com uso de memória
count(container_memory_usage_bytes{name!=""}) by (name)

# Listar nomes com timestamp da última vez visto
max(container_last_seen{name!=""}) by (name)

# Contar total de containers únicos
count(count(container_last_seen{name!=""}) by (name))

# Listar containers por nome (regex)
container_last_seen{name=~"nginx.*"}

# Listar containers por imagem
container_last_seen{image=~"nginx.*"}

# Containers excluindo PODs do Kubernetes
container_last_seen{name!="", name!~"POD|k8s_.*"}
```

---

### Container CPU (CPU de Containers)
```promql
# Uso de CPU por container (em segundos/segundo)
rate(container_cpu_usage_seconds_total{name!=""}[5m])

# Uso de CPU por container (em %)
rate(container_cpu_usage_seconds_total{name!=""}[5m]) * 100

# Uso de CPU por container e core
rate(container_cpu_usage_seconds_total{name!="", cpu!=""}[5m]) * 100

# Top 5 containers por uso de CPU
topk(5, rate(container_cpu_usage_seconds_total{name!=""}[5m]) * 100)

# Bottom 5 containers por uso de CPU
bottomk(5, rate(container_cpu_usage_seconds_total{name!=""}[5m]) * 100)

# Uso médio de CPU de todos os containers
avg(rate(container_cpu_usage_seconds_total{name!=""}[5m]) * 100)

# Uso total de CPU de todos os containers
sum(rate(container_cpu_usage_seconds_total{name!=""}[5m]) * 100)

# CPU por container específico (ex: nginx)
rate(container_cpu_usage_seconds_total{name="nginx-test-app"}[5m]) * 100

# Containers com CPU acima de 50%
rate(container_cpu_usage_seconds_total{name!=""}[5m]) * 100 > 50

# Tempo de CPU em modo user
rate(container_cpu_user_seconds_total{name!=""}[5m])

# Tempo de CPU em modo system
rate(container_cpu_system_seconds_total{name!=""}[5m])
```

---

### Container Memory (Memória de Containers)
```promql
# Memória usada por container (em bytes)
container_memory_usage_bytes{name!=""}

# Memória usada por container (em MB)
container_memory_usage_bytes{name!=""} / 1024 / 1024

# Memória usada por container (em GB)
container_memory_usage_bytes{name!=""} / 1024 / 1024 / 1024

# Limite de memória por container
container_spec_memory_limit_bytes{name!=""}

# Uso de memória vs limite (em %)
(container_memory_usage_bytes{name!=""} / container_spec_memory_limit_bytes{name!=""}) * 100

# Top 5 containers por uso de memória
topk(5, container_memory_usage_bytes{name!=""})

# Containers usando mais de 80% do limite
(container_memory_usage_bytes{name!=""} / container_spec_memory_limit_bytes{name!=""}) * 100 > 80

# Memória working set (memória ativa)
container_memory_working_set_bytes{name!=""}

# Memória em cache
container_memory_cache{name!=""}

# Memória RSS (Resident Set Size)
container_memory_rss{name!=""}

# Memória swap usada
container_memory_swap{name!=""}

# Page faults (falhas de página)
rate(container_memory_failures_total{name!=""}[5m])

# Uso total de memória de todos os containers
sum(container_memory_usage_bytes{name!=""})

# Uso médio de memória
avg(container_memory_usage_bytes{name!=""})
```

---

### Container Network (Rede de Containers)
```promql
# Taxa de recebimento (bytes/s)
rate(container_network_receive_bytes_total{name!=""}[5m])

# Taxa de transmissão (bytes/s)
rate(container_network_transmit_bytes_total{name!=""}[5m])

# Tráfego total (recebido + transmitido) em bytes/s
rate(container_network_receive_bytes_total{name!=""}[5m]) + rate(container_network_transmit_bytes_total{name!=""}[5m])

# Tráfego total em MB/s
(rate(container_network_receive_bytes_total{name!=""}[5m]) + rate(container_network_transmit_bytes_total{name!=""}[5m])) / 1024 / 1024

# Pacotes recebidos por segundo
rate(container_network_receive_packets_total{name!=""}[5m])

# Pacotes transmitidos por segundo
rate(container_network_transmit_packets_total{name!=""}[5m])

# Erros de recebimento
rate(container_network_receive_errors_total{name!=""}[5m])

# Erros de transmissão
rate(container_network_transmit_errors_total{name!=""}[5m])

# Pacotes descartados no recebimento
rate(container_network_receive_packets_dropped_total{name!=""}[5m])

# Pacotes descartados na transmissão
rate(container_network_transmit_packets_dropped_total{name!=""}[5m])

# Top 5 containers por tráfego de rede
topk(5, rate(container_network_receive_bytes_total{name!=""}[5m]) + rate(container_network_transmit_bytes_total{name!=""}[5m]))

# Tráfego por interface de rede
sum by(name, interface) (rate(container_network_receive_bytes_total{name!=""}[5m]))

# Total de erros de rede
sum(rate(container_network_receive_errors_total{name!=""}[5m]) + rate(container_network_transmit_errors_total{name!=""}[5m]))
```

---

### Container Filesystem (Sistema de Arquivos)
```promql
# Espaço usado no filesystem (em bytes)
container_fs_usage_bytes{name!=""}

# Espaço usado no filesystem (em GB)
container_fs_usage_bytes{name!=""} / 1024 / 1024 / 1024

# Limite do filesystem
container_fs_limit_bytes{name!=""}

# Uso do filesystem (em %)
(container_fs_usage_bytes{name!=""} / container_fs_limit_bytes{name!=""}) * 100

# Taxa de leitura (bytes/s)
rate(container_fs_reads_bytes_total{name!=""}[5m])

# Taxa de escrita (bytes/s)
rate(container_fs_writes_bytes_total{name!=""}[5m])

# I/O total (leitura + escrita) em MB/s
(rate(container_fs_reads_bytes_total{name!=""}[5m]) + rate(container_fs_writes_bytes_total{name!=""}[5m])) / 1024 / 1024

# Operações de leitura por segundo
rate(container_fs_reads_total{name!=""}[5m])

# Operações de escrita por segundo
rate(container_fs_writes_total{name!=""}[5m])

# Tempo de I/O (latência)
rate(container_fs_io_time_seconds_total{name!=""}[5m])

# Top 5 containers por I/O de disco
topk(5, rate(container_fs_reads_bytes_total{name!=""}[5m]) + rate(container_fs_writes_bytes_total{name!=""}[5m]))

# Inodes usados
container_fs_inodes_total{name!=""} - container_fs_inodes_free{name!=""}

# Uso de inodes (em %)
((container_fs_inodes_total{name!=""} - container_fs_inodes_free{name!=""}) / container_fs_inodes_total{name!=""}) * 100
```

---

### Container Status (Status de Containers)
```promql
# Última vez que o container foi visto (timestamp)
container_last_seen{name!=""}

# Containers que não foram vistos nos últimos 60 segundos (possivelmente down)
time() - container_last_seen{name!=""} > 60

# Tempo desde o último restart
time() - container_start_time_seconds{name!=""}

# Uptime do container em horas
(time() - container_start_time_seconds{name!=""}) / 3600

# Uptime do container em dias
(time() - container_start_time_seconds{name!=""}) / 86400

# Containers reiniciados recentemente (últimos 5 minutos)
changes(container_last_seen{name!=""}[5m]) > 0

# Número de restarts por container
container_start_time_seconds{name!=""} - container_start_time_seconds{name!=""} offset 1h
```

---

### Container Resources (Recursos de Containers)
```promql
# Limite de CPU por container (em cores)
container_spec_cpu_quota{name!=""} / container_spec_cpu_period{name!=""}

# Limite de memória por container (em GB)
container_spec_memory_limit_bytes{name!=""} / 1024 / 1024 / 1024

# Reserva de memória por container
container_spec_memory_reservation_limit_bytes{name!=""}

# Número de CPUs disponíveis para o container
container_spec_cpu_shares{name!=""}

# Containers sem limite de memória definido
container_spec_memory_limit_bytes{name!=""} == 0

# Containers sem limite de CPU definido
container_spec_cpu_quota{name!=""} == -1
```

---

### Container Comparisons (Comparações entre Containers)
```promql
# Comparar uso de CPU entre containers
rate(container_cpu_usage_seconds_total{name="nginx-test-app"}[5m]) 
/ 
rate(container_cpu_usage_seconds_total{name="redis-test-app"}[5m])

# Diferença de memória entre containers
container_memory_usage_bytes{name="postgres-test-app"} 
- 
container_memory_usage_bytes{name="redis-test-app"}

# Ratio de uso de memória vs limite
avg by(name) (container_memory_usage_bytes{name!=""} / container_spec_memory_limit_bytes{name!=""})

# Containers ordenados por uso de recursos (CPU + Memória)
(rate(container_cpu_usage_seconds_total{name!=""}[5m]) * 100) 
+ 
((container_memory_usage_bytes{name!=""} / container_spec_memory_limit_bytes{name!=""}) * 100)
```

---

### Container Aggregations (Agregações)
```promql
# Total de CPU usado por todos os containers
sum(rate(container_cpu_usage_seconds_total{name!=""}[5m]) * 100)

# Total de memória usada por todos os containers (em GB)
sum(container_memory_usage_bytes{name!=""}) / 1024 / 1024 / 1024

# Média de uso de CPU por container
avg(rate(container_cpu_usage_seconds_total{name!=""}[5m]) * 100)

# Média de uso de memória por container (em MB)
avg(container_memory_usage_bytes{name!=""}) / 1024 / 1024

# Contar containers por imagem
count by(image) (container_last_seen{name!=""})

# Contar containers por host
count by(instance) (container_last_seen{name!=""})

# Uso total de rede de todos os containers (MB/s)
sum(rate(container_network_receive_bytes_total{name!=""}[5m]) + rate(container_network_transmit_bytes_total{name!=""}[5m])) / 1024 / 1024

# Uso total de I/O de disco de todos os containers (MB/s)
sum(rate(container_fs_reads_bytes_total{name!=""}[5m]) + rate(container_fs_writes_bytes_total{name!=""}[5m])) / 1024 / 1024
```

---

### Container Filtering (Filtragem de Containers)
```promql
# Apenas containers de aplicação (excluir sistema)
container_memory_usage_bytes{name!="", name!~"cadvisor|prometheus|alertmanager"}

# Containers por tipo de aplicação (usando labels)
container_memory_usage_bytes{name!="", image=~"nginx.*"}

# Containers em um host específico
container_memory_usage_bytes{name!="", instance="10.0.1.10:8080"}

# Containers com nome contendo "test"
container_memory_usage_bytes{name=~".*test.*"}

# Containers excluindo PODs e pausados
container_memory_usage_bytes{name!="", name!~"POD|k8s_POD.*"}

# Múltiplos containers específicos
container_memory_usage_bytes{name=~"nginx-test-app|redis-test-app|postgres-test-app"}
```

---

## ⚙️ MÉTRICAS DE SISTEMA

### Load Average (Carga do Sistema)
```promql
# Load average 1 minuto
node_load1

# Load average 5 minutos
node_load5

# Load average 15 minutos
node_load15

# Load average normalizado por número de CPUs
node_load1 / count(node_cpu_seconds_total{mode="idle"}) by (instance)

# Load average 5min normalizado
node_load5 / count(node_cpu_seconds_total{mode="idle"}) by (instance)
```

### Uptime (Tempo de Atividade)
```promql
# Uptime em segundos
node_time_seconds - node_boot_time_seconds

# Uptime em dias
(node_time_seconds - node_boot_time_seconds) / 86400

# Uptime em horas
(node_time_seconds - node_boot_time_seconds) / 3600
```

### Processos
```promql
# Número total de processos
node_procs_running + node_procs_blocked

# Processos em execução
node_procs_running

# Processos bloqueados
node_procs_blocked

# Processos zumbis
node_processes_state{state="zombie"}

# Forks por segundo
rate(node_forks_total[5m])

# Context switches por segundo
rate(node_context_switches_total[5m])
```

---

## 🎯 QUERIES PARA CONTAINERS DE TESTE

### Monitorando os Containers do docker-compose-cadvisor-test.yml

```promql
# Status de todos os containers de teste
container_last_seen{name=~"nginx-test-app|redis-test-app|postgres-test-app|stress-test-app|busybox-test-app"}

# CPU do Stress Test (deve estar alto)
rate(container_cpu_usage_seconds_total{name="stress-test-app"}[5m]) * 100

# Memória do Stress Test (deve estar alto)
container_memory_usage_bytes{name="stress-test-app"} / 1024 / 1024

# Comparar uso de recursos entre apps
sum by(name) (rate(container_cpu_usage_seconds_total{name=~".*-test-app"}[5m]) * 100)

# Tráfego de rede do NGINX
rate(container_network_receive_bytes_total{name="nginx-test-app"}[5m]) + rate(container_network_transmit_bytes_total{name="nginx-test-app"}[5m])

# Memória do Postgres vs Redis
container_memory_usage_bytes{name=~"postgres-test-app|redis-test-app"}

# Uso de CPU de todos os containers de teste
rate(container_cpu_usage_seconds_total{name=~".*-test-app"}[5m]) * 100

# Uso de memória vs limite dos containers de teste
(container_memory_usage_bytes{name=~".*-test-app"} / container_spec_memory_limit_bytes{name=~".*-test-app"}) * 100

# Container mais leve (Busybox)
container_memory_usage_bytes{name="busybox-test-app"} / 1024 / 1024

# Total de recursos usados pelos containers de teste
sum(container_memory_usage_bytes{name=~".*-test-app"}) / 1024 / 1024 / 1024
```

---

## 🔥 QUERIES AVANÇADAS

### Agregações e Comparações
```promql
# Média de uso de CPU de todas as instâncias
avg(100 - (avg by(instance) (irate(node_cpu_seconds_total{mode="idle"}[5m])) * 100))

# Soma total de memória de todas as instâncias (em GB)
sum(node_memory_MemTotal_bytes) / 1024 / 1024 / 1024

# Instância com maior uso de memória
max by(instance) ((node_memory_MemTotal_bytes - node_memory_MemAvailable_bytes) / node_memory_MemTotal_bytes * 100)

# Instância com menor espaço em disco disponível
min by(instance) (node_filesystem_avail_bytes{mountpoint="/"} / node_filesystem_size_bytes{mountpoint="/"} * 100)

# Contagem de instâncias com CPU acima de 80%
count(100 - (avg by(instance) (irate(node_cpu_seconds_total{mode="idle"}[5m])) * 100) > 80)

# Percentil 95 de uso de CPU
quantile(0.95, 100 - (avg by(instance) (irate(node_cpu_seconds_total{mode="idle"}[5m])) * 100))
```

### Previsões e Tendências
```promql
# Previsão de quando o disco ficará cheio (em segundos)
predict_linear(node_filesystem_avail_bytes{mountpoint="/"}[1h], 4 * 3600)

# Taxa de crescimento de uso de disco (bytes/s)
deriv(node_filesystem_avail_bytes{mountpoint="/"}[1h])

# Previsão de uso de memória nas próximas 4 horas
predict_linear(node_memory_MemAvailable_bytes[1h], 4 * 3600)
```

### Comparações Temporais
```promql
# Uso de CPU atual vs 1 hora atrás
100 - (avg by(instance) (irate(node_cpu_seconds_total{mode="idle"}[5m])) * 100)
- 
(100 - (avg by(instance) (irate(node_cpu_seconds_total{mode="idle"}[5m] offset 1h)) * 100))

# Tráfego de rede atual vs 1 dia atrás
rate(node_network_receive_bytes_total[5m]) 
- 
rate(node_network_receive_bytes_total[5m] offset 1d)

# Aumento de uso de disco nas últimas 24 horas
node_filesystem_avail_bytes{mountpoint="/"} offset 24h 
- 
node_filesystem_avail_bytes{mountpoint="/"}
```

### Alertas Compostos
```promql
# CPU alta E memória alta
(100 - (avg by(instance) (irate(node_cpu_seconds_total{mode="idle"}[5m])) * 100) > 80)
and
((node_memory_MemTotal_bytes - node_memory_MemAvailable_bytes) / node_memory_MemTotal_bytes * 100 > 85)

# Disco cheio OU inodes esgotados
(node_filesystem_avail_bytes{mountpoint="/"} / node_filesystem_size_bytes{mountpoint="/"} * 100 < 20)
or
((node_filesystem_files{mountpoint="/"} - node_filesystem_files_free{mountpoint="/"}) / node_filesystem_files{mountpoint="/"} * 100 > 90)

# Instâncias com problemas múltiplos
count by(instance) (
  (100 - (avg by(instance) (irate(node_cpu_seconds_total{mode="idle"}[5m])) * 100) > 80)
  or
  ((node_memory_MemTotal_bytes - node_memory_MemAvailable_bytes) / node_memory_MemTotal_bytes * 100 > 85)
  or
  (node_filesystem_avail_bytes{mountpoint="/"} / node_filesystem_size_bytes{mountpoint="/"} * 100 < 20)
) > 1
```

---

## 📈 QUERIES PARA DASHBOARDS

### Overview Geral
```promql
# Total de instâncias monitoradas
count(up{job="node-exporter"})

# Instâncias online
count(up{job="node-exporter"} == 1)

# Instâncias offline
count(up{job="node-exporter"} == 0)

# Uso médio de CPU do cluster
avg(100 - (avg by(instance) (irate(node_cpu_seconds_total{mode="idle"}[5m])) * 100))

# Uso médio de memória do cluster
avg((node_memory_MemTotal_bytes - node_memory_MemAvailable_bytes) / node_memory_MemTotal_bytes * 100)

# Uso médio de disco do cluster
avg((node_filesystem_size_bytes{mountpoint="/"} - node_filesystem_avail_bytes{mountpoint="/"}) / node_filesystem_size_bytes{mountpoint="/"} * 100)
```

### Top N Resources
```promql
# Top 5 instâncias por uso de CPU
topk(5, 100 - (avg by(instance) (irate(node_cpu_seconds_total{mode="idle"}[5m])) * 100))

# Top 5 instâncias por uso de memória
topk(5, (node_memory_MemTotal_bytes - node_memory_MemAvailable_bytes) / node_memory_MemTotal_bytes * 100)

# Top 5 instâncias por uso de disco
topk(5, (node_filesystem_size_bytes{mountpoint="/"} - node_filesystem_avail_bytes{mountpoint="/"}) / node_filesystem_size_bytes{mountpoint="/"} * 100)

# Top 5 instâncias por tráfego de rede
topk(5, rate(node_network_receive_bytes_total{device!="lo"}[5m]) + rate(node_network_transmit_bytes_total{device!="lo"}[5m]))

# Bottom 5 instâncias por espaço livre em disco
bottomk(5, node_filesystem_avail_bytes{mountpoint="/"})
```

### Heatmaps e Histogramas
```promql
# Distribuição de uso de CPU
histogram_quantile(0.50, sum(rate(node_cpu_seconds_total[5m])) by (le, instance))
histogram_quantile(0.90, sum(rate(node_cpu_seconds_total[5m])) by (le, instance))
histogram_quantile(0.99, sum(rate(node_cpu_seconds_total[5m])) by (le, instance))
```

---

## 🎯 QUERIES PARA TROUBLESHOOTING

### Diagnóstico de Performance
```promql
# Instâncias com alta latência de disco
rate(node_disk_read_time_seconds_total[5m]) / rate(node_disk_reads_completed_total[5m]) > 0.1

# Instâncias com muitos erros de rede
rate(node_network_receive_errs_total[5m]) + rate(node_network_transmit_errs_total[5m]) > 10

# Instâncias com swap alto (possível falta de memória)
(node_memory_SwapTotal_bytes - node_memory_SwapFree_bytes) / node_memory_SwapTotal_bytes * 100 > 50

# Instâncias com load average alto
node_load5 / count(node_cpu_seconds_total{mode="idle"}) by (instance) > 2

# Instâncias com muitos processos zumbis
node_processes_state{state="zombie"} > 5
```

### Capacidade e Planejamento
```promql
# Dias até o disco ficar cheio (assumindo crescimento linear)
predict_linear(node_filesystem_avail_bytes{mountpoint="/"}[7d], 86400) / 
(rate(node_filesystem_avail_bytes{mountpoint="/"}[7d]) * -1)

# Taxa de crescimento de uso de memória (últimas 24h)
(node_memory_MemTotal_bytes - node_memory_MemAvailable_bytes) - 
(node_memory_MemTotal_bytes - node_memory_MemAvailable_bytes offset 24h)

# Capacidade restante de CPU (%)
100 - avg(100 - (avg by(instance) (irate(node_cpu_seconds_total{mode="idle"}[5m])) * 100))
```

---

## 💡 DICAS E BOAS PRÁTICAS

### Entendendo irate() e avg by()

#### 📈 irate() - Instant Rate

**O que faz:**
Calcula a taxa de mudança instantânea por segundo de um counter (métrica que sempre cresce).

**Como funciona:**
- Pega os **2 últimos pontos** de dados no intervalo especificado
- Calcula a diferença entre eles
- Divide pelo tempo decorrido
- Resultado: taxa por segundo

**Sintaxe:**
```promql
irate(metric_name[time_range])
```

**Exemplo prático:**
```promql
# CPU idle nos últimos 5 minutos
irate(node_cpu_seconds_total{mode="idle"}[5m])

# Como funciona:
# Ponto 1: 1000 segundos (em t=0)
# Ponto 2: 1015 segundos (em t=15s)
# irate = (1015 - 1000) / 15 = 1.0 segundo por segundo
```

**Quando usar irate():**
- ✅ Para detectar picos e mudanças rápidas
- ✅ Para alertas que precisam reagir rapidamente
- ✅ Para gráficos em tempo real
- ✅ Para métricas que mudam rapidamente

**Quando NÃO usar irate():**
- ❌ Para médias de longo prazo (use `rate()`)
- ❌ Para dados históricos (use `rate()`)
- ❌ Para cálculos de tendência (use `rate()`)

**irate() vs rate():**
```promql
# irate - Usa apenas os 2 últimos pontos (mais sensível a picos)
irate(node_cpu_seconds_total{mode="idle"}[5m])

# rate - Usa todos os pontos no intervalo (mais suave)
rate(node_cpu_seconds_total{mode="idle"}[5m])
```

**Visualização da diferença:**
```
Dados: [10, 12, 14, 50, 52]  (último valor é um pico)

rate():  Média de todos os pontos = ~20
irate(): Apenas (52-50) = 2 (não captura o pico anterior)
```

---

#### 📊 avg by() - Average By Labels

**O que faz:**
Calcula a média de múltiplas séries temporais, agrupando por labels específicos.

**Como funciona:**
- Agrupa séries temporais que têm os mesmos valores nos labels especificados
- Calcula a média de cada grupo
- Retorna uma série temporal por grupo

**Sintaxe:**
```promql
avg by(label1, label2, ...) (metric_expression)
# ou
avg(metric_expression) by (label1, label2, ...)
```

**Exemplo prático:**

**Cenário:** Você tem 4 CPUs em cada instância

```promql
# Sem agregação - retorna 4 séries (uma por CPU)
node_cpu_seconds_total{mode="idle", instance="server1"}
# Resultado:
# {cpu="0", instance="server1"} = 1000
# {cpu="1", instance="server1"} = 1020
# {cpu="2", instance="server1"} = 980
# {cpu="3", instance="server1"} = 1000

# Com avg by(instance) - retorna 1 série (média das 4 CPUs)
avg by(instance) (node_cpu_seconds_total{mode="idle"})
# Resultado:
# {instance="server1"} = 1000  (média de 1000+1020+980+1000 / 4)
```

**Exemplo completo de uso de CPU:**
```promql
# Passo 1: Calcular taxa instantânea de CPU idle por core
irate(node_cpu_seconds_total{mode="idle"}[5m])
# Retorna: 4 séries (uma por CPU core)

# Passo 2: Calcular média de todos os cores por instância
avg by(instance) (irate(node_cpu_seconds_total{mode="idle"}[5m]))
# Retorna: 1 série por instância (média de todos os cores)

# Passo 3: Converter para porcentagem de uso (não idle)
100 - (avg by(instance) (irate(node_cpu_seconds_total{mode="idle"}[5m])) * 100)
# Retorna: % de CPU em uso por instância
```

**Outros agregadores:**
```promql
# Soma total (ex: memória total de todas as instâncias)
sum by(datacenter) (node_memory_MemTotal_bytes)

# Valor mínimo (ex: menor espaço em disco)
min by(environment) (node_filesystem_avail_bytes)

# Valor máximo (ex: maior uso de CPU)
max by(team) (node_cpu_usage)

# Contagem (ex: quantas instâncias por região)
count by(region) (up)
```

**avg without() - O inverso:**
```promql
# avg by(instance) - mantém apenas o label 'instance'
avg by(instance) (node_cpu_seconds_total{mode="idle"})

# avg without(cpu) - remove o label 'cpu', mantém todos os outros
avg without(cpu) (node_cpu_seconds_total{mode="idle"})
```

---

#### 🎯 Exemplo Completo Explicado

**Query de uso de CPU:**
```promql
100 - (avg by(instance) (irate(node_cpu_seconds_total{mode="idle"}[5m])) * 100)
```

**Passo a passo:**

1. **`node_cpu_seconds_total{mode="idle"}[5m]`**
   - Pega os dados de CPU idle dos últimos 5 minutos
   - Retorna múltiplas séries (uma por CPU core)

2. **`irate(...[5m])`**
   - Calcula taxa instantânea (segundos por segundo)
   - Ainda retorna múltiplas séries (uma por core)
   - Valor entre 0 e 1 (ex: 0.95 = 95% idle)

3. **`avg by(instance) (...)`**
   - Agrupa por instância
   - Calcula média de todos os cores
   - Retorna 1 série por instância
   - Valor entre 0 e 1 (ex: 0.92 = média de 92% idle)

4. **`... * 100`**
   - Converte para porcentagem
   - Valor entre 0 e 100 (ex: 92 = 92% idle)

5. **`100 - ...`**
   - Inverte para mostrar uso (não idle)
   - Valor entre 0 e 100 (ex: 8 = 8% de uso)

**Resultado final:**
```
{instance="10.0.1.10:9100"} = 8.5   (8.5% de CPU em uso)
{instance="10.0.1.11:9100"} = 45.2  (45.2% de CPU em uso)
{instance="10.0.1.12:9100"} = 92.7  (92.7% de CPU em uso)
```

---

#### 🔬 Comparação Visual

**Sem agregação:**
```promql
irate(node_cpu_seconds_total{mode="idle"}[5m])

Resultado (4 cores):
{instance="server1", cpu="0"} = 0.95
{instance="server1", cpu="1"} = 0.93
{instance="server1", cpu="2"} = 0.90
{instance="server1", cpu="3"} = 0.92
```

**Com avg by(instance):**
```promql
avg by(instance) (irate(node_cpu_seconds_total{mode="idle"}[5m]))

Resultado (1 série):
{instance="server1"} = 0.925  (média de 0.95+0.93+0.90+0.92 / 4)
```

**Com avg by(instance, mode):**
```promql
avg by(instance, mode) (irate(node_cpu_seconds_total[5m]))

Resultado (múltiplas séries por modo):
{instance="server1", mode="idle"}   = 0.925
{instance="server1", mode="user"}   = 0.050
{instance="server1", mode="system"} = 0.025
```

---

### Funções Úteis
- `rate()` - Para counters (sempre crescentes)
- `irate()` - Para mudanças instantâneas (mais sensível)
- `increase()` - Aumento total no período
- `avg()`, `sum()`, `min()`, `max()` - Agregações
- `topk()`, `bottomk()` - Top/Bottom N valores
- `count()` - Contagem de séries
- `predict_linear()` - Previsões lineares
- `histogram_quantile()` - Percentis

### Intervalos de Tempo
- `[5m]` - Últimos 5 minutos
- `[1h]` - Última hora
- `[1d]` - Último dia
- `[7d]` - Última semana

### Modificadores
- `offset 1h` - Dados de 1 hora atrás
- `by (label)` - Agrupa por label
- `without (label)` - Agrupa removendo label

### Operadores
- Aritméticos: `+`, `-`, `*`, `/`, `%`, `^`
- Comparação: `==`, `!=`, `>`, `<`, `>=`, `<=`
- Lógicos: `and`, `or`, `unless`
- Agregação: `sum`, `avg`, `min`, `max`, `count`

---

## 🚀 TESTANDO AS QUERIES

### No Prometheus UI
1. Acesse: `http://localhost:9090`
2. Vá para a aba **Graph**
3. Cole a query no campo de texto
4. Clique em **Execute**
5. Escolha entre **Table** ou **Graph** para visualizar

### Via API
```bash
# Query simples
curl 'http://localhost:9090/api/v1/query?query=up'

# Query com range
curl 'http://localhost:9090/api/v1/query_range?query=node_cpu_seconds_total&start=2024-01-01T00:00:00Z&end=2024-01-01T01:00:00Z&step=15s'
```

### Validação de Queries
```bash
# Validar sintaxe
docker-compose exec prometheus promtool query instant http://localhost:9090 'up'

# Testar query com range
docker-compose exec prometheus promtool query range http://localhost:9090 'node_cpu_seconds_total' --start=1h --end=now
```

---

## 📚 RECURSOS ADICIONAIS

- **Documentação Oficial**: https://prometheus.io/docs/prometheus/latest/querying/basics/
- **PromQL Cheat Sheet**: https://promlabs.com/promql-cheat-sheet/
- **Query Examples**: https://prometheus.io/docs/prometheus/latest/querying/examples/
- **Node Exporter Metrics**: https://github.com/prometheus/node_exporter#enabled-by-default

---

**Autor**: PosTech DevOps e Arquitetura Cloud  
**Aula**: 02 - Monitoramento OpenSource  
**Data**: 2024
