# Deploy da Stack de Observabilidade - Passo a Passo

Guia completo para implementar a stack de observabilidade no Kubernetes usando Helm com SSL/TLS automático via Let's Encrypt.

## Arquitetura da Stack

```
┌─────────────────────────────────────────────────────────────────┐
│                    EKS CLUSTER                                  │
│                                                                 │
│  ┌─────────────────┐  ┌─────────────────┐  ┌─────────────────┐ │
│  │   MONITORING    │  │   CERT-MANAGER  │  │   INGRESS-NGINX │ │
│  │   NAMESPACE     │  │   NAMESPACE     │  │   NAMESPACE     │ │
│  │                 │  │                 │  │                 │ │
│  │ • Prometheus    │  │ • cert-manager  │  │ • Ingress       │ │
│  │ • Grafana       │  │ • ClusterIssuer │  │   Controller    │ │
│  │ • Node Exporter │  │ • Let's Encrypt │  │ • NLB           │ │
│  │ • Loki          │  │                 │  │                 │ │
│  │ • Promtail      │  │                 │  │                 │ │
│  └─────────────────┘  └─────────────────┘  └─────────────────┘ │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

## Pré-requisitos

### 1. Cluster EKS Criado
```bash
# Executar script de criação do cluster
./scripts/create-eks-cluster.sh

# Verificar se o cluster está funcionando
kubectl get nodes
kubectl cluster-info

# Verificar add-ons AWS
aws eks list-addons --cluster-name observability-lab-cluster
```

### 2. Helm Instalado
```bash
# Verificar versão do Helm
helm version

# Se não estiver instalado
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
```

### 3. Repositórios Helm Necessários
```bash
# Adicionar repositórios
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo add grafana https://grafana.github.io/helm-charts
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm repo add jetstack https://charts.jetstack.io

# Atualizar repositórios
helm repo update

# Verificar repositórios
helm repo list
```

## Passo 1: Instalar Ingress NGINX Controller

O Ingress Controller permite expor serviços HTTP/HTTPS com roteamento avançado e Load Balancer da AWS.

```bash
# Instalar Ingress NGINX
helm install ingress-nginx ingress-nginx/ingress-nginx \
  --namespace ingress-nginx \
  --create-namespace \
  --values helm-values/ingress-nginx/values.yaml \
  --wait \
  --timeout 10m

# Verificar instalação
kubectl get pods -n ingress-nginx

# Verificar LoadBalancer (aguardar External IP)
kubectl get svc -n ingress-nginx ingress-nginx-controller -w
```

**Configurações importantes:**
- **Service Type**: LoadBalancer com Network Load Balancer (NLB) da AWS
- **Métricas**: Habilitadas para Prometheus
- **Logs**: Formato JSON estruturado para observabilidade
- **Recursos**: Otimizados (CPU: 100m-200m, Memory: 90Mi-256Mi)
- **Réplicas**: 2 para alta disponibilidade

## Passo 2: Instalar cert-manager

O cert-manager automatiza a criação e renovação de certificados SSL/TLS via Let's Encrypt.

```bash
# Instalar cert-manager
helm install cert-manager jetstack/cert-manager \
  --namespace cert-manager \
  --create-namespace \
  --values helm-values/cert-manager/values.yaml \
  --wait \
  --timeout 10m

# Verificar instalação
kubectl get pods -n cert-manager

# Aplicar ClusterIssuers
kubectl apply -f helm-values/cert-manager/cluster-issuer.yaml

# Verificar ClusterIssuers
kubectl get clusterissuer
```

**Componentes instalados:**
- **cert-manager**: Controller principal
- **cert-manager-webhook**: Validação de recursos
- **cert-manager-cainjector**: Injeção de CA
- **ClusterIssuer**: Configuração para Let's Encrypt (prod e staging)

## Passo 3: Instalar kube-prometheus-stack

Esta é a peça central da observabilidade, incluindo Prometheus, Grafana com SSL automático.

```bash
# Instalar kube-prometheus-stack
helm install kube-prometheus-stack prometheus-community/kube-prometheus-stack \
  --namespace monitoring \
  --create-namespace \
  --values helm-values/kube-prometheus-stack/values.yaml \
  --wait \
  --timeout 15m

# Verificar instalação
kubectl get pods -n monitoring

