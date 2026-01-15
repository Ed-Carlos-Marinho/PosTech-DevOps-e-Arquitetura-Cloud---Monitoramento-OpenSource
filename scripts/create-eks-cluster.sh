#!/bin/bash

# =============================================================================
# EKS CLUSTER CREATION SCRIPT
# =============================================================================
# Aula 07 - PosTech DevOps - Observabilidade no Kubernetes
# Script para criação automatizada do cluster EKS com add-ons essenciais
# =============================================================================

set -e  # Exit on any error

# Desabilitar pager do AWS CLI
export AWS_PAGER=""

# Configurações padrão (podem ser sobrescritas via variáveis de ambiente)
CLUSTER_NAME="${CLUSTER_NAME:-observability-lab-cluster}"
REGION="${REGION:-us-east-2}"
NODE_GROUP_NAME="${NODE_GROUP_NAME:-worker-nodes}"
INSTANCE_TYPE="${INSTANCE_TYPE:-t3.medium}"
MIN_SIZE="${MIN_SIZE:-2}"
MAX_SIZE="${MAX_SIZE:-6}"
DESIRED_SIZE="${DESIRED_SIZE:-3}"
KUBERNETES_VERSION="${KUBERNETES_VERSION:-1.34}"

# Cores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Função de log
log() {
    echo -e "${BLUE}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} $1"
}

success() {
    echo -e "${GREEN}✅ $1${NC}"
}

warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

error() {
    echo -e "${RED}❌ $1${NC}"
    exit 1
}

# Função de verificação
check_prerequisites() {
    log "Verificando pré-requisitos..."
    
    # Verificar AWS CLI
    if ! command -v aws &> /dev/null; then
        error "AWS CLI não encontrado. Instale o AWS CLI v2."
    fi
    
    # Verificar eksctl
    if ! command -v eksctl &> /dev/null; then
        warning "eksctl não encontrado. Instalando..."
        install_eksctl
    fi
    
    # Verificar kubectl
    if ! command -v kubectl &> /dev/null; then
        warning "kubectl não encontrado. Instalando..."
        install_kubectl
    fi
    
    # Verificar jq
    if ! command -v jq &> /dev/null; then
        warning "jq não encontrado. Instalando..."
        install_jq
    fi
    # Verificar credenciais AWS
    if ! aws sts get-caller-identity &> /dev/null; then
        error "Credenciais AWS não configuradas. Execute 'aws configure'."
    fi
}

# Instalar jq
install_jq() {
    log "Instalando jq..."
    if [[ "$OSTYPE" == "darwin"* ]]; then
        # macOS
        if command -v brew &> /dev/null; then
            brew install jq
        else
            curl -L https://github.com/stedolan/jq/releases/latest/download/jq-osx-amd64 -o /tmp/jq
            sudo mv /tmp/jq /usr/local/bin/jq
            sudo chmod +x /usr/local/bin/jq
        fi
    else
        # Linux
        curl -L https://github.com/stedolan/jq/releases/latest/download/jq-linux64 -o /tmp/jq
        sudo mv /tmp/jq /usr/local/bin/jq
        sudo chmod +x /usr/local/bin/jq
    fi
    success "jq instalado"
}

# Instalar eksctl
install_eksctl() {
    log "Instalando eksctl..."
    curl --silent --location "https://github.com/weaveworks/eksctl/releases/latest/download/eksctl_$(uname -s)_amd64.tar.gz" | tar xz -C /tmp
    sudo mv /tmp/eksctl /usr/local/bin
    success "eksctl instalado"
}

# Instalar kubectl
install_kubectl() {
    log "Instalando kubectl..."
    curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
    sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
    rm kubectl
    success "kubectl instalado"
}

