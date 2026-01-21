# PosTech DevOps e Arquitetura Cloud - Monitoramento OpenSource

Este repositório contém os materiais práticos do módulo **Monitoramento OpenSource** da PosTech DevOps e Arquitetura Cloud.

## Estrutura do Repositório

Cada aula possui sua própria branch com materiais específicos e documentação completa.

### 📚 Aulas Disponíveis

#### [Aula 01 - Zabbix](../../tree/aula-01)
**Objetivo:** Compreender e aplicar o uso do Zabbix para instalação, configuração e monitoramento de hosts, criando métricas de desempenho e alertas para infraestrutura.

**Teoria Abordada:**
- Conceitos de monitoramento tradicional
- Agente e servidor Zabbix
- Agente ativo/passivo
- Triggers, itens e templates
- Arquitetura cliente-servidor e ciclo de coleta

**Conteúdo:**
- Script de User Data EC2 automatizado
- Docker Compose com stack completa do Zabbix
- Configuração de instâncias EC2 com SSM
- Instalação e configuração do Zabbix Agent
- Monitoramento tradicional de infraestrutura

**Tecnologias:** Zabbix Server, Zabbix Agent, MySQL, Docker, AWS EC2

---

#### [Aula 02 - Prometheus](../../tree/aula-02)
**Objetivo:** Aprender a configurar e utilizar o Prometheus para coleta de métricas em sistemas dinâmicos, entendendo conceitos de scraping, exporters e alert rules para monitoramento moderno.

**Teoria Abordada:**
- Monitoramento de sistemas dinâmicos e efêmeros
- Modelo de coleta pull
- Exporters e séries temporais
- Consultas com PromQL
- Funcionamento do Alertmanager

**Conteúdo:**
- Stack Prometheus + Alertmanager
- Node Exporter e cAdvisor
- Configuração de alertas
- Consultas PromQL práticas

**Tecnologias:** Prometheus, Alertmanager, Node Exporter, cAdvisor, PromQL

---

#### [Aula 03 - Grafana](../../tree/aula-03)
**Objetivo:** Configurar o Grafana para integrar fontes de dados (Prometheus, Zabbix, etc.), criar dashboards dinâmicos e configurar alertas visuais e notificações personalizadas.

**Teoria Abordada:**
- Arquitetura do Grafana
- Conceitos de data sources
- Variáveis e painéis dinâmicos
- Alertas baseados em métricas
- Integração com Prometheus e Zabbix
- Boas práticas de visualização de dados

**Conteúdo:**
- Stack completa: Grafana + Prometheus + Zabbix
- Configuração de múltiplas fontes de dados
- Criação de dashboards dinâmicos
- Alertas visuais e notificações
- Boas práticas de visualização

**Tecnologias:** Grafana, Prometheus, Zabbix, Dashboards, Alerting

---

#### [Aula 04 - Logs com Loki](../../tree/aula-04)
**Objetivo:** Configurar o Loki para coleta, armazenamento e consulta de logs, integrando com Grafana para correlação entre logs e métricas em uma solução de observabilidade unificada.

**Teoria Abordada:**
- Conceitos de log aggregation e centralização
- Arquitetura Loki vs Elasticsearch
- Promtail como agente de coleta
- LogQL para consultas de logs
- Correlação entre logs e métricas
- Estratégias de retenção e performance

**Conteúdo:**
- Stack Loki + Grafana + Prometheus
- Configuração do Promtail para coleta
- Aplicação de teste geradora de logs
- Consultas LogQL práticas
- Correlação logs-métricas no Grafana

**Tecnologias:** Loki, Promtail, LogQL, Grafana, Log Aggregation

---

#### [Aula 05 - Tracing com Jaeger](../../tree/aula-05)
**Objetivo:** Entender o conceito de tracing distribuído e configurar o Jaeger para rastrear requisições entre serviços, identificar gargalos e melhorar a performance de aplicações distribuídas.

**Teoria Abordada:**
- Conceitos de tracing distribuído
- Spans, traces e contexto de requisição
- Sampling e instrumentação de serviços
- Arquitetura Jaeger (collector, agent, query e UI)
- Diagnóstico de latência e gargalos
- Jaeger Client Libraries nativo
- Context propagation entre serviços

