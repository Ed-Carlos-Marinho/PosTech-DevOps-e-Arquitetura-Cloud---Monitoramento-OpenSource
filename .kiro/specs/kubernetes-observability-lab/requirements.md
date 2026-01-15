# Requirements Document - Kubernetes Observability Lab Environment

## Introduction

Este documento especifica os requisitos para criar um ambiente de aula prático onde será demonstrada a implementação de observabilidade no Kubernetes usando EKS (Amazon Elastic Kubernetes Service) e uma instância EC2 como estação de trabalho para execução de comandos kubectl e helm.

## Glossary

- **EKS_Cluster**: Amazon Elastic Kubernetes Service cluster gerenciado
- **Bastion_Instance**: Instância EC2 configurada como estação de trabalho para acesso ao cluster
- **kubectl**: Cliente de linha de comando para Kubernetes
- **helm**: Gerenciador de pacotes para Kubernetes
- **kube_prometheus_stack**: Helm chart para stack completa de observabilidade
- **Lab_Environment**: Ambiente completo de aula com EKS + EC2
- **Student_Access**: Acesso dos alunos ao ambiente via SSH ou Session Manager
- **Demo_Applications**: Aplicações de exemplo para demonstrar observabilidade

## Requirements

### Requirement 1: EKS Cluster Setup

**User Story:** Como instrutor, eu quero um cluster EKS configurado e pronto para uso, para que eu possa demonstrar a implementação de observabilidade no Kubernetes.

#### Acceptance Criteria

1. WHEN the EKS cluster is created, THE Lab_Environment SHALL provision a managed Kubernetes cluster with at least 3 worker nodes
2. THE EKS_Cluster SHALL be accessible via kubectl from the bastion instance
3. THE EKS_Cluster SHALL have appropriate IAM roles and policies for observability components
4. WHEN the cluster is ready, THE Lab_Environment SHALL have default storage classes configured
5. THE EKS_Cluster SHALL support LoadBalancer and Ingress controllers for external access
6. THE EKS_Cluster SHALL have cluster autoscaling enabled for dynamic node management
7. WHEN students access the cluster, THE Lab_Environment SHALL provide appropriate RBAC permissions

### Requirement 2: EC2 Bastion Instance Configuration

**User Story:** Como instrutor, eu quero uma instância EC2 configurada como estação de trabalho, para que eu possa executar comandos kubectl e helm durante a aula.

#### Acceptance Criteria

1. WHEN the bastion instance is launched, THE Lab_Environment SHALL install kubectl, helm, and AWS CLI
2. THE Bastion_Instance SHALL have kubeconfig automatically configured for EKS access
3. THE Bastion_Instance SHALL include code-server for browser-based development environment
4. WHEN students connect, THE Bastion_Instance SHALL provide SSH and Session Manager access
5. THE Bastion_Instance SHALL have all necessary Helm repositories pre-configured
6. THE Bastion_Instance SHALL include monitoring and troubleshooting tools (htop, curl, jq)
7. WHEN the instance starts, THE Lab_Environment SHALL clone the course repository with examples

### Requirement 3: Observability Stack Deployment

**User Story:** Como instrutor, eu quero deployar a stack de observabilidade no EKS, para que eu possa demonstrar monitoramento completo de aplicações Kubernetes.

#### Acceptance Criteria

1. WHEN kube-prometheus-stack is deployed, THE Lab_Environment SHALL install Prometheus, Grafana, and AlertManager
2. THE Lab_Environment SHALL deploy Loki stack for log aggregation
3. WHEN the stack is ready, THE Lab_Environment SHALL configure persistent storage for metrics and logs
4. THE Lab_Environment SHALL expose Grafana via LoadBalancer or Ingress for external access
5. WHEN data sources are configured, THE Lab_Environment SHALL automatically integrate Prometheus and Loki in Grafana
6. THE Lab_Environment SHALL include pre-configured dashboards for Kubernetes monitoring
7. WHEN the deployment completes, THE Lab_Environment SHALL validate all components are healthy

### Requirement 4: Demo Applications Deployment

**User Story:** Como instrutor, eu quero aplicações de exemplo deployadas no cluster, para que eu possa demonstrar coleta de métricas e logs.

#### Acceptance Criteria

1. WHEN demo applications are deployed, THE Lab_Environment SHALL create sample microservices with metrics endpoints
2. THE Demo_Applications SHALL include ServiceMonitor and PodMonitor examples
3. THE Demo_Applications SHALL generate realistic logs for Loki collection
4. WHEN applications are running, THE Lab_Environment SHALL demonstrate automatic service discovery
5. THE Demo_Applications SHALL include examples of custom metrics and alerts
6. THE Lab_Environment SHALL deploy applications in different namespaces for multi-tenancy demonstration
7. WHEN load is generated, THE Demo_Applications SHALL provide realistic monitoring scenarios