# Criar IAM roles necessárias
create_iam_roles() {
    log "Criando IAM roles necessárias..."
    
    # Role para EKS Cluster
    cat > /tmp/eks-cluster-trust-policy.json << EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "eks.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF

    # Criar role do cluster se não existir
    if ! aws iam get-role --role-name EKSClusterRole-${CLUSTER_NAME} &> /dev/null; then
        aws iam create-role \
            --role-name EKSClusterRole-${CLUSTER_NAME} \
            --assume-role-policy-document file:///tmp/eks-cluster-trust-policy.json
        
        aws iam attach-role-policy \
            --role-name EKSClusterRole-${CLUSTER_NAME} \
            --policy-arn arn:aws:iam::aws:policy/AmazonEKSClusterPolicy
        
        success "Role EKSClusterRole-${CLUSTER_NAME} criada"
    else
        warning "Role EKSClusterRole-${CLUSTER_NAME} já existe"
    fi

    # Role para Node Group
    cat > /tmp/eks-nodegroup-trust-policy.json << EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "ec2.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF

    # Criar role do node group se não existir
    if ! aws iam get-role --role-name EKSNodeGroupRole-${CLUSTER_NAME} &> /dev/null; then
        aws iam create-role \
            --role-name EKSNodeGroupRole-${CLUSTER_NAME} \
            --assume-role-policy-document file:///tmp/eks-nodegroup-trust-policy.json
        
        aws iam attach-role-policy \
            --role-name EKSNodeGroupRole-${CLUSTER_NAME} \
            --policy-arn arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy
        
        aws iam attach-role-policy \
            --role-name EKSNodeGroupRole-${CLUSTER_NAME} \
            --policy-arn arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy
        
        aws iam attach-role-policy \
            --role-name EKSNodeGroupRole-${CLUSTER_NAME} \
            --policy-arn arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly
        
        success "Role EKSNodeGroupRole-${CLUSTER_NAME} criada"
    else
        warning "Role EKSNodeGroupRole-${CLUSTER_NAME} já existe"
    fi
    
    # Cleanup
    rm -f /tmp/eks-cluster-trust-policy.json /tmp/eks-nodegroup-trust-policy.json
}

# Criar cluster EKS
create_eks_cluster() {
    log "Verificando se cluster ${CLUSTER_NAME} já existe..."
    
    if aws eks describe-cluster --name ${CLUSTER_NAME} --region ${REGION} &> /dev/null; then
        warning "Cluster ${CLUSTER_NAME} já existe. Pulando criação..."
        return 0
    fi
    
    log "Criando cluster EKS ${CLUSTER_NAME}..."
    
    # Criar arquivo de configuração do eksctl
    cat > /tmp/cluster-config.yaml << EOF
apiVersion: eksctl.io/v1alpha5
kind: ClusterConfig

metadata:
  name: ${CLUSTER_NAME}
  region: ${REGION}
  version: "${KUBERNETES_VERSION}"

iam:
  withOIDC: true

addons:
  - name: vpc-cni
    version: latest
  - name: coredns
    version: latest
  - name: kube-proxy
    version: latest

nodeGroups:
  - name: ${NODE_GROUP_NAME}
    instanceType: ${INSTANCE_TYPE}
    minSize: ${MIN_SIZE}
    maxSize: ${MAX_SIZE}
    desiredCapacity: ${DESIRED_SIZE}
    volumeSize: 30
    volumeType: gp3
    amiFamily: AmazonLinux2023
    ssh:
      enableSsm: true
    iam:
      attachPolicyARNs:
        - arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy
        - arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy
        - arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly
        - arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore
      withAddonPolicies:
        ebs: true
        efs: true
        albIngress: true
        cloudWatch: true
    tags:
      Environment: lab
      Course: postech-devops
      Class: aula-07

cloudWatch:
  clusterLogging:
    enableTypes: ["*"]
EOF

    # Criar cluster usando eksctl
    eksctl create cluster -f /tmp/cluster-config.yaml
    
    success "Cluster EKS ${CLUSTER_NAME} criado com sucesso"
    
    # Cleanup
    rm -f /tmp/cluster-config.yaml
}

# Configurar kubeconfig
configure_kubeconfig() {
    log "Configurando kubeconfig..."
    aws eks update-kubeconfig --region ${REGION} --name ${CLUSTER_NAME}
    success "Kubeconfig configurado"
}

