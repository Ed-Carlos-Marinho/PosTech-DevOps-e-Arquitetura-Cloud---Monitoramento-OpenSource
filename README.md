# Aula 07 - PosTech DevOps e Arquitetura Cloud

Este repositório contém os materiais da **Aula 07** do módulo **Monitoramento OpenSource** da PosTech DevOps e Arquitetura Cloud.

## Observabilidade no Kubernetes

**Objetivo:** Integrar parte da stack de observabilidade (Prometheus, Grafana, Loki) dentro de um cluster Kubernetes, entendendo as melhores práticas de deployment e coleta de dados.

**Teoria:** Conceitos de observabilidade em ambientes orquestrados; uso do Prometheus Operator; configuração de ServiceMonitor e PodMonitor; coleta de métricas de aplicações, pods e nodes; integração com Grafana e Loki; boas práticas de deployment e descoberta automática de métricas.

## Arquitetura da Aula 07

### Ambiente de Laboratório Kubernetes

- **EKS Cluster**: Amazon Elastic Kubernetes Service para demonstração de observabilidade nativa
  - Prometheus Operator (gerenciamento declarativo de monitoramento)
  - Grafana (visualização unificada de métricas e logs)
  - Loki (agregação de logs otimizada para Kubernetes)
  - ServiceMonitor e PodMonitor (descoberta automática de métricas)
  - Aplicações demo instrumentadas

- **Instância EC2 Bastion**: Estação de trabalho para execução de comandos
  - kubectl (cliente Kubernetes)
  - helm (gerenciador de pacotes Kubernetes)
  - code-server (VS Code no navegador)
  - AWS CLI (integração com serviços AWS)
  - Ferramentas de troubleshooting

### Novidades da Aula 07:
- **Kubernetes Nativo**: Observabilidade em ambiente orquestrado real
- **Prometheus Operator**: Gerenciamento declarativo de monitoramento
- **ServiceMonitor/PodMonitor**: Descoberta automática de targets
- **Infraestrutura como Código**: Terraform para reprodutibilidade
- **Ambiente Multi-usuário**: Acesso controlado para estudantes

## Estrutura do Projeto Aula 07

```
├── README.md                           # Documentação principal
├── ec2-userdata-eks-bastion.sh         # Script user data para instância bastion
├── kubernetes/                         # Manifests Kubernetes
│   ├── observability/                  # Stack de observabilidade
│   │   ├── kube-prometheus-stack/      # Helm values
│   │   ├── loki-stack/                 # Configuração Loki
│   │   └── dashboards/                 # Dashboards Grafana
│   ├── demo-apps/                      # Aplicações de demonstração
│   │   ├── web-app/                    # App com ServiceMonitor
│   │   ├── cronjob/                    # Job com PodMonitor
│   │   └── monitoring/                 # Recursos de monitoramento
│   └── rbac/                           # Controle de acesso
├── scripts/                            # Scripts de automação
│   ├── setup-environment.sh            # Setup completo do ambiente
│   ├── create-demo-apps.sh             # Deploy das aplicações demo
│   └── cleanup-environment.sh          # Limpeza do ambiente
├── exercises/                          # Exercícios práticos
│   ├── 01-deploy-prometheus-stack/     # Exercício 1
│   ├── 02-create-servicemonitor/       # Exercício 2
│   ├── 03-custom-dashboards/           # Exercício 3
│   ├── 04-log-analysis-loki/           # Exercício 4
│   └── 05-alerting-rules/              # Exercício 5
└── docs/                               # Documentação
    ├── setup-eks-lab.md                # Guia de setup do laboratório
    ├── kubernetes-observability.md     # Guia de observabilidade K8s
    ├── servicemonitor-guide.md         # Guia ServiceMonitor
    ├── podmonitor-guide.md             # Guia PodMonitor
    └── troubleshooting.md              # Guia de troubleshooting
```

## Como usar - Aula 07

## Como usar - Aula 07

### Pré-requisitos
- Conta AWS com permissões para EKS, EC2, IAM
- Cluster EKS criado manualmente (veja guia abaixo)
- Key pair AWS criado
- AWS CLI configurado localmente (opcional)

### 1. Criar Cluster EKS Manualmente

#### Via Console AWS (Recomendado para aula)
1. **EKS Console** → **Clusters** → **Create cluster**
2. **Configurações básicas:**
   - Name: `observability-lab-cluster`
   - Kubernetes version: `1.28`
   - Service role: Criar ou usar existente com políticas EKS

