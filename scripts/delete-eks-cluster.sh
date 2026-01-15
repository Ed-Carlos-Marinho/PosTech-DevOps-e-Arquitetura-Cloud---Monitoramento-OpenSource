#!/bin/bash

# =============================================================================
# EKS CLUSTER DELETION SCRIPT
# =============================================================================
# Aula 07 - PosTech DevOps - Observabilidade no Kubernetes
# Script para limpeza completa do cluster EKS e recursos associados
# =============================================================================

set -e  # Exit on any error

# Configurações padrão
CLUSTER_NAME="${CLUSTER_NAME:-observability-lab-cluster}"
REGION="${REGION:-us-east-2}"

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
}

# Confirmar deleção
confirm_deletion() {
    echo ""
    warning "ATENÇÃO: Esta operação irá deletar PERMANENTEMENTE:"
    echo "  • Cluster EKS: ${CLUSTER_NAME}"
    echo "  • Todos os node groups"
    echo "  • Todos os add-ons"
    echo "  • Load balancers criados"
    echo "  • Volumes EBS (se não tiverem retain policy)"
    echo "  • IAM roles criadas pelo script"
    echo ""
    
    read -p "Tem certeza que deseja continuar? (digite 'DELETE' para confirmar): " confirmation
    
    if [[ "$confirmation" != "DELETE" ]]; then
        log "Operação cancelada pelo usuário"
        exit 0
    fi
}

# Verificar se cluster existe
check_cluster_exists() {
    log "Verificando se cluster ${CLUSTER_NAME} existe..."
    
    if ! aws eks describe-cluster --name ${CLUSTER_NAME} --region ${REGION} &> /dev/null; then
        warning "Cluster ${CLUSTER_NAME} não encontrado na região ${REGION}"
        exit 0
    fi
    
    success "Cluster encontrado"
}

# Deletar Load Balancers criados pelo ALB Controller
delete_load_balancers() {
    log "Deletando Load Balancers criados pelo cluster..."
    
    # Obter VPC ID do cluster
    VPC_ID=$(aws eks describe-cluster --name ${CLUSTER_NAME} --region ${REGION} --query "cluster.resourcesVpcConfig.vpcId" --output text)
    
    # Listar e deletar ALBs
    ALB_ARNS=$(aws elbv2 describe-load-balancers --region ${REGION} --query "LoadBalancers[?VpcId=='${VPC_ID}'].LoadBalancerArn" --output text)
    
    if [[ -n "$ALB_ARNS" ]]; then
        for ALB_ARN in $ALB_ARNS; do
            log "Deletando ALB: $ALB_ARN"
            aws elbv2 delete-load-balancer --load-balancer-arn $ALB_ARN --region ${REGION} || true
        done
        
        # Aguardar deleção dos ALBs
        log "Aguardando deleção dos Load Balancers..."
        sleep 30
    fi
    
    success "Load Balancers processados"
}