# Instalar EBS CSI Driver
install_ebs_csi_driver() {
    log "Instalando EBS CSI Driver..."
    
    # Verificar se já está instalado
    if aws eks describe-addon --cluster-name ${CLUSTER_NAME} --region ${REGION} --addon-name aws-ebs-csi-driver &> /dev/null; then
        warning "EBS CSI Driver já está instalado"
        return 0
    fi
    
    # Criar service account para EBS CSI Driver (se não existir)
    if ! kubectl get serviceaccount ebs-csi-controller-sa -n kube-system &> /dev/null; then
        eksctl create iamserviceaccount \
            --name ebs-csi-controller-sa \
            --namespace kube-system \
            --cluster ${CLUSTER_NAME} \
            --region ${REGION} \
            --attach-policy-arn arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy \
            --approve \
            --override-existing-serviceaccounts
        
        # Aguardar um pouco para a role ser criada
        sleep 15
    fi
    
    # Obter ARN da role criada
    ROLE_ARN=$(aws iam list-roles --output json | jq -r '.Roles[] | select(.RoleName | contains("ebs-csi-controller-sa")) | .Arn' | head -1)
    
    if [[ -n "$ROLE_ARN" && "$ROLE_ARN" != "null" ]]; then
        log "Usando role: $ROLE_ARN"
        # Instalar add-on com service account role
        aws eks create-addon \
            --cluster-name ${CLUSTER_NAME} \
            --region ${REGION} \
            --addon-name aws-ebs-csi-driver \
            --service-account-role-arn ${ROLE_ARN} \
            --resolve-conflicts OVERWRITE
    else
        log "Instalando add-on sem role específica"
        # Instalar add-on sem service account role (fallback)
        aws eks create-addon \
            --cluster-name ${CLUSTER_NAME} \
            --region ${REGION} \
            --addon-name aws-ebs-csi-driver \
            --resolve-conflicts OVERWRITE
    fi
    
    # Aguardar add-on ficar ativo
    log "Aguardando EBS CSI Driver ficar ativo..."
    aws eks wait addon-active --cluster-name ${CLUSTER_NAME} --region ${REGION} --addon-name aws-ebs-csi-driver
    
    success "EBS CSI Driver instalado"
}

# Instalar EFS CSI Driver
install_efs_csi_driver() {
    log "Instalando EFS CSI Driver..."
    
    # Verificar se já está instalado
    if aws eks describe-addon --cluster-name ${CLUSTER_NAME} --region ${REGION} --addon-name aws-efs-csi-driver &> /dev/null; then
        warning "EFS CSI Driver já está instalado"
        return 0
    fi
    
    # Criar service account para EFS CSI Driver (se não existir)
    if ! kubectl get serviceaccount efs-csi-controller-sa -n kube-system &> /dev/null; then
        eksctl create iamserviceaccount \
            --name efs-csi-controller-sa \
            --namespace kube-system \
            --cluster ${CLUSTER_NAME} \
            --region ${REGION} \
            --attach-policy-arn arn:aws:iam::aws:policy/service-role/AmazonEFSCSIDriverPolicy \
            --approve \
            --override-existing-serviceaccounts
        
        # Aguardar um pouco para a role ser criada
        sleep 15
    fi
    
    # Obter ARN da role criada usando jq para evitar problemas com query complexa
    ROLE_ARN=$(aws iam list-roles --output json | jq -r '.Roles[] | select(.RoleName | contains("efs-csi-controller-sa")) | .Arn' | head -1)
    
    if [[ -n "$ROLE_ARN" && "$ROLE_ARN" != "null" ]]; then
        log "Usando role: $ROLE_ARN"
        # Instalar add-on com service account role
        aws eks create-addon \
            --cluster-name ${CLUSTER_NAME} \
            --region ${REGION} \
            --addon-name aws-efs-csi-driver \
            --service-account-role-arn ${ROLE_ARN} \
            --resolve-conflicts OVERWRITE
    else
        log "Instalando add-on sem role específica"
        # Instalar add-on sem service account role (fallback)
        aws eks create-addon \
            --cluster-name ${CLUSTER_NAME} \
            --region ${REGION} \
            --addon-name aws-efs-csi-driver \
            --resolve-conflicts OVERWRITE
    fi
    
    # Aguardar add-on ficar ativo
    log "Aguardando EFS CSI Driver ficar ativo..."
    aws eks wait addon-active --cluster-name ${CLUSTER_NAME} --region ${REGION} --addon-name aws-efs-csi-driver
    
    success "EFS CSI Driver instalado"
}

