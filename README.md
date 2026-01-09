# Aula 03 - PosTech DevOps e Arquitetura Cloud

Este repositório contém os materiais da **Aula 03** do módulo **Monitoramento OpenSource** da PosTech DevOps e Arquitetura Cloud.

## Conteúdo da Branch aula-03

### 1. Script de User Data EC2 Instância 1 (`ec2-userdata-instance-01.sh`)
Script automatizado para configuração da instância de monitoramento com:
- Docker e Docker Compose
- Code-server (VS Code no navegador) na porta 8080
- Configurações básicas de segurança

### 2. Script de User Data EC2 Instância 2 (`ec2-userdata-instance-02.sh`)
Script automatizado para configuração da instância monitorada com:
- Node Exporter (métricas do sistema)
- cAdvisor (métricas de containers via Docker)
- Zabbix Agent (monitoramento tradicional)
- Configurações de firewall

### 3. Docker Compose Stack Completa (`docker-compose.yml`)
Stack integrada de monitoramento com:
- Grafana (visualização de dados e dashboards)
- Prometheus Server (coleta de métricas)
- Alertmanager (gerenciamento de alertas)
- Zabbix Server (monitoramento tradicional)
- MySQL Database (para Zabbix)

### 4. Exporters para Instância Monitorada
- Node Exporter (instalação automática via user data)
- cAdvisor (instalação automática via user data)
- Zabbix Agent (instalação automática via user data)

## Arquivos de Documentação

- `docs/ec2-userdata.md` - Guia detalhado dos scripts de user data
- `docs/grafana-compose.md` - Guia detalhado do Docker Compose com Grafana
- `docs/setup-ec2-instances.md` - Passo a passo completo para criar as instâncias EC2 com SSM

## Objetivo da Aula

Configurar o Grafana para integrar fontes de dados (Prometheus, Zabbix, etc.), criar dashboards dinâmicos e configurar alertas visuais e notificações personalizadas.

## Teoria Abordada

- **Arquitetura do Grafana**: Componentes, plugins e extensibilidade
- **Conceitos de data sources**: Integração com Prometheus, Zabbix e outras fontes
- **Variáveis e painéis dinâmicos**: Criação de dashboards interativos e reutilizáveis
- **Alertas baseados em métricas**: Configuração de alertas visuais no Grafana
- **Integração com Prometheus e Zabbix**: Unificação de ferramentas de monitoramento
- **Boas práticas de visualização de dados**: Design de dashboards eficazes e informativos