# Setup do Laboratório EKS - Observabilidade no Kubernetes

Guia completo para configurar o ambiente de laboratório da Aula 07, incluindo criação manual do cluster EKS e instância EC2 bastion.

## Arquitetura do Laboratório

```
┌─────────────────────────────────────────────────────────────┐
│                        AWS Account                          │
│                                                             │
│  ┌─────────────────┐    ┌─────────────────────────────────┐ │
│  │   EC2 Bastion   │    │         EKS Cluster             │ │
│  │                 │    │                                 │ │
│  │ • kubectl       │────│ • Prometheus Operator          │ │
│  │ • helm          │    │ • Grafana                       │ │
│  │ • AWS CLI       │    │ • Loki                          │ │
│  │ • code-server   │    │ • Demo Applications             │ │
│  │ • k9s           │    │ • ServiceMonitor/PodMonitor     │ │
│  └─────────────────┘    └─────────────────────────────────┘ │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

## Pré-requisitos

- Conta AWS com permissões administrativas
- AWS CLI configurado localmente (opcional)
- Key pair AWS criado
- Conhecimento básico de AWS Console

## Passo 1: Criar IAM Roles Necessárias

### 1.1 Role para EKS Cluster

1. **IAM Console** → **Roles** → **Create role**
2. **Trusted entity**: AWS service → EKS → EKS - Cluster
3. **Permissions**: `AmazonEKSClusterPolicy` (já anexada automaticamente)
4. **Role name**: `EKSClusterRole-ObservabilityLab`
5. **Create role**

### 1.2 Role para EKS Node Group

1. **IAM Console** → **Roles** → **Create role**
2. **Trusted entity**: AWS service → EC2
3. **Permissions**: Anexar as seguintes policies:
   - `AmazonEKSWorkerNodePolicy`
   - `AmazonEKS_CNI_Policy`
   - `AmazonEC2ContainerRegistryReadOnly`
4. **Role name**: `EKSNodeGroupRole-ObservabilityLab`
5. **Create role**

### 1.3 Role para Instância Bastion

1. **IAM Console** → **Roles** → **Create role**
2. **Trusted entity**: AWS service → EC2
3. **Permissions**: Anexar as seguintes policies:
   - `AmazonEKSClusterPolicy`
   - `AmazonEKSWorkerNodePolicy`
   - `AmazonSSMManagedInstanceCore`
4. **Role name**: `BastionRole-ObservabilityLab`
5. **Create role**

## Passo 2: Criar Cluster EKS

### 2.1 Via Console AWS (Recomendado)

1. **EKS Console** → **Clusters** → **Create cluster**

2. **Step 1: Configure cluster**
   - **Name**: `observability-lab-cluster`
   - **Kubernetes version**: `1.28`
   - **Cluster service role**: `EKSClusterRole-ObservabilityLab`
   - **Next**

3. **Step 2: Specify networking**
   - **VPC**: Default VPC (ou criar nova se preferir)
   - **Subnets**: Selecionar pelo menos 2 subnets em AZs diferentes
   - **Security groups**: Default (será criado automaticamente)
   - **Cluster endpoint access**: Public and private
   - **Next**

4. **Step 3: Configure observability**
   - **Control plane logging**: Habilitar todos os tipos (opcional)
   - **Next**

5. **Step 4: Select add-ons**
   - Manter add-ons padrão: CoreDNS, kube-proxy, Amazon VPC CNI
   - **Next**

6. **Step 5: Review and create**
   - Revisar configurações
   - **Create**

⏱️ **Aguardar**: O cluster levará cerca de 10-15 minutos para ser criado.

### 2.2 Via AWS CLI (Alternativo)

```bash
# Criar cluster
aws eks create-cluster \
  --name observability-lab-cluster \
  --version 1.28 \
  --role-arn arn:aws:iam::$(aws sts get-caller-identity --query Account --output text):role/EKSClusterRole-ObservabilityLab \
  --resources-vpc-config subnetIds=$(aws ec2 describe-subnets --filters "Name=default-for-az,Values=true" --query "Subnets[0:2].SubnetId" --output text | tr '\t' ',')