**Conteúdo:**
- Stack Jaeger completa (collector, agent, query, UI)
- Aplicações distribuídas instrumentadas (Node.js + Python)
- Instrumentação com Jaeger Client Libraries
- Correlação traces-logs-métricas
- Análise de performance e debugging

**Tecnologias:** Jaeger, OpenTracing, Distributed Tracing, Node.js, Python Flask

---

#### [Aula 07 - Observabilidade no Kubernetes](../../tree/aula-07)
**Objetivo:** Integrar parte da stack de observabilidade (Prometheus, Grafana, Loki) dentro de um cluster Kubernetes, entendendo as melhores práticas de deployment e coleta de dados.

**Teoria Abordada:**
- Conceitos de observabilidade em ambientes orquestrados
- Prometheus Operator para gerenciamento declarativo
- ServiceMonitor e PodMonitor para descoberta automática
- Coleta de métricas de aplicações, pods e nodes
- Integração com Grafana e Loki
- Boas práticas de deployment e descoberta automática de métricas

**Conteúdo:**
- Cluster EKS (Amazon Elastic Kubernetes Service)
- Prometheus Operator com kube-prometheus-stack
- ServiceMonitor e PodMonitor para descoberta de targets
- Grafana para visualização unificada
- Loki para agregação de logs em Kubernetes
- Aplicações demo instrumentadas
- Instância EC2 Bastion com kubectl, helm e code-server

**Tecnologias:** Kubernetes, EKS, Prometheus Operator, Helm, ServiceMonitor, PodMonitor, Grafana, Loki

## 🚀 Como Usar

### 1. Escolher a Aula
Navegue para a branch correspondente à aula desejada:
```bash
git checkout aula-01  # Para Zabbix
git checkout aula-02  # Para Prometheus  
git checkout aula-03  # Para Grafana
git checkout aula-04  # Para Logs com Loki
git checkout aula-05  # Para Tracing com Jaeger
git checkout aula-07  # Para Observabilidade no Kubernetes
```

### 2. Seguir a Documentação
Cada branch contém:
- **README.md** - Visão geral da aula
- **setup-ec2-instances.md** - Configuração das instâncias AWS
- **Guias específicos** - Documentação detalhada de cada ferramenta
- **Docker Compose files** - Stacks prontas para uso

### 3. Executar os Labs
1. Configure as instâncias EC2 seguindo o guia
2. Execute os Docker Compose files
3. Siga os tutoriais de configuração
4. Explore as ferramentas de monitoramento

## 📋 Pré-requisitos

- **Conta AWS** com permissões para EC2, IAM e SSM
- **Conhecimentos básicos** de Docker e Linux
- **Key Pair** configurado na AWS
- **AWS CLI** instalado (opcional)

## 🏗️ Arquitetura Geral

### Aula 01 (Zabbix)
```
┌─────────────────┐    ┌─────────────────┐
│   Instância 1   │    │   Instância 2   │
│                 │    │                 │
│ • Zabbix Server │◄──►│ • Zabbix Agent  │
│ • MySQL         │    │ • Métricas OS   │
│ • Web Interface │    │                 │
└─────────────────┘    └─────────────────┘
```

### Aula 02 (Prometheus)
```
┌─────────────────┐    ┌─────────────────┐
│   Instância 1   │    │   Instância 2   │
│                 │    │                 │
│ • Prometheus    │◄──►│ • Node Exporter │
│ • Alertmanager  │    │ • cAdvisor      │
│                 │    │                 │
└─────────────────┘    └─────────────────┘
```

### Aula 03 (Grafana)
```
┌─────────────────┐    ┌─────────────────┐
│   Instância 1   │    │   Instância 2   │
│                 │    │                 │
│ • Grafana       │◄──►│ • Node Exporter │
│ • Prometheus    │    │ • cAdvisor      │
│ • Zabbix Server │    │ • Zabbix Agent  │
│ • Alertmanager  │    │ • Nginx Demo    │
└─────────────────┘    └─────────────────┘
```