# Instalar AWS Load Balancer Controller
install_alb_controller() {
    log "Instalando AWS Load Balancer Controller..."
    
    # Verificar se já está instalado
    if kubectl get deployment aws-load-balancer-controller -n kube-system &> /dev/null; then
        warning "AWS Load Balancer Controller já está instalado"
        return 0
    fi
    
    # Verificar se helm está disponível
    if ! command -v helm &> /dev/null; then
        warning "Helm não encontrado. Pulando instalação do AWS Load Balancer Controller."
        return 0
    fi
    
    # Criar service account para ALB Controller (se não existir)
    if ! kubectl get serviceaccount aws-load-balancer-controller -n kube-system &> /dev/null; then
        # Usar nome de role mais curto para evitar limite de 64 caracteres
        ROLE_NAME="ALBControllerRole-$(echo ${CLUSTER_NAME} | cut -c1-30)"
        
        # Criar política IAM customizada para AWS Load Balancer Controller
        # Baseada na política oficial mais recente da AWS
        cat > /tmp/alb-controller-policy.json << 'EOF'
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "iam:CreateServiceLinkedRole"
            ],
            "Resource": "*",
            "Condition": {
                "StringEquals": {
                    "iam:AWSServiceName": "elasticloadbalancing.amazonaws.com"
                }
            }
        },
        {
            "Effect": "Allow",
            "Action": [
                "ec2:DescribeAccountAttributes",
                "ec2:DescribeAddresses",
                "ec2:DescribeAvailabilityZones",
                "ec2:DescribeInternetGateways",
                "ec2:DescribeVpcs",
                "ec2:DescribeVpcPeeringConnections",
                "ec2:DescribeSubnets",
                "ec2:DescribeSecurityGroups",
                "ec2:DescribeInstances",
                "ec2:DescribeNetworkInterfaces",
                "ec2:DescribeTags",
                "ec2:DeleteSecurityGroup",
                "ec2:GetCoipPoolUsage",
                "ec2:DescribeCoipPools",
                "elasticloadbalancing:DescribeLoadBalancers",
                "elasticloadbalancing:DescribeLoadBalancerAttributes",
                "elasticloadbalancing:DescribeListeners",
                "elasticloadbalancing:DescribeListenerCertificates",
                "elasticloadbalancing:DescribeListenerAttributes",
                "elasticloadbalancing:DescribeSSLPolicies",
                "elasticloadbalancing:DescribeRules",
                "elasticloadbalancing:DescribeTargetGroups",
                "elasticloadbalancing:DescribeTargetGroupAttributes",
                "elasticloadbalancing:DescribeTargetHealth",
                "elasticloadbalancing:DescribeTags"
            ],
            "Resource": "*"
        },
        {
            "Effect": "Allow",
            "Action": [
                "cognito-idp:DescribeUserPoolClient",
                "acm:ListCertificates",
                "acm:DescribeCertificate",
                "iam:ListServerCertificates",
                "iam:GetServerCertificate",
                "waf-regional:GetWebACL",
                "waf-regional:GetWebACLForResource",
                "waf-regional:AssociateWebACL",
                "waf-regional:DisassociateWebACL",
                "wafv2:GetWebACL",
                "wafv2:GetWebACLForResource",
                "wafv2:AssociateWebACL",
                "wafv2:DisassociateWebACL",
                "shield:DescribeProtection",
                "shield:GetSubscriptionState",
                "shield:DescribeSubscription",
                "shield:CreateProtection",
                "shield:DeleteProtection"
            ],
            "Resource": "*"
        },
        {
            "Effect": "Allow",
            "Action": [
                "ec2:AuthorizeSecurityGroupIngress",
                "ec2:RevokeSecurityGroupIngress",
                "ec2:CreateSecurityGroup",
                "elasticloadbalancing:CreateListener",
                "elasticloadbalancing:DeleteListener",
                "elasticloadbalancing:CreateRule",
                "elasticloadbalancing:DeleteRule",
                "elasticloadbalancing:SetWebAcl",
                "elasticloadbalancing:ModifyListener",
                "elasticloadbalancing:AddListenerCertificates",
                "elasticloadbalancing:RemoveListenerCertificates",
                "elasticloadbalancing:ModifyRule"
            ],
            "Resource": "*"
        },
        {
            "Effect": "Allow",
            "Action": [
                "elasticloadbalancing:CreateLoadBalancer",
                "elasticloadbalancing:CreateTargetGroup"
            ],
            "Resource": "*",
            "Condition": {
                "Null": {
                    "aws:RequestedRegion": "false"
                }
            }
        },
        {
            "Effect": "Allow",
            "Action": [
                "elasticloadbalancing:CreateLoadBalancer",
                "elasticloadbalancing:CreateTargetGroup",
                "elasticloadbalancing:DeleteLoadBalancer",
                "elasticloadbalancing:DeleteTargetGroup",
                "elasticloadbalancing:ModifyLoadBalancerAttributes",
                "elasticloadbalancing:ModifyTargetGroup",
                "elasticloadbalancing:ModifyTargetGroupAttributes",
                "elasticloadbalancing:RegisterTargets",
                "elasticloadbalancing:DeregisterTargets",
                "elasticloadbalancing:SetSecurityGroups",
                "elasticloadbalancing:SetSubnets",
                "elasticloadbalancing:SetIpAddressType",
                "elasticloadbalancing:AddTags",
                "elasticloadbalancing:RemoveTags"
            ],
            "Resource": "*",
            "Condition": {
                "Null": {
                    "aws:ResourceTag/elbv2.k8s.aws/cluster": "false"
                }
            }
        },
        {
            "Effect": "Allow",
            "Action": [
                "elasticloadbalancing:AddTags",
                "elasticloadbalancing:RemoveTags"
            ],
            "Resource": [
                "arn:aws:elasticloadbalancing:*:*:targetgroup/*/*",
                "arn:aws:elasticloadbalancing:*:*:loadbalancer/net/*/*",
                "arn:aws:elasticloadbalancing:*:*:loadbalancer/app/*/*"
            ],
            "Condition": {
                "Null": {
                    "aws:RequestedRegion": "false",
                    "aws:ResourceTag/elbv2.k8s.aws/cluster": "false"
                }
            }
        },
        {
            "Effect": "Allow",
            "Action": [
                "elasticloadbalancing:ModifyLoadBalancerAttributes",
                "elasticloadbalancing:ModifyTargetGroup",
                "elasticloadbalancing:ModifyTargetGroupAttributes",
                "elasticloadbalancing:RegisterTargets",
                "elasticloadbalancing:DeregisterTargets"
            ],
            "Resource": "*"
        },
        {
            "Effect": "Allow",
            "Action": [
                "ec2:CreateTags"
            ],
            "Resource": "arn:aws:ec2:*:*:security-group/*",
            "Condition": {
                "StringEquals": {
                    "ec2:CreateAction": "CreateSecurityGroup"
                },
                "Null": {
                    "aws:RequestedRegion": "false"
                }
            }
        }
    ]
}
EOF
        
        # Criar política IAM
        POLICY_ARN=$(aws iam create-policy \
            --policy-name AWSLoadBalancerControllerIAMPolicy-${CLUSTER_NAME} \
            --policy-document file:///tmp/alb-controller-policy.json \
            --query 'Policy.Arn' --output text 2>/dev/null || \
            aws iam list-policies --query "Policies[?PolicyName=='AWSLoadBalancerControllerIAMPolicy-${CLUSTER_NAME}'].Arn" --output text)
        
        eksctl create iamserviceaccount \
            --cluster=${CLUSTER_NAME} \
            --region=${REGION} \
            --namespace=kube-system \
            --name=aws-load-balancer-controller \
            --role-name=${ROLE_NAME} \
            --attach-policy-arn=${POLICY_ARN} \
            --approve \
            --override-existing-serviceaccounts
        
        # Aguardar um pouco para a role ser criada
        sleep 15
        
        # Cleanup
        rm -f /tmp/alb-controller-policy.json
    fi
    
    # Adicionar repositório Helm do EKS
    helm repo add eks https://aws.github.io/eks-charts || true
    helm repo update
    
    # Obter VPC ID
    VPC_ID=$(aws eks describe-cluster --name ${CLUSTER_NAME} --region ${REGION} --query "cluster.resourcesVpcConfig.vpcId" --output text)
    
    # Verificar se já existe uma instalação do Helm
    if helm list -n kube-system | grep -q aws-load-balancer-controller; then
        log "Atualizando AWS Load Balancer Controller existente..."
        helm upgrade aws-load-balancer-controller eks/aws-load-balancer-controller \
            -n kube-system \
            --set clusterName=${CLUSTER_NAME} \
            --set serviceAccount.create=false \
            --set serviceAccount.name=aws-load-balancer-controller \
            --set region=${REGION} \
            --set vpcId=${VPC_ID} \
            --wait --timeout=300s
    else
        log "Instalando AWS Load Balancer Controller..."
        helm install aws-load-balancer-controller eks/aws-load-balancer-controller \
            -n kube-system \
            --set clusterName=${CLUSTER_NAME} \
            --set serviceAccount.create=false \
            --set serviceAccount.name=aws-load-balancer-controller \
            --set region=${REGION} \
            --set vpcId=${VPC_ID} \
            --wait --timeout=300s
    fi
    
    # Aguardar deployment ficar pronto
    log "Aguardando AWS Load Balancer Controller ficar pronto..."
    kubectl wait --for=condition=available deployment/aws-load-balancer-controller -n kube-system --timeout=300s
    
    success "AWS Load Balancer Controller instalado"
}

