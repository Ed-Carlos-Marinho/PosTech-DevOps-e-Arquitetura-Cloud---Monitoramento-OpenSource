# Scripts de Automação EKS

Este diretório contém scripts para automatizar a criação e gerenciamento do cluster EKS para a Aula 07 de Observabilidade no Kubernetes.

## Scripts Disponíveis

### 🚀 `create-eks-cluster.sh`
Script completo para criação automatizada do cluster EKS com todos os add-ons necessários.

**Recursos criados:**
- Cluster EKS com OIDC habilitado
- Node group com instâncias Spot (economia de custos)
- EBS CSI Driver (para volumes persistentes)
- EFS CSI Driver (para volumes compartilhados)
- AWS Load Balancer Controller (para ALB/NLB)
- Storage classes otimizadas (gp3)
- IAM roles e service accounts necessárias

**Nota:** O Metrics Server será instalado separadamente via Helm usando `helm-values/metrics-server/values.yaml`

**Uso básico:**
```bash
./scripts/create-eks-cluster.sh
```

**Uso com parâmetros customizados:**
```bash
# Definir variáveis de ambiente
export CLUSTER_NAME="meu-cluster"
export REGION="us-west-2"
export INSTANCE_TYPE="t3.large"
export DESIRED_SIZE="4"

./scripts/create-eks-cluster.sh
```

**Parâmetros configuráveis:**
- `CLUSTER_NAME` (padrão: observability-lab-cluster)
- `REGION` (padrão: us-east-2)
- `NODE_GROUP_NAME` (padrão: worker-nodes)
- `INSTANCE_TYPE` (padrão: t3.medium)
- `MIN_SIZE` (padrão: 2)
- `MAX_SIZE` (padrão: 6)
- `DESIRED_SIZE` (padrão: 3)
- `KUBERNETES_VERSION` (padrão: 1.34)

### 🗑️ `delete-eks-cluster.sh`
Script para limpeza completa do cluster EKS e todos os recursos associados.

**Recursos removidos:**
- Cluster EKS e node groups
- Load Balancers criados pelo ALB Controller
- Add-ons do EKS
- IAM roles criadas
- Service accounts e recursos Kubernetes

**Uso:**
```bash
./scripts/delete-eks-cluster.sh
```

**⚠️ ATENÇÃO:** Este script remove PERMANENTEMENTE todos os recursos. Confirme digitando 'DELETE' quando solicitado.

## Pré-requisitos

### Ferramentas Necessárias
- **AWS CLI v2** - Configurado com credenciais válidas
- **eksctl** - Será instalado automaticamente se não estiver presente
- **kubectl** - Será instalado automaticamente se não estiver presente
- **helm** - Necessário para AWS Load Balancer Controller
- **jq** - Para processamento JSON (geralmente já instalado)

### Permissões AWS Necessárias
Sua conta AWS deve ter as seguintes permissões:

**EKS:**
- `eks:*`

**EC2:**
- `ec2:*`

**IAM:**
- `iam:CreateRole`
- `iam:AttachRolePolicy`
- `iam:CreateServiceLinkedRole`
- `iam:CreateInstanceProfile`
- `iam:TagRole`

**CloudFormation:**
- `cloudformation:*`

**Auto Scaling:**
- `autoscaling:*`

### Configuração AWS CLI
```bash
# Configurar credenciais
aws configure

# Verificar configuração
aws sts get-caller-identity
```

## Exemplos de Uso

### Cenário 1: Cluster para Desenvolvimento
```bash
export CLUSTER_NAME="dev-observability"
export INSTANCE_TYPE="t3.small"
export DESIRED_SIZE="2"
export REGION="us-east-2"

./scripts/create-eks-cluster.sh
```

### Cenário 2: Cluster para Produção
```bash
export CLUSTER_NAME="prod-observability"
export INSTANCE_TYPE="t3.large"
export MIN_SIZE="3"
export MAX_SIZE="10"
export DESIRED_SIZE="5"
export REGION="us-west-2"

./scripts/create-eks-cluster.sh
```

