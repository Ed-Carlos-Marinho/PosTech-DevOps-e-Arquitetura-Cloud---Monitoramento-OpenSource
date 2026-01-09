# Aula 02 - PosTech DevOps e Arquitetura Cloud

Este repositório contém os materiais da **Aula 02** do módulo **Monitoramento OpenSource** da PosTech DevOps e Arquitetura Cloud.

## Conteúdo da Branch aula-02

### 1. Scripts de User Data EC2
- `ec2-userdata-instance-01.sh` - Script para Instância 1 (Prometheus Server)
- `ec2-userdata-instance-02.sh` - Script para Instância 2 (Docker apenas)

Scripts automatizados para configuração de instâncias EC2 Ubuntu:
- **Instância 1**: Docker, Docker Compose e code-server
- **Instância 2**: Docker apenas (exporters instalados manualmente)

### 2. Docker Compose Prometheus (`docker-compose.yml`)
Stack do Prometheus para monitoramento moderno com:
- Prometheus Server (coleta de métricas)
- Alertmanager (gerenciamento de alertas)

### 3. Exporters Manuais
- Node Exporter (instalação manual nas instâncias)
- cAdvisor (instalação manual nas instâncias)

## Estrutura do Projeto

```
├── README.md                           # Documentação principal
├── docker-compose.yml                 # Stack Prometheus + Alertmanager
├── prometheus.yml                      # Configuração do Prometheus
├── alertmanager.yml                    # Configuração do Alertmanager
├── alert_rules.yml                     # Regras de alertas
├── ec2-userdata-instance-01.sh         # Script para Instância 1 (Prometheus Server)
├── ec2-userdata-instance-02.sh         # Script para Instância 2 (Docker apenas)
└── docs/                               # Documentação detalhada
    ├── setup-ec2-instances.md          # Guia de setup das instâncias
    ├── exporters-installation.md       # Guia de instalação dos exporters
    ├── prometheus-compose.md           # Guia do Docker Compose
    └── ec2-userdata.md                 # Guia dos scripts de user data
```

## Objetivo da Aula

Aprender a configurar e utilizar o Prometheus para coleta de métricas em sistemas dinâmicos, entendendo conceitos de scraping, exporters e alert rules para monitoramento moderno.

## Teoria Abordada

- **Monitoramento de sistemas dinâmicos e efêmeros**: Containers, microserviços e infraestrutura como código
- **Modelo de coleta pull**: Como o Prometheus coleta métricas ativamente dos targets
- **Exporters**: Componentes que expõem métricas de sistemas e aplicações
- **Séries temporais**: Estrutura de dados para armazenamento de métricas ao longo do tempo
- **Consultas com PromQL**: Linguagem de consulta do Prometheus para análise de dados
- **Funcionamento do Alertmanager**: Gerenciamento e roteamento de alertas baseados em regras