# Função removida - Metrics Server será instalado via Helm
# usando o arquivo helm-values/metrics-server/values.yaml

# Aguardar todos os add-ons ficarem ativos
wait_for_addons() {
    log "Aguardando todos os add-ons ficarem completamente ativos..."
    
    # Lista de add-ons para verificar
    ADDONS=("vpc-cni" "coredns" "kube-proxy" "metrics-server" "aws-ebs-csi-driver" "aws-efs-csi-driver")
    
    for addon in "${ADDONS[@]}"; do
        log "Verificando status do add-on: $addon"
        
        # Aguardar até 5 minutos para cada add-on
        local timeout=300
        local elapsed=0
        
        while [[ $elapsed -lt $timeout ]]; do
            local status=$(aws eks describe-addon --cluster-name ${CLUSTER_NAME} --region ${REGION} --addon-name $addon --query "addon.status" --output text 2>/dev/null || echo "NOT_FOUND")
            
            if [[ "$status" == "ACTIVE" ]]; then
                success "Add-on $addon está ativo"
                break
            elif [[ "$status" == "NOT_FOUND" ]]; then
                warning "Add-on $addon não encontrado, pulando..."
                break
            else
                log "Add-on $addon status: $status (aguardando...)"
                sleep 10
                elapsed=$((elapsed + 10))
            fi
        done
        
        if [[ $elapsed -ge $timeout ]]; then
            warning "Timeout aguardando add-on $addon ficar ativo"
        fi
    done
    
    # Verificar pods do sistema
    log "Verificando pods do sistema..."
    kubectl get pods -n kube-system
    
    success "Verificação de add-ons concluída"
}