### Aula 04 (Logs com Loki)
```
┌─────────────────┐    ┌─────────────────┐
│   Instância 1   │    │   Instância 2   │
│                 │    │                 │
│ • Grafana       │◄──►│ • Test App      │
│ • Loki          │    │ • Promtail      │
│ • Prometheus    │    │ • Nginx Proxy   │
│ • Promtail      │    │                 │
└─────────────────┘    └─────────────────┘
```

### Aula 05 (Tracing com Jaeger)
```
┌─────────────────┐    ┌─────────────────┐
│   Instância 1   │    │   Instância 2   │
│                 │    │                 │
│ • Grafana       │◄──►│ • Frontend App  │
│ • Jaeger UI     │    │ • Backend API   │
│ • Jaeger Query  │    │ • PostgreSQL    │
│ • Jaeger Coll.  │    │ • Redis Cache   │
│ • Elasticsearch │    │ • RabbitMQ      │
│ • Loki          │    │ • Jaeger Agent  │
│ • Prometheus    │    │ • Promtail      │
└─────────────────┘    └─────────────────┘
```

### Aula 07 (Observabilidade no Kubernetes)
```
┌─────────────────────────────────────────┐
│         Cluster EKS (Kubernetes)        │
│                                         │
│  ┌──────────────────────────────────┐  │
│  │   Namespace: monitoring          │  │
│  │                                  │  │
│  │  • Prometheus Operator           │  │
│  │  • Grafana                       │  │
│  │  • Loki                          │  │
│  │  • ServiceMonitor                │  │
│  │  • PodMonitor                    │  │
│  └──────────────────────────────────┘  │
│                                         │
│  ┌──────────────────────────────────┐  │
│  │   Namespace: demo-apps           │  │
│  │                                  │  │
│  │  • Web App (instrumentada)       │  │
│  │  • CronJob (com PodMonitor)      │  │
│  │  • Métricas expostas             │  │
│  └──────────────────────────────────┘  │
└─────────────────────────────────────────┘
           ▲
           │
┌──────────┴──────────┐
│  Instância Bastion  │
│                     │
│  • kubectl          │
│  • helm             │
│  • code-server      │
│  • AWS CLI          │
└─────────────────────┘
```

## 🎯 Objetivos de Aprendizado

Ao completar este módulo, você será capaz de:

- **Implementar** soluções de monitoramento tradicionais com Zabbix
- **Configurar** monitoramento moderno com Prometheus e PromQL
- **Criar** dashboards dinâmicos e alertas visuais com Grafana
- **Centralizar** logs com Loki e consultas LogQL
- **Implementar** tracing distribuído com Jaeger
- **Integrar** múltiplas ferramentas de monitoramento
- **Aplicar** boas práticas de observabilidade completa (métricas, logs, traces)
- **Automatizar** deployment de stacks de monitoramento
- **Configurar** observabilidade nativa em Kubernetes com Prometheus Operator
- **Utilizar** ServiceMonitor e PodMonitor para descoberta automática de métricas

## 📖 Recursos Adicionais

- [Documentação oficial do Zabbix](https://www.zabbix.com/documentation)
- [Documentação oficial do Prometheus](https://prometheus.io/docs/)
- [Documentação oficial do Grafana](https://grafana.com/docs/)
- [Documentação oficial do Loki](https://grafana.com/docs/loki/latest/)
- [Documentação oficial do Jaeger](https://www.jaegertracing.io/docs/)
- [Documentação oficial do Kubernetes](https://kubernetes.io/docs/)
- [Prometheus Operator](https://prometheus-operator.dev/)
- [PromQL Tutorial](https://prometheus.io/docs/prometheus/latest/querying/basics/)
- [LogQL Tutorial](https://grafana.com/docs/loki/latest/logql/)
- [OpenTracing Specification](https://opentracing.io/specification/)
- [Grafana Dashboard Gallery](https://grafana.com/grafana/dashboards/)
- [Helm Charts](https://helm.sh/docs/)

## 🤝 Contribuição

Este repositório é parte do curso PosTech DevOps e Arquitetura Cloud. Para sugestões ou melhorias, entre em contato com a equipe acadêmica.

---

**PosTech DevOps e Arquitetura Cloud**  
*Módulo: Monitoramento OpenSource*