3. **Networking:**
   - VPC: Default ou criar nova
   - Subnets: Selecionar subnets públicas e privadas
   - Security groups: Default ou criar específico

4. **Add-ons:** Manter padrões (CoreDNS, kube-proxy, VPC CNI)

5. **Node groups:**
   - Name: `worker-nodes`
   - Instance types: `t3.medium`
   - Capacity type: `Spot` (para economia)
   - Scaling: Min 2, Max 6, Desired 3

#### Via AWS CLI (Alternativo)
```bash
# Criar cluster EKS
aws eks create-cluster \
  --name observability-lab-cluster \
  --version 1.28 \
  --role-arn arn:aws:iam::ACCOUNT:role/eks-service-role \
  --resources-vpc-config subnetIds=subnet-xxx,subnet-yyy

# Aguardar cluster ficar ativo
aws eks wait cluster-active --name observability-lab-cluster

# Criar node group
aws eks create-nodegroup \
  --cluster-name observability-lab-cluster \
  --nodegroup-name worker-nodes \
  --instance-types t3.medium \
  --capacity-type SPOT \
  --scaling-config minSize=2,maxSize=6,desiredSize=3 \
  --node-role arn:aws:iam::ACCOUNT:role/NodeInstanceRole \
  --subnets subnet-xxx subnet-yyy
```

### 2. Criar Instância EC2 Bastion

#### Via Console AWS
1. **EC2 Dashboard** → **Launch Instance**
2. **Configurações básicas:**
   - Name: `eks-bastion-observability-lab`
   - AMI: Ubuntu Server 22.04 LTS
   - Instance type: `t3.medium`
   - Key pair: Selecione sua chave

3. **Network settings:**
   - VPC: Mesma do cluster EKS
   - Subnet: Pública
   - Auto-assign public IP: Enable
   - Security group: Criar novo com SSH (22) e HTTP (8080)

4. **Advanced details:**
   - IAM instance profile: Criar com políticas EKS (veja abaixo)
   - User data: Cole o conteúdo do `ec2-userdata-eks-bastion.sh`

#### Políticas IAM Necessárias
Criar role IAM com as seguintes políticas:
- `AmazonEKSClusterPolicy` (para acesso ao cluster)
- `AmazonEKSWorkerNodePolicy` (para gerenciar nodes)
- `AmazonSSMManagedInstanceCore` (para Session Manager)

### 3. Acessar o Ambiente
```bash
# Via SSH
ssh -i sua-chave.pem ubuntu@BASTION_IP

# Via Session Manager (recomendado)
aws ssm start-session --target INSTANCE_ID

# Aguardar inicialização (5-10 minutos)
sudo tail -f /var/log/user-data.log
```

### 4. Configurar Acesso ao EKS
```bash
# Na instância bastion
./configure-eks-access.sh observability-lab-cluster us-east-2

# Verificar acesso
kubectl get nodes
kubectl get namespaces

# Verificar pré-requisitos
./check-prerequisites.sh
```

### 5. Deploy da Stack de Observabilidade
```bash
# Na instância bastion
cd /home/ubuntu/lab-materials

# Deploy da stack de observabilidade (seguir documentação)
# Consultar: docs/deploy-observability-stack.md

# Verificar deployment
kubectl get pods -n monitoring
kubectl get svc -n monitoring
```

### 6. Acessar Interfaces de Monitoramento
- **Grafana**: Obter URL do LoadBalancer
  ```bash
  kubectl get svc -n monitoring grafana
  # Acessar via browser: http://EXTERNAL-IP:3000
  # Credenciais: admin / admin123
  ```

### 7. Deploy das Aplicações Demo
```bash
# Deploy das aplicações de exemplo
./scripts/create-demo-apps.sh

# Verificar ServiceMonitor e PodMonitor
kubectl get servicemonitor -n demo-apps
kubectl get podmonitor -n demo-apps

# Verificar targets no Prometheus
# Grafana > Explore > Prometheus > up
```

### 8. Exercícios Práticos

#### Exercício 1: Deploy kube-prometheus-stack
```bash
cd exercises/01-deploy-prometheus-stack
cat README.md
# Seguir instruções do exercício
```

#### Exercício 2: Criar ServiceMonitor
```bash
cd exercises/02-create-servicemonitor
cat README.md
# Criar ServiceMonitor para nova aplicação
```

#### Exercício 3: Dashboards Customizados
```bash
cd exercises/03-custom-dashboards
cat README.md
# Criar dashboard personalizado no Grafana
```