# Verificar status do cluster
verify_cluster() {
    log "Verificando status do cluster..."
    
    # Aguardar nodes ficarem prontos
    log "Aguardando nodes ficarem prontos..."
    kubectl wait --for=condition=Ready nodes --all --timeout=300s
    
    # Verificar nodes
    echo ""
    log "Nodes do cluster:"
    kubectl get nodes -o wide
    
    # Verificar add-ons
    echo ""
    log "Add-ons instalados:"
    aws eks describe-cluster --name ${CLUSTER_NAME} --region ${REGION} --query "cluster.addons[*].{Name:addonName,Status:status,Version:addonVersion}" --output table
    
    # Verificar pods do sistema
    echo ""
    log "Pods do sistema:"
    kubectl get pods -n kube-system
    
    success "Cluster verificado e funcionando"
}

# Criar storage classes
create_storage_classes() {
    log "Criando storage classes..."
    
    # Storage class para EBS gp3
    cat << EOF | kubectl apply -f -
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: gp3
  annotations:
    storageclass.kubernetes.io/is-default-class: "true"
provisioner: ebs.csi.aws.com
parameters:
  type: gp3
  fsType: ext4
volumeBindingMode: WaitForFirstConsumer
allowVolumeExpansion: true
---
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: gp3-retain
provisioner: ebs.csi.aws.com
parameters:
  type: gp3
  fsType: ext4
reclaimPolicy: Retain
volumeBindingMode: WaitForFirstConsumer
allowVolumeExpansion: true
EOF

    # Remover storage class padrão antiga
    kubectl patch storageclass gp2 -p '{"metadata": {"annotations":{"storageclass.kubernetes.io/is-default-class":"false"}}}'
    
    success "Storage classes criadas"
}