# Aguardar cluster ficar ativo
aws eks wait cluster-active --name observability-lab-cluster
```

## Passo 3: Criar Node Group

### 3.1 Via Console AWS

1. **EKS Console** → **Clusters** → **observability-lab-cluster** → **Compute** → **Add node group**

2. **Step 1: Configure node group**
   - **Name**: `worker-nodes`
   - **Node IAM role**: `EKSNodeGroupRole-ObservabilityLab`
   - **Next**

3. **Step 2: Set compute and scaling configuration**
   - **AMI type**: Amazon Linux 2 (AL2_x86_64)
   - **Capacity type**: Spot (para economia)
   - **Instance types**: t3.medium
   - **Disk size**: 30 GiB
   - **Scaling configuration**:
     - **Minimum size**: 2
     - **Maximum size**: 6
     - **Desired size**: 3
   - **Next**

4. **Step 3: Specify networking**
   - **Subnets**: Selecionar subnets privadas (se disponíveis) ou públicas
   - **Next**

5. **Step 4: Review and create**
   - **Create**

⏱️ **Aguardar**: O node group levará cerca de 5-10 minutos para ser criado.

### 3.2 Via AWS CLI (Alternativo)

```bash
# Criar node group
aws eks create-nodegroup \
  --cluster-name observability-lab-cluster \
  --nodegroup-name worker-nodes \
  --instance-types t3.medium \
  --capacity-type SPOT \
  --scaling-config minSize=2,maxSize=6,desiredSize=3 \
  --disk-size 30 \
  --node-role arn:aws:iam::$(aws sts get-caller-identity --query Account --output text):role/EKSNodeGroupRole-ObservabilityLab \
  --subnets $(aws ec2 describe-subnets --filters "Name=default-for-az,Values=true" --query "Subnets[0:2].SubnetId" --output text | tr '\t' ' ')

# Aguardar node group ficar ativo
aws eks wait nodegroup-active --cluster-name observability-lab-cluster --nodegroup-name worker-nodes
```

## Passo 4: Criar Instância EC2 Bastion

### 4.1 Via Console AWS

1. **EC2 Console** → **Launch Instance**

2. **Name and tags**
   - **Name**: `eks-bastion-observability-lab`

3. **Application and OS Images**
   - **AMI**: Ubuntu Server 22.04 LTS (Free tier eligible)

4. **Instance type**
   - **Instance type**: t3.medium

5. **Key pair**
   - **Key pair name**: Selecionar seu key pair existente

6. **Network settings**
   - **VPC**: Mesma VPC do cluster EKS
   - **Subnet**: Subnet pública
   - **Auto-assign public IP**: Enable
   - **Security group**: Create new
     - **Security group name**: `bastion-sg-observability-lab`
     - **Rules**:
       - SSH (22) - Source: My IP (ou 0.0.0.0/0 se necessário)
       - Custom TCP (8080) - Source: My IP (code-server)

7. **Configure storage**
   - **Size**: 30 GiB gp3

8. **Advanced details**
   - **IAM instance profile**: `BastionRole-ObservabilityLab`
   - **User data**: Cole o conteúdo completo do arquivo `ec2-userdata-eks-bastion.sh`

9. **Launch instance**

⏱️ **Aguardar**: A instância levará cerca de 5-10 minutos para inicializar completamente.

## Passo 5: Verificar e Configurar Acesso

### 5.1 Verificar Status do Cluster

```bash
# Via AWS CLI local (se configurado)
aws eks describe-cluster --name observability-lab-cluster --query cluster.status

# Verificar nodes
aws eks describe-nodegroup --cluster-name observability-lab-cluster --nodegroup-name worker-nodes --query nodegroup.status
```

### 5.2 Conectar na Instância Bastion

```bash
# Via SSH
ssh -i sua-chave.pem ubuntu@BASTION_PUBLIC_IP

