# Aula 01 - PosTech DevOps e Arquitetura Cloud

Este repositório contém os materiais da **Aula 01** do módulo **Monitoramento OpenSource** da PosTech DevOps e Arquitetura Cloud.

## Conteúdo da Branch aula-01

### 1. Script de User Data EC2 (`ec2-userdata-demo.sh`)
Script automatizado para configuração de instâncias EC2 Ubuntu com:
- Docker e Docker Compose
- Code-server (VS Code no navegador) na porta 80
- Configurações básicas de segurança

### 2. Docker Compose Zabbix (`docker-compose.yml`)
Stack completa do Zabbix para monitoramento com:
- Zabbix Server (engine de monitoramento)
- Zabbix Web Interface (porta 8080)
- MySQL Database
- Zabbix Agent

## Arquivos de Documentação

- `ec2-userdata.md` - Guia detalhado do script de user data
- `zabbix-compose.md` - Guia detalhado do Docker Compose Zabbix
- `setup-ec2-instances.md` - Passo a passo completo para criar as instâncias EC2 com SSM

## Objetivo da Aula

Compreender e aplicar o uso do Zabbix para instalação, configuração e monitoramento de hosts, criando métricas de desempenho e alertas para infraestrutura.