# Verificar Ingresses e certificados
kubectl get ingress -n monitoring
kubectl get certificates -n monitoring
```

**Componentes instalados:**
- **Prometheus**: Coleta de métricas com retenção de 7 dias
- **Grafana**: Interface de visualização com SSL (admin/admin123)
- **Node Exporter**: Métricas dos nodes (DaemonSet)
- **Kube State Metrics**: Métricas dos recursos Kubernetes
- **Prometheus Operator**: Gerenciamento declarativo

**Configurações importantes:**
- **Ingress SSL**: Certificados automáticos via Let's Encrypt
- **Domínios**: grafana.demo.lynxnetwork.com.br e prometheus.demo.lynxnetwork.com.br
- **Storage**: Volumes persistentes (Prometheus: 20GB, Grafana: 10GB)
- **Datasource Loki**: Pré-configurado para integração

## Passo 4: Instalar Loki Stack

Loki fornece agregação de logs otimizada para Kubernetes com recursos reduzidos.

```bash
# Instalar Loki
helm install loki grafana/loki \
  --namespace monitoring \
  --values helm-values/loki-stack/values.yaml \
  --wait \
  --timeout 10m

# Instalar Promtail
helm install promtail grafana/promtail \
  --namespace monitoring \
  --values helm-values/loki-stack/promtail-values.yaml \
  --wait \
  --timeout 10m

