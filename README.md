# Aula 02 - PosTech DevOps e Arquitetura Cloud

Este repositório contém os materiais da **Aula 02** do módulo **Monitoramento OpenSource** da PosTech DevOps e Arquitetura Cloud.

## 📋 Conteúdo da Branch aula-02

### 1. Scripts de User Data EC2
- `ec2-userdata-instance-01.sh` - Script para Instância 1 (Prometheus Server)
- `ec2-userdata-instance-02.sh` - Script para Instância 2 (Docker + Docker Compose)

Scripts automatizados para configuração de instâncias EC2 Ubuntu:
- **Instância 1**: Docker, Docker Compose e code-server
- **Instância 2**: Docker, Docker Compose (para exporters e aplicações de teste)

### 2. Docker Compose Files
- `docker-compose.yml` - Stack Prometheus + Alertmanager
- `docker-compose-cadvisor-test.yml` - cAdvisor + Aplicações de teste

### 3. Arquivos de Configuração
- `prometheus.yml` - Configuração do Prometheus (com exemplos comentados)
- `alertmanager.yml` - Configuração do Alertmanager (com múltiplos receivers)
- `alert_rules.yml` - Regras de alertas (sistema + containers)

### 4. Documentação Completa
- `docs/setup-ec2-instances.md` - Guia de setup das instâncias EC2
- `docs/exporters-installation.md` - Instalação de Node Exporter e cAdvisor
- `docs/prometheus-compose.md` - Guia do Docker Compose
- `docs/ec2-userdata.md` - Guia dos scripts de user data
- `docs/promql-queries-demo.md` - Queries PromQL para demonstração
- `docs/service-discovery.md` - Configuração de Service Discovery

## 🏗️ Estrutura do Projeto

```
├── README.md                              # Documentação principal
├── docker-compose.yml                     # Stack Prometheus + Alertmanager
├── docker-compose-cadvisor-test.yml       # cAdvisor + Apps de teste
├── prometheus.yml                         # Configuração do Prometheus
├── alertmanager.yml                       # Configuração do Alertmanager
├── alert_rules.yml                        # Regras de alertas
├── ec2-userdata-instance-01.sh            # Script para Instância 1
├── ec2-userdata-instance-02.sh            # Script para Instância 2
└── docs/                                  # Documentação detalhada
    ├── setup-ec2-instances.md             # Setup das instâncias
    ├── exporters-installation.md          # Instalação dos exporters
    ├── prometheus-compose.md              # Guia do Docker Compose
    ├── ec2-userdata.md                    # Guia dos scripts
    ├── promql-queries-demo.md             # Queries PromQL
    └── service-discovery.md               # Service Discovery
```

## 🎯 Objetivo da Aula

Aprender a configurar e utilizar o Prometheus para coleta de métricas em sistemas dinâmicos, entendendo conceitos de scraping, exporters e alert rules para monitoramento moderno.

## 📚 Teoria Abordada

- **Monitoramento de sistemas dinâmicos e efêmeros**: Containers, microserviços e infraestrutura como código
- **Modelo de coleta pull**: Como o Prometheus coleta métricas ativamente dos targets
- **Exporters**: Componentes que expõem métricas de sistemas e aplicações
- **Séries temporais**: Estrutura de dados para armazenamento de métricas ao longo do tempo
- **Consultas com PromQL**: Linguagem de consulta do Prometheus para análise de dados
- **Funcionamento do Alertmanager**: Gerenciamento e roteamento de alertas baseados em regras
- **Service Discovery**: Descoberta automática de targets em ambientes dinâmicos
- **Container Monitoring**: Monitoramento de containers com cAdvisor

## 🚀 Quick Start

### Pré-requisitos
- Conta AWS com permissões para criar instâncias EC2
- Git instalado
- Conhecimento básico de Docker e Docker Compose

### Passo 1: Criar Instâncias EC2

1. **Instância 1 (Prometheus Server)**:
   - AMI: Ubuntu 22.04 LTS
   - Tipo: t3.medium (mínimo)
   - User Data: Conteúdo do arquivo `ec2-userdata-instance-01.sh`
   - Security Group: Portas 9090 (Prometheus), 9093 (Alertmanager), 8443 (code-server)

2. **Instância 2 (Exporters)**:
   - AMI: Ubuntu 22.04 LTS
   - Tipo: t3.small (mínimo)
   - User Data: Conteúdo do arquivo `ec2-userdata-instance-02.sh`
   - Security Group: Portas 9100 (Node Exporter), 8080 (cAdvisor)