### Requirement 5: Student Access and Security

**User Story:** Como instrutor, eu quero controlar o acesso dos alunos ao ambiente, para que eles possam praticar sem comprometer a segurança.

#### Acceptance Criteria

1. THE Lab_Environment SHALL implement least-privilege access for students
2. WHEN students access the bastion, THE Lab_Environment SHALL provide isolated user sessions
3. THE Lab_Environment SHALL restrict kubectl access to specific namespaces for students
4. WHEN students interact with the cluster, THE Lab_Environment SHALL log all activities
5. THE Lab_Environment SHALL implement session timeouts for automatic cleanup
6. THE Lab_Environment SHALL provide read-only access to monitoring dashboards
7. WHEN the lab ends, THE Lab_Environment SHALL support easy cleanup and reset

### Requirement 6: Infrastructure as Code

**User Story:** Como instrutor, eu quero toda a infraestrutura definida como código, para que eu possa recriar o ambiente facilmente para diferentes turmas.

#### Acceptance Criteria

1. THE Lab_Environment SHALL use Terraform or CloudFormation for infrastructure provisioning
2. WHEN infrastructure is deployed, THE Lab_Environment SHALL create all AWS resources consistently
3. THE Lab_Environment SHALL include Helm charts and Kubernetes manifests in version control
4. WHEN changes are made, THE Lab_Environment SHALL support infrastructure updates via code
5. THE Lab_Environment SHALL include scripts for environment setup and teardown
6. THE Lab_Environment SHALL document all configuration parameters and customization options
7. WHEN deployed in different regions, THE Lab_Environment SHALL adapt automatically

### Requirement 7: Cost Optimization

**User Story:** Como administrador, eu quero otimizar os custos do ambiente de aula, para que possamos manter o laboratório dentro do orçamento.

#### Acceptance Criteria

1. THE Lab_Environment SHALL use spot instances where appropriate for cost savings
2. WHEN the lab is not in use, THE Lab_Environment SHALL support automatic shutdown
3. THE Lab_Environment SHALL implement cluster autoscaling to minimize idle resources
4. WHEN storage is configured, THE Lab_Environment SHALL use cost-effective storage classes
5. THE Lab_Environment SHALL provide cost monitoring and alerting
6. THE Lab_Environment SHALL support scheduled start/stop for lab sessions
7. WHEN resources are no longer needed, THE Lab_Environment SHALL facilitate easy cleanup

### Requirement 8: Monitoring and Troubleshooting

**User Story:** Como instrutor, eu quero monitorar o próprio ambiente de aula, para que eu possa identificar e resolver problemas rapidamente.

#### Acceptance Criteria

1. THE Lab_Environment SHALL monitor the health of EKS cluster and bastion instance
2. WHEN issues occur, THE Lab_Environment SHALL provide alerting and notifications
3. THE Lab_Environment SHALL include logging for all infrastructure components
4. WHEN students encounter problems, THE Lab_Environment SHALL provide troubleshooting guides
5. THE Lab_Environment SHALL monitor resource usage and capacity
6. THE Lab_Environment SHALL include backup and recovery procedures
7. WHEN performance issues arise, THE Lab_Environment SHALL provide diagnostic tools

### Requirement 9: Documentation and Guides

**User Story:** Como instrutor, eu quero documentação completa do ambiente, para que eu possa conduzir a aula efetivamente e os alunos possam seguir os exercícios.

#### Acceptance Criteria

1. THE Lab_Environment SHALL include step-by-step deployment guides
2. WHEN students access the environment, THE Lab_Environment SHALL provide clear usage instructions
3. THE Lab_Environment SHALL include troubleshooting documentation for common issues
4. THE Lab_Environment SHALL provide examples of kubectl and helm commands for the lab
5. THE Lab_Environment SHALL include architecture diagrams and component explanations
6. THE Lab_Environment SHALL document all endpoints and access methods
7. WHEN exercises are performed, THE Lab_Environment SHALL provide validation steps

### Requirement 10: Lab Exercises and Scenarios

**User Story:** Como instrutor, eu quero exercícios práticos estruturados, para que os alunos possam aprender observabilidade no Kubernetes de forma hands-on.

#### Acceptance Criteria

1. THE Lab_Environment SHALL include guided exercises for deploying monitoring stack
2. WHEN students practice, THE Lab_Environment SHALL provide scenarios for ServiceMonitor creation
3. THE Lab_Environment SHALL include exercises for custom dashboard creation in Grafana
4. THE Lab_Environment SHALL provide log analysis exercises using Loki and LogQL
5. WHEN alerts are configured, THE Lab_Environment SHALL include alerting rule exercises
6. THE Lab_Environment SHALL provide troubleshooting scenarios with broken applications
7. WHEN the lab concludes, THE Lab_Environment SHALL include assessment criteria and validation steps