# Verificar instalação
kubectl get pods -n monitoring -l app.kubernetes.io/name=loki
kubectl get pods -n monitoring -l app.kubernetes.io/name=promtail
```

**Componentes instalados:**
- **Loki**: Servidor de agregação de logs (SingleBinary mode)
- **Promtail**: Agente de coleta de logs (DaemonSet em todos os nodes)

**Configurações importantes:**
- **Recursos otimizados**: Loki (64Mi-128Mi), Promtail (64Mi-128Mi)
- **Storage**: Volume persistente de 5GB para Loki
- **Retenção**: 7 dias de logs
- **Coleta automática**: Logs de todos os pods Kubernetes
- **Integração**: Datasource pré-configurado no Grafana

## Passo 5: Configurar DNS

Para acessar via domínios personalizados, configure os registros DNS:

```bash
# Obter hostname do Load Balancer
LOAD_BALANCER=$(kubectl get svc -n ingress-nginx ingress-nginx-controller -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
echo "Load Balancer: $LOAD_BALANCER"
```

**Registros DNS necessários:**
```
grafana.demo.lynxnetwork.com.br     CNAME   <LOAD_BALANCER_HOSTNAME>
prometheus.demo.lynxnetwork.com.br  CNAME   <LOAD_BALANCER_HOSTNAME>
```

## Verificação da Instalação

### 1. Verificar Todos os Pods
```bash
# Pods de monitoramento
kubectl get pods -n monitoring

# Pods do ingress
kubectl get pods -n ingress-nginx

# Pods do cert-manager
kubectl get pods -n cert-manager
```

### 2. Verificar Certificados SSL
```bash
# Verificar certificados
kubectl get certificates -n monitoring

# Verificar secrets TLS
kubectl get secrets -n monitoring | grep tls

# Testar certificados
curl -I https://grafana.demo.lynxnetwork.com.br
curl -I https://prometheus.demo.lynxnetwork.com.br
```

### 3. Verificar ServiceMonitors
```bash
# Listar ServiceMonitors
kubectl get servicemonitor -n monitoring

# Verificar targets no Prometheus
# Acessar: https://prometheus.demo.lynxnetwork.com.br/targets
```

## Acessar as Interfaces

### 1. Grafana (HTTPS com SSL)
```bash
# URL: https://grafana.demo.lynxnetwork.com.br
# Credenciais: admin / admin123
```

**Datasources pré-configurados:**
- **Prometheus**: Métricas do cluster
- **Loki**: Logs agregados

### 2. Prometheus (HTTPS com SSL)
```bash
# URL: https://prometheus.demo.lynxnetwork.com.br
```

## Dashboards Disponíveis

O kube-prometheus-stack inclui 27+ dashboards automáticos:

### Dashboards Kubernetes
- **Kubernetes / Compute Resources / Cluster**
- **Kubernetes / Compute Resources / Namespace (Pods)**
- **Kubernetes / Compute Resources / Node (Pods)**
- **Kubernetes / Compute Resources / Pod**

### Dashboards de Infraestrutura
- **Node Exporter / Nodes**
- **Prometheus / Overview**
- **Grafana / Overview**

### Dashboards de Rede
- **Kubernetes / Networking / Cluster**
- **Kubernetes / Networking / Namespace (Pods)**

## Testar a Stack de Observabilidade

### 1. Verificar Métricas
```bash
# Métricas de nodes
kubectl top nodes

# Métricas de pods
kubectl top pods -A

# Acessar Prometheus
open https://prometheus.demo.lynxnetwork.com.br
```

### 2. Verificar Logs
```bash
# Logs do Loki
kubectl logs -n monitoring loki-0

# Logs do Promtail
kubectl logs -n monitoring -l app.kubernetes.io/name=promtail

# Acessar Grafana → Explore → Loki
# Consulta exemplo: {namespace="kube-system"}
```

### 3. Verificar SSL/TLS
```bash
# Testar certificados
openssl s_client -connect grafana.demo.lynxnetwork.com.br:443 -servername grafana.demo.lynxnetwork.com.br

# Verificar redirecionamento HTTPS
curl -I http://grafana.demo.lynxnetwork.com.br
```

## Troubleshooting

### Problema: Certificados não são criados
```bash
# Verificar cert-manager logs
kubectl logs -n cert-manager deployment/cert-manager

# Verificar challenges
kubectl get challenges -A

# Verificar orders
kubectl get orders -A

# Verificar ClusterIssuer
kubectl describe clusterissuer letsencrypt-prod
```

### Problema: Pods em Pending (Recursos Insuficientes)
```bash
# Verificar eventos
kubectl get events -n monitoring --sort-by='.lastTimestamp'

# Verificar recursos dos nodes
kubectl describe nodes

# Reduzir recursos nos values files se necessário
```

### Problema: Loki não recebe logs
```bash
# Verificar Promtail
kubectl logs -n monitoring -l app.kubernetes.io/name=promtail

# Verificar conectividade
kubectl exec -n monitoring -l app.kubernetes.io/name=promtail -- nslookup loki.monitoring.svc.cluster.local

# Testar endpoint do Loki
kubectl exec -n monitoring loki-0 -- wget -qO- http://localhost:3100/ready
```

### Problema: Grafana não carrega dashboards
```bash
# Verificar sidecar
kubectl logs -n monitoring -l app.kubernetes.io/name=grafana -c grafana-sc-dashboard

# Verificar ConfigMaps de dashboards
kubectl get configmaps -n monitoring -l grafana_dashboard=1
```

## Comandos Úteis

### Helm
```bash
# Listar releases
helm list -A

# Status de um release
helm status kube-prometheus-stack -n monitoring

# Upgrade de um release
helm upgrade kube-prometheus-stack prometheus-community/kube-prometheus-stack \
  -n monitoring \
  -f helm-values/kube-prometheus-stack/values.yaml

# Rollback
helm rollback kube-prometheus-stack 1 -n monitoring
```

### Certificados
```bash
# Forçar renovação de certificado
kubectl delete certificate grafana-demo-lynxnetwork-tls -n monitoring

# Verificar logs do cert-manager
kubectl logs -n cert-manager deployment/cert-manager -f
```

### Loki
```bash
# Testar API do Loki
kubectl port-forward -n monitoring svc/loki 3100:3100
curl http://localhost:3100/ready

# Consultar logs via API
curl "http://localhost:3100/loki/api/v1/query_range" \
  --data-urlencode 'query={namespace="monitoring"}' \
  --data-urlencode 'start=1h' | jq
```

## Estrutura de Arquivos

```
helm-values/
├── cert-manager/
│   ├── values.yaml           # Configuração do cert-manager
│   └── cluster-issuer.yaml   # ClusterIssuers Let's Encrypt
├── ingress-nginx/
│   └── values.yaml           # Configuração do Ingress Controller
├── kube-prometheus-stack/
│   └── values.yaml           # Prometheus + Grafana com Ingress SSL
└── loki-stack/
    ├── values.yaml           # Configuração do Loki
    └── promtail-values.yaml  # Configuração do Promtail
```

## Resumo dos Recursos Criados

| Componente | Namespace | Acesso | URL |
|------------|-----------|---------|-----|
| Grafana | monitoring | HTTPS | https://grafana.demo.lynxnetwork.com.br |
| Prometheus | monitoring | HTTPS | https://prometheus.demo.lynxnetwork.com.br |
| Loki | monitoring | Interno | http://loki.monitoring.svc.cluster.local:3100 |
| cert-manager | cert-manager | Interno | - |
| Ingress NGINX | ingress-nginx | Load Balancer | NLB da AWS |

## Estimativa de Recursos (Otimizada)

| Componente | CPU Request | Memory Request | Storage |
|------------|-------------|----------------|---------|
| Prometheus | 500m | 1Gi | 20Gi |
| Grafana | 100m | 256Mi | 10Gi |
| Loki | 25m | 64Mi | 5Gi |
| Promtail | 25m × 3 | 64Mi × 3 | - |
| cert-manager | 10m × 3 | 32Mi × 3 | - |
| Ingress NGINX | 100m × 2 | 90Mi × 2 | - |
| **Total** | **~1 CPU** | **~2Gi** | **35Gi** |

## Próximos Passos

Após a instalação completa:

1. **Configurar DNS** nos seus provedores
2. **Explorar Dashboards** no Grafana
3. **Criar Alertas Customizados**
4. **Monitorar Aplicações** com ServiceMonitors
5. **Analisar Logs** com Loki no Grafana

A stack está otimizada para ambientes de laboratório com SSL automático e pode ser facilmente escalada para produção ajustando os resources nos values files.