#### Exercício 4: Análise de Logs com Loki
```bash
cd exercises/04-log-analysis-loki
cat README.md
# Consultas LogQL e correlação com métricas
```

#### Exercício 5: Regras de Alerta
```bash
cd exercises/05-alerting-rules
cat README.md
# Configurar alertas customizados
```

### 9. Limpeza do Ambiente
```bash
# Remover aplicações demo
./scripts/cleanup-environment.sh

# Destruir cluster EKS (quando não precisar mais)
# Via Console AWS ou AWS CLI:
aws eks delete-nodegroup --cluster-name observability-lab-cluster --nodegroup-name worker-nodes
aws eks delete-cluster --name observability-lab-cluster

# Terminar instância EC2 bastion
# Via Console AWS ou AWS CLI
```

## Endpoints e Interfaces - Aula 07

### Instância Bastion
- **SSH**: `ssh -i key.pem ubuntu@BASTION_IP`
- **Session Manager**: Via AWS Console ou AWS CLI
- **Code-server**: `http://BASTION_IP:8080` (senha: demo123)

### Cluster EKS
- **Grafana**: `http://GRAFANA_LB_URL:3000` (admin/admin123)
- **Prometheus**: Acessível via port-forward ou Grafana
- **Loki**: Integrado no Grafana como data source

### Aplicações Demo
- **Web App**: Acessível via Ingress ou port-forward
- **Metrics Endpoints**: `/metrics` em cada aplicação
- **ServiceMonitor**: Descoberta automática pelo Prometheus

## Comandos Úteis - Aula 07

### Kubernetes
```bash
# Verificar cluster
kubectl cluster-info
kubectl get nodes

# Monitoramento
kubectl get pods -n monitoring
kubectl get servicemonitor -A
kubectl get podmonitor -A

# Logs
kubectl logs -n monitoring prometheus-kube-prometheus-prometheus-0
kubectl logs -n monitoring grafana-xxx

# Port-forward para acesso local
kubectl port-forward -n monitoring svc/grafana 3000:80
kubectl port-forward -n monitoring svc/prometheus-kube-prometheus-prometheus 9090:9090
```

### Helm
```bash
# Listar releases
helm list -A

# Status do kube-prometheus-stack
helm status kube-prometheus-stack -n monitoring

# Upgrade da stack
helm upgrade kube-prometheus-stack prometheus-community/kube-prometheus-stack -n monitoring -f values.yaml
```

### Troubleshooting
```bash
# Verificar eventos
kubectl get events -n monitoring --sort-by='.lastTimestamp'

# Verificar recursos
kubectl top nodes
kubectl top pods -n monitoring

# Verificar configuração do Prometheus
kubectl get prometheus -n monitoring -o yaml
```

## Objetivos de Aprendizado - Aula 07

### Conceitos Teóricos
- **Observabilidade em Kubernetes**: Diferenças entre monitoramento tradicional e cloud-native
- **Prometheus Operator**: Vantagens do gerenciamento declarativo
- **Service Discovery**: Como o Kubernetes facilita a descoberta automática
- **Labels e Selectors**: Importância para organização e filtragem
- **Agregação de Logs**: Desafios e soluções em ambientes distribuídos

### Habilidades Práticas
- Deployar stack de observabilidade usando Helm
- Criar e configurar ServiceMonitor e PodMonitor
- Instrumentar aplicações para exposição de métricas
- Criar dashboards customizados no Grafana
- Escrever consultas LogQL para análise de logs
- Configurar regras de alerta para Kubernetes
- Troubleshooting de problemas de monitoramento

### Melhores Práticas
- Organização de recursos de monitoramento por namespace
- Estratégias de labeling para métricas e logs
- Configuração de retenção e storage para dados de monitoramento
- Segurança e controle de acesso em ambientes de monitoramento
- Otimização de performance para coleta de métricas em escala

---

## Conteúdo Legado - Aula 05 (Docker Compose)

### Arquitetura da Aula 05

- **Instância 1**: Stack de Observabilidade Completa (t4g.medium - ARM64)
  - Grafana (visualização unificada de métricas, logs e traces)
  - Loki (armazenamento centralizado de logs)
  - Prometheus (coleta de métricas)
  - Jaeger (tracing distribuído completo)
  - Promtail (coleta local de logs)