### Cenário 3: Cluster Multi-AZ
```bash
export CLUSTER_NAME="multi-az-cluster"
export REGION="eu-west-1"
export DESIRED_SIZE="6"  # 2 nodes por AZ

./scripts/create-eks-cluster.sh
```

## Verificação Pós-Criação

Após executar o script de criação, verifique se tudo está funcionando:

```bash
# Verificar nodes
kubectl get nodes -o wide

# Verificar add-ons
aws eks list-addons --cluster-name observability-lab-cluster

# Verificar storage classes
kubectl get storageclass

# Verificar pods do sistema (exceto metrics-server que será instalado via Helm)
kubectl get pods -n kube-system

# Testar criação de volume
kubectl apply -f - <<EOF
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: test-pvc
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 1Gi
  storageClassName: gp3
EOF

kubectl get pvc test-pvc
kubectl delete pvc test-pvc
```

## Troubleshooting

### Problema: Script falha na criação do cluster
**Solução:** Verificar se as credenciais AWS têm as permissões necessárias:
```bash
aws sts get-caller-identity
aws iam get-user
```

### Problema: Add-ons não são instalados
**Solução:** Verificar se o OIDC provider foi criado corretamente:
```bash
aws eks describe-cluster --name observability-lab-cluster --query "cluster.identity.oidc.issuer"
```

### Problema: Load Balancer Controller não funciona
**Solução:** Verificar se o service account tem as permissões corretas:
```bash
kubectl describe sa aws-load-balancer-controller -n kube-system
```

### Problema: Volumes EBS não são criados
**Solução:** Verificar se o EBS CSI Driver está funcionando:
```bash
kubectl get pods -n kube-system | grep ebs-csi
kubectl logs -n kube-system deployment/ebs-csi-controller
```

## Custos Estimados

| Recurso | Configuração Padrão | Custo/hora (aprox.) |
|---------|-------------------|-------------------|
| EKS Control Plane | Managed | $0.10 |
| Worker Nodes | 3x t3.medium spot | $0.14 |
| EBS Volumes | 3x 30GB gp3 | $0.01 |
| Load Balancers | Conforme uso | Variável |
| **Total Base** | | **~$0.25/hora** |

💡 **Dicas de economia:**
- Use instâncias Spot (já configurado por padrão)
- Termine o cluster quando não estiver usando
- Use storage gp3 ao invés de gp2 (já configurado)
- Configure auto-scaling para reduzir nodes em horários de baixo uso

## Logs e Debugging

### Logs do Script
Os scripts geram logs detalhados com timestamps e códigos de cores para facilitar o debugging.

### Logs do EKS
```bash
# Logs do control plane (se habilitado)
aws logs describe-log-groups --log-group-name-prefix "/aws/eks/observability-lab-cluster"

# Logs dos nodes
kubectl logs -n kube-system daemonset/aws-node
kubectl logs -n kube-system deployment/coredns
```

### Eventos do Cluster
```bash
# Eventos recentes
kubectl get events --sort-by='.lastTimestamp' -A

# Eventos de um namespace específico
kubectl get events -n kube-system --sort-by='.lastTimestamp'
```

## Próximos Passos

Após criar o cluster com sucesso:

1. **Seguir Documentação de Deploy:**
   ```bash
   # Consultar guia completo
   cat docs/deploy-observability-stack.md
   ```

2. **Instalar Metrics Server:**
   ```bash
   helm repo add metrics-server https://kubernetes-sigs.github.io/metrics-server/
   helm install metrics-server metrics-server/metrics-server -n kube-system -f helm-values/metrics-server/values.yaml
   ```

3. **Instalar Stack de Observabilidade:**
   ```bash
   # Seguir passo a passo na documentação
   # docs/deploy-observability-stack.md
   ```

4. **Executar Exercícios:**
   ```bash
   cd exercises/01-deploy-prometheus-stack
   ```

5. **Acessar Grafana:**
   ```bash
   kubectl get svc -n monitoring grafana
   # Acessar via LoadBalancer URL
   ```