# Função principal
main() {
    echo ""
    log "🚀 INICIANDO CRIAÇÃO DO CLUSTER EKS"
    log "=================================="
    log "Cluster: ${CLUSTER_NAME}"
    log "Região: ${REGION} (Ohio)"
    log "Versão K8s: ${KUBERNETES_VERSION}"
    log "Tipo de instância: ${INSTANCE_TYPE}"
    log "Nodes: ${MIN_SIZE}-${MAX_SIZE} (desejado: ${DESIRED_SIZE})"
    echo ""
    
    # Executar etapas
    check_prerequisites
    create_iam_roles
    create_eks_cluster
    configure_kubeconfig
    
    # Aguardar cluster ficar ativo
    log "Aguardando cluster ficar completamente ativo..."
    aws eks wait cluster-active --name ${CLUSTER_NAME} --region ${REGION}
    
    # Instalar add-ons
    install_ebs_csi_driver
    install_efs_csi_driver
    install_alb_controller
    create_storage_classes
    
    # Aguardar todos os add-ons ficarem completamente ativos
    wait_for_addons
    
    # Verificação final
    verify_cluster
    
    echo ""
    success "🎉 CLUSTER EKS CRIADO COM SUCESSO!"
    echo ""
    log "📋 INFORMAÇÕES DO CLUSTER:"
    log "=========================="
    log "Nome: ${CLUSTER_NAME}"
    log "Região: ${REGION}"
    log "Endpoint: $(aws eks describe-cluster --name ${CLUSTER_NAME} --region ${REGION} --query "cluster.endpoint" --output text)"
    log "Versão: $(aws eks describe-cluster --name ${CLUSTER_NAME} --region ${REGION} --query "cluster.version" --output text)"
    echo ""
    log "🔧 PRÓXIMOS PASSOS:"
    log "=================="
    log "1. Verificar acesso: kubectl get nodes"
    log "2. Seguir documentação: docs/deploy-observability-stack.md"
    log "3. Instalar Metrics Server manualmente via Helm"
    log "4. Instalar stack de observabilidade seguindo o guia passo a passo"
    echo ""
    log "💡 COMANDOS ÚTEIS:"
    log "=================="
    log "• Verificar cluster: kubectl cluster-info"
    log "• Listar nodes: kubectl get nodes"
    log "• Verificar add-ons: aws eks list-addons --cluster-name ${CLUSTER_NAME}"
    log "• Deletar cluster: eksctl delete cluster --name ${CLUSTER_NAME} --region ${REGION}"
    echo ""
}

# Verificar se está sendo executado diretamente
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi