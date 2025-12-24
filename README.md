# Aula 02 - PosTech DevOps e Arquitetura Cloud

Este repositório contém os materiais da **Aula 02** do módulo **Monitoramento OpenSource** da PosTech DevOps e Arquitetura Cloud.

## Conteúdo da Branch aula-02

### 1. Script de User Data EC2 (`ec2-userdata-demo.sh`)
Script automatizado para configuração de instâncias EC2 Ubuntu com:
- Docker e Docker Compose
- Code-server (VS Code no navegador) na porta 80
- Configurações básicas de segurança

### 2. Docker Compose Prometheus (`docker-compose.yml`)
Stack do Prometheus para monitoramento moderno com:
- Prometheus Server (coleta de métricas)
- Alertmanager (gerenciamento de alertas)

### 3. Exporters Manuais
- Node Exporter (instalação manual nas instâncias)
- cAdvisor (instalação manual nas instâncias)

## Arquivos de Documentação

- `ec2-userdata.md` - Guia detalhado do script de user data
- `prometheus-compose.md` - Guia detalhado do Docker Compose Prometheus
- `setup-ec2-instances.md` - Passo a passo completo para criar as instâncias EC2 com SSM
- `exporters-installation.md` - Instalação manual do Node Exporter e cAdvisor

## Objetivo da Aula

Aprender a configurar e utilizar o Prometheus para coleta de métricas em sistemas dinâmicos, entendendo conceitos de scraping, exporters e alert rules para monitoramento moderno.

## Teoria Abordada

- **Monitoramento de sistemas dinâmicos e efêmeros**: Containers, microserviços e infraestrutura como código
- **Modelo de coleta pull**: Como o Prometheus coleta métricas ativamente dos targets
- **Exporters**: Componentes que expõem métricas de sistemas e aplicações
- **Séries temporais**: Estrutura de dados para armazenamento de métricas ao longo do tempo
- **Consultas com PromQL**: Linguagem de consulta do Prometheus para análise de dados
- **Funcionamento do Alertmanager**: Gerenciamento e roteamento de alertas baseados em regras