# Deletar recursos Kubernetes que podem criar recursos AWS
cleanup_kubernetes_resources() {
    log "Limpando recursos Kubernetes que criam recursos AWS..."
    
    # Configurar kubeconfig se necessário
    aws eks update-kubeconfig --region ${REGION} --name ${CLUSTER_NAME} || true
    
    # Deletar releases Helm primeiro
    log "Deletando releases Helm..."
    if command -v helm &> /dev/null; then
        # Listar todos os releases
        HELM_RELEASES=$(helm list --all-namespaces -q 2>/dev/null || true)
        
        if [[ -n "$HELM_RELEASES" ]]; then
            log "Releases Helm encontrados:"
            helm list --all-namespaces
            
            # Deletar releases em ordem específica para evitar dependências
            # 1. Aplicações e stacks de observabilidade
            for release in promtail loki kube-prometheus-stack; do
                NAMESPACE=$(helm list --all-namespaces -o json 2>/dev/null | jq -r ".[] | select(.name==\"$release\") | .namespace" || true)
                if [[ -n "$NAMESPACE" ]]; then
                    log "Deletando Helm release: $release (namespace: $NAMESPACE)"
                    helm uninstall $release -n $NAMESPACE --wait --timeout 5m || true
                fi
            done
            
            # 2. Cert-manager
            if helm list -n cert-manager -q 2>/dev/null | grep -q cert-manager; then
                log "Deletando Helm release: cert-manager"
                helm uninstall cert-manager -n cert-manager --wait --timeout 5m || true
            fi
            
            # 3. Ingress controllers
            if helm list -n ingress-nginx -q 2>/dev/null | grep -q ingress-nginx; then
                log "Deletando Helm release: ingress-nginx"
                helm uninstall ingress-nginx -n ingress-nginx --wait --timeout 5m || true
            fi
            
            # 4. Deletar qualquer outro release restante
            REMAINING_RELEASES=$(helm list --all-namespaces -q 2>/dev/null || true)
            for release in $REMAINING_RELEASES; do
                if [[ -n "$release" ]]; then
                    NAMESPACE=$(helm list --all-namespaces -o json 2>/dev/null | jq -r ".[] | select(.name==\"$release\") | .namespace" || true)
                    log "Deletando Helm release restante: $release (namespace: $NAMESPACE)"
                    helm uninstall $release -n $NAMESPACE --wait --timeout 5m || true
                fi
            done
            
            success "Releases Helm deletados"
        else
            log "Nenhum release Helm encontrado"
        fi
    else
        warning "Helm não encontrado, pulando limpeza de releases"
    fi
    
    # Deletar services do tipo LoadBalancer
    log "Deletando services do tipo LoadBalancer..."
    kubectl get svc --all-namespaces -o json | jq -r '.items[] | select(.spec.type=="LoadBalancer") | "\(.metadata.namespace) \(.metadata.name)"' | while read namespace name; do
        if [[ -n "$namespace" && -n "$name" ]]; then
            log "Deletando service LoadBalancer: $namespace/$name"
            kubectl delete svc $name -n $namespace --ignore-not-found=true --timeout=60s || true
        fi
    done
    
    # Deletar ingresses que podem ter ALBs
    log "Deletando ingresses..."
    kubectl delete ingress --all --all-namespaces --ignore-not-found=true --timeout=60s || true
    
    # Deletar PVCs que podem ter volumes EBS
    log "Deletando PersistentVolumeClaims..."
    kubectl delete pvc --all --all-namespaces --ignore-not-found=true --timeout=60s || true
    
    # Deletar CRDs do cert-manager (se existirem)
    log "Deletando CRDs do cert-manager..."
    kubectl delete crd certificates.cert-manager.io \
                       certificaterequests.cert-manager.io \
                       challenges.acme.cert-manager.io \
                       clusterissuers.cert-manager.io \
                       issuers.cert-manager.io \
                       orders.acme.cert-manager.io \
                       --ignore-not-found=true --timeout=60s || true
    
    # Deletar namespaces customizados
    log "Deletando namespaces customizados..."
    CUSTOM_NAMESPACES="monitoring cert-manager ingress-nginx"
    for ns in $CUSTOM_NAMESPACES; do
        if kubectl get namespace $ns &> /dev/null; then
            log "Deletando namespace: $ns"
            kubectl delete namespace $ns --ignore-not-found=true --timeout=120s || true
        fi
    done
    
    # Aguardar limpeza
    log "Aguardando finalização da limpeza de recursos..."
    sleep 30
    
    # Verificar se ainda existem namespaces em terminação
    TERMINATING_NS=$(kubectl get namespaces -o json | jq -r '.items[] | select(.status.phase=="Terminating") | .metadata.name' 2>/dev/null || true)
    if [[ -n "$TERMINATING_NS" ]]; then
        warning "Namespaces ainda em terminação: $TERMINATING_NS"
        log "Aguardando mais 30 segundos..."
        sleep 30
    fi
    
    success "Recursos Kubernetes limpos"
}

# Deletar add-ons do EKS
delete_addons() {
    log "Deletando add-ons do EKS..."
    
    # Listar add-ons
    ADDONS=$(aws eks list-addons --cluster-name ${CLUSTER_NAME} --region ${REGION} --query "addons" --output text)
    
    for ADDON in $ADDONS; do
        if [[ -n "$ADDON" ]]; then
            log "Deletando add-on: $ADDON"
            aws eks delete-addon --cluster-name ${CLUSTER_NAME} --addon-name $ADDON --region ${REGION} || true
        fi
    done
    
    success "Add-ons deletados"
}

