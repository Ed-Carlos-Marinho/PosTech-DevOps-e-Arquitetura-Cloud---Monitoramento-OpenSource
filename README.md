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

## 🚀 Como Usar

### 1. Escolher a Aula
Navegue para a branch correspondente à aula desejada:
```bash
git checkout aula-01  # Para Zabbix
git checkout aula-02  # Para Prometheus  
git checkout aula-03  # Para Grafana
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

## 🎯 Objetivos de Aprendizado

Ao completar este módulo, você será capaz de:

- **Implementar** soluções de monitoramento tradicionais com Zabbix
- **Configurar** monitoramento moderno com Prometheus e PromQL
- **Criar** dashboards dinâmicos e alertas visuais com Grafana
- **Integrar** múltiplas ferramentas de monitoramento
- **Aplicar** boas práticas de observabilidade em infraestrutura
- **Automatizar** deployment de stacks de monitoramento

## 📖 Recursos Adicionais

- [Documentação oficial do Zabbix](https://www.zabbix.com/documentation)
- [Documentação oficial do Prometheus](https://prometheus.io/docs/)
- [Documentação oficial do Grafana](https://grafana.com/docs/)
- [PromQL Tutorial](https://prometheus.io/docs/prometheus/latest/querying/basics/)
- [Grafana Dashboard Gallery](https://grafana.com/grafana/dashboards/)

## 🤝 Contribuição

Este repositório é parte do curso PosTech DevOps e Arquitetura Cloud. Para sugestões ou melhorias, entre em contato com a equipe acadêmica.

---

**PosTech DevOps e Arquitetura Cloud**  
*Módulo: Monitoramento OpenSource*