- **Instância 2**: Aplicações Distribuídas Instrumentadas (t3.medium - AMD64)
  - Frontend Service (Node.js/Express com OpenTelemetry)
  - Backend API Service (Python/Flask com OpenTelemetry)
  - PostgreSQL Database (armazenamento persistente)
  - Redis Cache (cache de consultas)
  - RabbitMQ (message queue)
  - Jaeger Agent (coleta local de traces)
  - Promtail (envio de logs para Loki)

### 5. Configurações de Tracing Distribuído
- Jaeger All-in-One (desenvolvimento) e componentes separados (produção)
- Instrumentação Jaeger Client Libraries nativo para múltiplas linguagens
- Sampling strategies para otimização de performance
- Correlação entre traces, logs e métricas no Grafana
- Context propagation entre serviços via HTTP headers

### Como usar - Aula 05 (Legado)

#### 1. Instância 1 (Observabilidade)
```bash
# Clonar repositório
git clone -b aula-05 https://github.com/Ed-Carlos-Marinho/PosTech-DevOps-e-Arquitetura-Cloud---Monitoramento-OpenSource.git
cd PosTech-DevOps-e-Arquitetura-Cloud---Monitoramento-OpenSource

# Iniciar stack de observabilidade
docker-compose -f docker-compose-observability.yml up -d

# Acessar interfaces
# - Grafana: http://IP_INSTANCIA_1:3000 (admin/admin123)
# - Prometheus: http://IP_INSTANCIA_1:9090
# - Loki: http://IP_INSTANCIA_1:3100 (API)
# - Jaeger UI: http://IP_INSTANCIA_1:16686
```

#### 2. Instância 2 (Aplicações Distribuídas)
```bash
# Clonar repositório
git clone -b aula-05 https://github.com/Ed-Carlos-Marinho/PosTech-DevOps-e-Arquitetura-Cloud---Monitoramento-OpenSource.git
cd PosTech-DevOps-e-Arquitetura-Cloud---Monitoramento-OpenSource/distributed-app

# Configurar IP do Jaeger Collector
sed -i 's/JAEGER_COLLECTOR_IP/IP_PRIVADO_INSTANCIA_1/' jaeger-agent-config.yml

# Iniciar stack de aplicações distribuídas
docker-compose -f docker-compose-app.yml up -d

# Testar aplicações e gerar traces
curl http://localhost/api/users
curl http://localhost/api/orders
curl http://localhost/api/products
```

#### 3. Configurar Data Sources no Grafana
1. **Loki**: `http://loki:3100`
2. **Prometheus**: `http://prometheus:9090`
3. **Jaeger**: `http://jaeger-query:16686`

#### 4. Consultas básicas para correlação

##### Traces no Jaeger
- Service: `frontend-service`
- Operation: `GET /api/users`
- Tags: `http.status_code=200`

##### Logs correlacionados no Loki
```logql
{job="frontend"} |= "trace_id"
{job="backend"} |= "span_id"
```

##### Métricas correlacionadas no Prometheus
```promql
http_requests_total{service="frontend"}
http_request_duration_seconds{service="backend"}
```

## Teoria Abordada

### Aula 07 - Kubernetes
- **Conceitos de observabilidade em ambientes orquestrados**: Importância do monitoramento nativo em Kubernetes
- **Prometheus Operator**: Gerenciamento declarativo de recursos de monitoramento
- **ServiceMonitor e PodMonitor**: Descoberta automática de targets de métricas
- **Coleta de métricas de aplicações, pods e nodes**: Estratégias de instrumentação em Kubernetes
- **Integração com Grafana e Loki**: Observabilidade unificada em ambientes cloud-native
- **Boas práticas de deployment**: Padrões para observabilidade em produção

### Aula 05 - Docker Compose (Legado)
- **Conceitos de tracing distribuído**: Importância do rastreamento em arquiteturas de microserviços
- **Spans, traces e contexto de requisição**: Estrutura fundamental do tracing distribuído
- **Sampling e instrumentação de serviços**: Estratégias para coleta eficiente de traces
- **Arquitetura Jaeger**: Componentes (collector, agent, query e UI) e suas funções
- **Diagnóstico de latência e gargalos**: Identificação e resolução de problemas de performance
- **Correlação com logs e métricas**: Observabilidade completa com os três pilares
- **Jaeger Client Libraries**: Instrumentação nativa para controle total sobre tracing
- **Estratégias de sampling**: Balanceamento entre visibilidade e overhead
- **Context propagation**: Propagação de contexto entre serviços distribuídos