# Deletar cluster usando eksctl
delete_cluster_eksctl() {
    log "Deletando cluster usando eksctl..."
    
    if command -v eksctl &> /dev/null; then
        eksctl delete cluster --name ${CLUSTER_NAME} --region ${REGION} --wait
        success "Cluster deletado via eksctl"
    else
        warning "eksctl não encontrado, usando AWS CLI..."
        delete_cluster_aws_cli
    fi
}

# Deletar cluster usando AWS CLI (fallback)
delete_cluster_aws_cli() {
    log "Deletando cluster usando AWS CLI..."
    
    # Deletar node groups primeiro
    NODE_GROUPS=$(aws eks list-nodegroups --cluster-name ${CLUSTER_NAME} --region ${REGION} --query "nodegroups" --output text)
    
    for NODE_GROUP in $NODE_GROUPS; do
        if [[ -n "$NODE_GROUP" ]]; then
            log "Deletando node group: $NODE_GROUP"
            aws eks delete-nodegroup --cluster-name ${CLUSTER_NAME} --nodegroup-name $NODE_GROUP --region ${REGION}
        fi
    done
    
    # Aguardar deleção dos node groups
    for NODE_GROUP in $NODE_GROUPS; do
        if [[ -n "$NODE_GROUP" ]]; then
            log "Aguardando deleção do node group: $NODE_GROUP"
            aws eks wait nodegroup-deleted --cluster-name ${CLUSTER_NAME} --nodegroup-name $NODE_GROUP --region ${REGION}
        fi
    done
    
    # Deletar cluster
    log "Deletando cluster EKS..."
    aws eks delete-cluster --name ${CLUSTER_NAME} --region ${REGION}
    
    # Aguardar deleção do cluster
    log "Aguardando deleção do cluster..."
    aws eks wait cluster-deleted --name ${CLUSTER_NAME} --region ${REGION}
    
    success "Cluster deletado via AWS CLI"
}

# Limpar contextos kubectl
cleanup_kubectl_contexts() {
    log "Limpando contextos kubectl..."
    
    # Remover contexto específico do cluster
    CONTEXT_NAME="arn:aws:eks:${REGION}:$(aws sts get-caller-identity --query Account --output text):cluster/${CLUSTER_NAME}"
    
    if kubectl config get-contexts -o name | grep -q "${CLUSTER_NAME}" 2>/dev/null; then
        log "Removendo contexto do cluster: ${CLUSTER_NAME}"
        kubectl config delete-context "${CONTEXT_NAME}" 2>/dev/null || true
        kubectl config unset "clusters.${CONTEXT_NAME}" 2>/dev/null || true
        kubectl config unset "users.${CONTEXT_NAME}" 2>/dev/null || true
    fi
    
    # Opção para limpar TODOS os contextos (descomente se necessário)
    # warning "Removendo TODOS os contextos kubectl..."
    # kubectl config get-contexts -o name | xargs -I {} kubectl config delete-context {} 2>/dev/null || true
    
    success "Contextos kubectl limpos"
}

# Deletar IAM roles criadas
delete_iam_roles() {
    log "Deletando IAM roles criadas..."
    
    # Roles criadas pelo script
    ROLES=(
        "EKSClusterRole-${CLUSTER_NAME}"
        "EKSNodeGroupRole-${CLUSTER_NAME}"
        "AmazonEKSLoadBalancerControllerRole-${CLUSTER_NAME}"
    )
    
    for ROLE in "${ROLES[@]}"; do
        if aws iam get-role --role-name $ROLE &> /dev/null; then
            log "Deletando role: $ROLE"
            
            # Detach policies
            POLICIES=$(aws iam list-attached-role-policies --role-name $ROLE --query "AttachedPolicies[].PolicyArn" --output text)
            for POLICY in $POLICIES; do
                if [[ -n "$POLICY" ]]; then
                    aws iam detach-role-policy --role-name $ROLE --policy-arn $POLICY || true
                fi
            done
            
            # Delete role
            aws iam delete-role --role-name $ROLE || true
            success "Role $ROLE deletada"
        fi
    done
    
    # Deletar roles criadas pelo eksctl (padrão eksctl-*)
    EKSCTL_ROLES=$(aws iam list-roles --query "Roles[?starts_with(RoleName, 'eksctl-${CLUSTER_NAME}')].RoleName" --output text)
    
    for ROLE in $EKSCTL_ROLES; do
        if [[ -n "$ROLE" ]]; then
            log "Deletando role eksctl: $ROLE"
            
            # Detach policies
            POLICIES=$(aws iam list-attached-role-policies --role-name $ROLE --query "AttachedPolicies[].PolicyArn" --output text 2>/dev/null || true)
            for POLICY in $POLICIES; do
                if [[ -n "$POLICY" ]]; then
                    aws iam detach-role-policy --role-name $ROLE --policy-arn $POLICY || true
                fi
            done
            
            # Delete instance profiles
            INSTANCE_PROFILES=$(aws iam list-instance-profiles-for-role --role-name $ROLE --query "InstanceProfiles[].InstanceProfileName" --output text 2>/dev/null || true)
            for PROFILE in $INSTANCE_PROFILES; do
                if [[ -n "$PROFILE" ]]; then
                    aws iam remove-role-from-instance-profile --instance-profile-name $PROFILE --role-name $ROLE || true
                    aws iam delete-instance-profile --instance-profile-name $PROFILE || true
                fi
            done
            
            # Delete role
            aws iam delete-role --role-name $ROLE || true
        fi
    done
    
    success "IAM roles processadas"
}

# Verificar limpeza
verify_cleanup() {
    log "Verificando limpeza..."
    
    # Verificar se cluster foi deletado
    if aws eks describe-cluster --name ${CLUSTER_NAME} --region ${REGION} &> /dev/null; then
        error "Cluster ainda existe!"
    fi
    
    # Verificar Load Balancers
    VPC_ID=$(aws ec2 describe-vpcs --filters "Name=tag:Name,Values=eksctl-${CLUSTER_NAME}-cluster/VPC" --query "Vpcs[0].VpcId" --output text 2>/dev/null || echo "None")
    if [[ "$VPC_ID" != "None" && "$VPC_ID" != "null" ]]; then
        REMAINING_ALBS=$(aws elbv2 describe-load-balancers --region ${REGION} --query "LoadBalancers[?VpcId=='${VPC_ID}']" --output text 2>/dev/null || true)
        if [[ -n "$REMAINING_ALBS" ]]; then
            warning "Ainda existem Load Balancers na VPC do cluster"
        fi
    fi
    
    success "Verificação de limpeza concluída"
}

# Função principal
main() {
    echo ""
    log "🗑️  INICIANDO DELEÇÃO DO CLUSTER EKS"
    log "==================================="
    log "Cluster: ${CLUSTER_NAME}"
    log "Região: ${REGION} (Ohio)"
    echo ""
    
    # Confirmar deleção
    confirm_deletion
    
    # Executar etapas de limpeza
    check_cluster_exists
    cleanup_kubernetes_resources
    delete_load_balancers
    delete_addons
    delete_cluster_eksctl
    cleanup_kubectl_contexts
    delete_iam_roles
    verify_cleanup
    
    echo ""
    success "🎉 CLUSTER EKS DELETADO COM SUCESSO!"
    echo ""
    log "📋 LIMPEZA CONCLUÍDA:"
    log "===================="
    log "• Releases Helm removidos"
    log "• Namespaces customizados deletados"
    log "• PVCs e volumes removidos"
    log "• Cluster EKS deletado"
    log "• Node groups removidos"
    log "• Add-ons removidos"
    log "• Load Balancers deletados"
    log "• Contextos kubectl limpos"
    log "• IAM roles limpas"
    echo ""
    warning "💡 VERIFICAÇÕES MANUAIS RECOMENDADAS:"
    log "===================================="
    log "• Verificar se não restaram volumes EBS órfãos"
    log "• Verificar se não restaram security groups"
    log "• Verificar se não restaram elastic IPs"
    log "• Verificar custos na AWS para confirmar limpeza"
    echo ""
}

# Verificar se está sendo executado diretamente
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi