# Aula 04 - PosTech DevOps e Arquitetura Cloud

Este repositório contém os materiais da **Aula 04** do módulo **Monitoramento OpenSource** da PosTech DevOps e Arquitetura Cloud.

## Conteúdo da Branch aula-04

### 1. Script de User Data EC2 Instância 1 (`ec2-userdata-instance-01.sh`)
Script automatizado para configuração da instância de monitoramento com:
- Docker e Docker Compose
- Code-server (VS Code no navegador) na porta 8080
- Configurações básicas de segurança

### 2. Script de User Data EC2 Instância 2 (`ec2-userdata-instance-02.sh`)
Script automatizado para configuração da instância de aplicação de teste com:
- Docker e Docker Compose
- Clonagem do repositório
- Inicialização automática da stack de aplicação

### 3. Docker Compose Stack de Observabilidade (`docker-compose-observability.yml`)
Stack focada em observabilidade para Instância 1:
- Grafana (visualização unificada de métricas e logs)
- Loki (armazenamento e consulta de logs)
- Prometheus Server (métricas básicas para correlação)
- Promtail (agente de coleta de logs local)

### 4. Docker Compose Stack de Aplicação (`test-app/docker-compose-app.yml`)
Stack de aplicação de teste para Instância 2:
- Aplicação Flask de teste (gera logs abundantes)
- Nginx (proxy e logs de acesso)
- Promtail (coleta de logs para Loki)
- Log Generator (gerador adicional de logs)

### 5. Configurações de Logs Centralizados
- Loki Server (armazenamento de logs)
- Promtail (coleta automática de logs do sistema e aplicações)
- Configurações LogQL para consultas avançadas
- Correlação entre logs e métricas no Grafana

## Estrutura do Projeto

```
├── README.md                           # Documentação principal
├── docker-compose-observability.yml   # Stack de observabilidade (Instância 1)
├── loki-config.yml                     # Configuração do Loki
├── promtail-config.yml                 # Configuração do Promtail (Instância 1)
├── prometheus.yml                      # Configuração do Prometheus (simplificada)
├── ec2-userdata-instance-01.sh         # Script para Instância 1
├── ec2-userdata-instance-02.sh         # Script para Instância 2
├── test-app/                           # Aplicação de teste (Instância 2)
│   ├── docker-compose-app.yml          # Stack da aplicação
│   ├── Dockerfile.test-app             # Dockerfile da aplicação
│   ├── test-app.py                     # Aplicação Flask
│   ├── requirements.txt                # Dependências Python
│   ├── nginx.conf                      # Configuração do Nginx
│   └── promtail-app-config.yml         # Configuração do Promtail
└── docs/                               # Documentação adicional
    ├── setup-ec2-instances.md          # Guia de setup das instâncias
    ├── loki-compose.md                 # Guia do Docker Compose
    ├── loki-logql-guide.md             # Guia de LogQL
    └── ec2-userdata.md                 # Guia dos scripts
```

## Arquivos de Documentação

- `docs/ec2-userdata.md` - Guia detalhado dos scripts de user data
- `docs/loki-compose.md` - Guia detalhado do Docker Compose com Loki
- `docs/setup-ec2-instances.md` - Passo a passo completo para criar as instâncias EC2 com SSM
- `docs/loki-logql-guide.md` - Guia completo de consultas LogQL e correlação com métricas

## Como usar

### 1. Instância 1 (Observabilidade)
```bash
# Clonar repositório
git clone -b aula-04 https://github.com/Ed-Carlos-Marinho/PosTech-DevOps-e-Arquitetura-Cloud---Monitoramento-OpenSource.git PosTech
cd PosTech

# Iniciar stack de observabilidade
docker-compose -f docker-compose-observability.yml up -d

# Acessar interfaces
# - Grafana: http://IP_INSTANCIA_1:3000 (admin/admin123)
# - Prometheus: http://IP_INSTANCIA_1:9090
# - Loki: http://IP_INSTANCIA_1:3100 (API)
```

### 2. Instância 2 (Aplicação de Teste)
```bash
# Clonar repositório
git clone -b aula-04 https://github.com/Ed-Carlos-Marinho/PosTech-DevOps-e-Arquitetura-Cloud---Monitoramento-OpenSource.git PosTech
cd PosTech/test-app

# Configurar IP do Loki (substitua pelo IP privado da Instância 1)
sed -i 's/LOKI_SERVER_IP/IP_PRIVADO_INSTANCIA_1/' promtail-app-config.yml

# Iniciar stack de aplicação
docker-compose -f docker-compose-app.yml up -d

# Aguardar alguns segundos
sleep 15

# Gerar tráfego inicial para criar logs
curl http://localhost/
curl http://localhost/generate/50
curl http://localhost/health
```

**Nota:** A stack inclui um `traffic-generator` que gera tráfego HTTP automaticamente a cada 5-10 segundos, garantindo que sempre haverá logs sendo gerados.

**Configuração Automática do IP do Loki:**

O script de userdata da Instância 2 pode configurar automaticamente o IP do Loki usando uma das seguintes opções:

1. **Variável de ambiente** (adicione no início do userdata):
```bash
export LOKI_SERVER_IP="10.0.1.100"
```

2. **Tag da instância EC2**:
```
Key: LokiServerIP
Value: 10.0.1.100
```

3. **SSM Parameter Store**:
```bash
aws ssm put-parameter --name "/observability/loki-server-ip" \
  --value "10.0.1.100" --type String
```

### 3. Configurar Data Sources no Grafana
1. **Loki**: `http://loki:3100`
2. **Prometheus**: `http://prometheus:9090`

### 4. Consultas LogQL básicas
```logql
# Todos os logs da aplicação
{job="test-app"}

# Logs de erro
{job="test-app",level="error"}

# Logs do Nginx
{job="nginx-access"}

# Taxa de logs por segundo
rate({job="test-app"}[5m])
```

## Objetivo da Aula

Implantar e utilizar o Loki para coleta, armazenamento e consulta de logs centralizados, integrando com o Grafana para observabilidade unificada (logs + métricas).

## Teoria Abordada

- **Conceito de logs centralizados**: Importância da centralização de logs em ambientes distribuídos
- **Diferenças entre logs e métricas**: Quando usar cada tipo de dado para observabilidade
- **Arquitetura Loki/Promtail**: Como funciona a coleta e armazenamento de logs
- **Estrutura de labels**: Organização eficiente de logs com labels no Loki
- **Consultas com LogQL**: Linguagem de consulta específica para logs no Loki
- **Correlação com métricas no Grafana**: Unificação de logs e métricas em dashboards
- **Observabilidade completa**: Logs, métricas e traces trabalhando juntos