# Via Session Manager (recomendado)
aws ssm start-session --target INSTANCE_ID
```

### 5.3 Verificar Inicialização da Instância

```bash
# Verificar logs de inicialização
sudo tail -f /var/log/user-data.log

# Aguardar até ver a mensagem de conclusão
# "=== ✅ Configuração do bastion EKS concluída em..."
```

### 5.4 Configurar Acesso ao EKS

```bash
# Na instância bastion
./configure-eks-access.sh observability-lab-cluster us-east-2

# Verificar acesso
kubectl get nodes
kubectl get namespaces

# Verificar pré-requisitos
./check-prerequisites.sh
```

## Passo 6: Validação do Ambiente

### 6.1 Verificar Cluster EKS

```bash
# Informações do cluster
kubectl cluster-info

# Verificar nodes
kubectl get nodes -o wide

# Verificar system pods
kubectl get pods -n kube-system
```

### 6.2 Verificar Ferramentas

```bash
# Versões das ferramentas
aws --version
kubectl version --client
helm version

# Repositórios Helm
helm repo list

# Testar k9s (interface TUI)
k9s
```

### 6.3 Verificar Code-server

```bash
# Status do serviço
sudo systemctl status code-server

# Acessar via browser
# http://BASTION_PUBLIC_IP:8080
# Senha: demo123
```

## Passo 7: Próximos Passos

Com o ambiente configurado, você pode prosseguir para:

1. **Deploy da Stack de Observabilidade**
   ```bash
   # Consultar documentação detalhada
   cat docs/deploy-observability-stack.md
   
   # Seguir passo a passo para instalação manual
   ```

2. **Exercícios Práticos**
   ```bash
   cd exercises/01-deploy-prometheus-stack
   cat README.md
   ```

3. **Explorar o Ambiente**
   ```bash
   # Interface TUI para Kubernetes
   k9s
   
   # Navegar pelos materiais
   cd lab-materials
   tree
   ```

## Troubleshooting

### Problema: Cluster EKS não consegue criar nodes

**Solução**: Verificar se as subnets têm tags corretas:
- `kubernetes.io/cluster/observability-lab-cluster = shared`

### Problema: Instância bastion não consegue acessar EKS

**Solução**: Verificar IAM role da instância tem as políticas corretas:
- `AmazonEKSClusterPolicy`
- `AmazonEKSWorkerNodePolicy`

### Problema: Code-server não está acessível

**Solução**: Verificar security group permite porta 8080:
```bash
# Verificar status do serviço
sudo systemctl status code-server

# Verificar se está ouvindo na porta
sudo netstat -tlnp | grep 8080
```

### Problema: kubectl não consegue conectar

**Solução**: Reconfigurar kubeconfig:
```bash
./configure-eks-access.sh observability-lab-cluster us-east-2
```

## Custos Estimados

| Recurso | Tipo | Custo/hora (aprox.) |
|---------|------|-------------------|
| EKS Cluster | Managed | $0.10 |
| Worker Nodes | 3x t3.medium spot | $0.14 |
| Bastion | t3.medium spot | $0.05 |
| **Total** | | **~$0.29/hora** |

💡 **Dica**: Para economizar, termine as instâncias quando não estiver usando o laboratório.

## Limpeza do Ambiente

Quando terminar o laboratório:

1. **Deletar Node Group**
   ```bash
   aws eks delete-nodegroup --cluster-name observability-lab-cluster --nodegroup-name worker-nodes
   ```

2. **Deletar Cluster EKS**
   ```bash
   aws eks delete-cluster --name observability-lab-cluster
   ```

3. **Terminar Instância EC2**
   - Via Console AWS: EC2 → Instances → Terminate

4. **Deletar IAM Roles** (opcional)
   - Via Console AWS: IAM → Roles → Delete