### Passo 2: Configurar Prometheus Server (Instância 1)

```bash
# Conectar via SSM ou SSH
aws ssm start-session --target i-xxxxxxxxx

# Clonar o repositório
git clone <URL_DO_REPOSITORIO>
cd <nome-do-repositorio>
git checkout aula-02

# Subir stack do Prometheus
docker-compose up -d

# Verificar containers
docker-compose ps

# Acessar Prometheus: http://IP_INSTANCIA_1:9090
# Acessar Alertmanager: http://IP_INSTANCIA_1:9093
```

### Passo 3: Configurar Exporters (Instância 2)

```bash
# Conectar via SSM ou SSH
aws ssm start-session --target i-xxxxxxxxx

# Clonar o repositório
git clone <URL_DO_REPOSITORIO>
cd <nome-do-repositorio>
git checkout aula-02

# Instalar Node Exporter (seguir docs/exporters-installation.md)
# Instalar cAdvisor + Apps de teste
docker-compose -f docker-compose-cadvisor-test.yml up -d

# Verificar containers
docker-compose -f docker-compose-cadvisor-test.yml ps

# Acessar cAdvisor: http://IP_INSTANCIA_2:8080
```

### Passo 4: Configurar Targets no Prometheus

Editar `prometheus.yml` na Instância 1:

```yaml
scrape_configs:
  - job_name: 'prometheus'
    static_configs:
      - targets: ['localhost:9090']

  - job_name: 'node-exporter'
    static_configs:
      - targets: ['IP_INSTANCIA_2:9100']

  - job_name: 'cadvisor'
    static_configs:
      - targets: ['IP_INSTANCIA_2:8080']
```

Recarregar configuração:
```bash
curl -X POST http://localhost:9090/-/reload
```

## 📊 Componentes do Sistema

### Prometheus Server (Instância 1)
- **Prometheus**: Coleta e armazena métricas
- **Alertmanager**: Gerencia e roteia alertas
- **Porta 9090**: Interface web do Prometheus
- **Porta 9093**: Interface web do Alertmanager

### Exporters (Instância 2)
- **Node Exporter**: Métricas do sistema operacional (CPU, memória, disco, rede)
- **cAdvisor**: Métricas de containers Docker
- **Porta 9100**: Node Exporter
- **Porta 8080**: cAdvisor

### Aplicações de Teste (Instância 2)
- **NGINX** (porta 8081): Web server
- **Redis** (porta 6379): Cache/Database
- **Postgres** (porta 5432): Database
- **Stress Test**: Gera carga de CPU/memória
- **Busybox**: Container leve

## 🔍 Queries PromQL Úteis

### Métricas de Sistema (Node Exporter)
```promql
# Uso de CPU (%)
100 - (avg by(instance) (irate(node_cpu_seconds_total{mode="idle"}[5m])) * 100)

# Uso de memória (%)
(node_memory_MemTotal_bytes - node_memory_MemAvailable_bytes) / node_memory_MemTotal_bytes * 100

# Uso de disco (%)
(node_filesystem_size_bytes{mountpoint="/"} - node_filesystem_avail_bytes{mountpoint="/"}) / node_filesystem_size_bytes{mountpoint="/"} * 100
```

### Métricas de Containers (cAdvisor)
```promql
# Listar containers
count(container_last_seen{name!=""}) by (name)

# CPU por container (%)
rate(container_cpu_usage_seconds_total{name!=""}[5m]) * 100

# Memória por container
container_memory_usage_bytes{name!=""}

# Top 5 containers por CPU
topk(5, rate(container_cpu_usage_seconds_total{name!=""}[5m]) * 100)
```

Veja mais queries em: `docs/promql-queries-demo.md`

## 🚨 Alertas Configurados

### Alertas de Sistema
- **HighCPUUsage**: CPU > 80% por 2 minutos
- **HighMemoryUsage**: Memória > 85% por 2 minutos
- **DiskSpaceLow**: Disco < 20% por 1 minuto
- **ServiceDown**: Target down por 1 minuto

### Alertas de Containers
- **ContainerHighCPU**: CPU > 50% por 2 minutos
- **ContainerCriticalCPU**: CPU > 80% por 5 minutos
- **ContainerHighMemory**: Memória > 80% do limite por 5 minutos
- **ContainerDown**: Container não visto há mais de 60 segundos
- **StressTestHighCPU**: Stress test > 30% CPU (para testes)

## 🧪 Testando Alertas

```bash
# Iniciar stress test para gerar carga
docker-compose -f docker-compose-cadvisor-test.yml start stress-test

# Monitorar uso de recursos
docker stats stress-test-app

# Verificar alertas no Prometheus
# http://IP_INSTANCIA_1:9090/alerts

# Verificar alertas no Alertmanager (quando dispararem)
# http://IP_INSTANCIA_1:9093
```

## 📖 Documentação Detalhada

- **[Setup EC2 Instances](docs/setup-ec2-instances.md)**: Guia completo de criação das instâncias
- **[Exporters Installation](docs/exporters-installation.md)**: Instalação de Node Exporter e cAdvisor
- **[Prometheus Compose](docs/prometheus-compose.md)**: Guia do Docker Compose
- **[PromQL Queries Demo](docs/promql-queries-demo.md)**: Queries PromQL para demonstração
- **[Service Discovery](docs/service-discovery.md)**: Configuração de Service Discovery

## 🛠️ Comandos Úteis

### Prometheus
```bash
# Validar configuração
docker-compose exec prometheus promtool check config /etc/prometheus/prometheus.yml

# Validar regras de alerta
docker-compose exec prometheus promtool check rules /etc/prometheus/alert_rules.yml

# Recarregar configuração
curl -X POST http://localhost:9090/-/reload

# Ver logs
docker-compose logs -f prometheus
```

### Alertmanager
```bash
# Validar configuração
docker-compose exec alertmanager amtool check-config /etc/alertmanager/alertmanager.yml

# Ver logs
docker-compose logs -f alertmanager

# Reiniciar
docker-compose restart alertmanager
```

### cAdvisor e Apps de Teste
```bash
# Ver status
docker-compose -f docker-compose-cadvisor-test.yml ps

# Ver logs
docker-compose -f docker-compose-cadvisor-test.yml logs -f cadvisor

# Parar stress test
docker-compose -f docker-compose-cadvisor-test.yml stop stress-test

# Reiniciar tudo
docker-compose -f docker-compose-cadvisor-test.yml restart
```

## 🔧 Troubleshooting

### Prometheus não coleta métricas
```bash
# Verificar targets
curl http://localhost:9090/api/v1/targets

# Testar conectividade
telnet IP_TARGET 9100
telnet IP_TARGET 8080

# Verificar Security Groups
# Verificar IPs no prometheus.yml
```

### Alertas não aparecem
```bash
# Verificar se regras foram carregadas
curl http://localhost:9090/api/v1/rules

# Verificar status dos alertas
curl http://localhost:9090/api/v1/alerts

# Forçar reload
curl -X POST http://localhost:9090/-/reload
```

### Containers não aparecem no cAdvisor
```bash
# Verificar se containers estão rodando
docker ps

# Reiniciar cAdvisor
docker-compose -f docker-compose-cadvisor-test.yml restart cadvisor

# Ver logs
docker-compose -f docker-compose-cadvisor-test.yml logs cadvisor
```

## 📝 Notas Importantes

- ⚠️ **Security Groups**: Configure corretamente para permitir comunicação entre instâncias
- ⚠️ **IPs Privados**: Use IPs privados para comunicação entre instâncias na mesma VPC
- ⚠️ **Recursos**: Instâncias t3.medium/small são mínimas, ajuste conforme necessário
- ⚠️ **Custos**: Lembre-se de parar/terminar instâncias quando não estiver usando
- ⚠️ **Produção**: Configurações são para fins educacionais, ajuste para produção

## 🎓 Recursos Adicionais

- [Documentação Oficial do Prometheus](https://prometheus.io/docs/)
- [PromQL Cheat Sheet](https://promlabs.com/promql-cheat-sheet/)
- [Node Exporter Metrics](https://github.com/prometheus/node_exporter)
- [cAdvisor Documentation](https://github.com/google/cadvisor)
- [Alertmanager Configuration](https://prometheus.io/docs/alerting/latest/configuration/)

## 📄 Licença

Este material é parte do curso PosTech DevOps e Arquitetura Cloud.

---

**Autor**: PosTech DevOps e Arquitetura Cloud  
**Aula**: 02 - Monitoramento OpenSource  
**Data**: 2024