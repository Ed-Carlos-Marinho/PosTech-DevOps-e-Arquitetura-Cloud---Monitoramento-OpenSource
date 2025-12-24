# Instalação Manual de Exporters

Guia para instalação manual do Node Exporter e cAdvisor nas instâncias Ubuntu para coleta de métricas pelo Prometheus.

## Node Exporter - Métricas do Sistema

### Instalação

```bash
# Conectar na instância via SSM ou SSH
aws ssm start-session --target i-xxxxxxxxx

# Criar usuário para o Node Exporter
sudo useradd --no-create-home --shell /bin/false node_exporter

# Baixar Node Exporter
cd /tmp
wget https://github.com/prometheus/node_exporter/releases/download/v1.8.2/node_exporter-1.8.2.linux-amd64.tar.gz

# Extrair e instalar
tar xvf node_exporter-1.8.2.linux-amd64.tar.gz
sudo cp node_exporter-1.8.2.linux-amd64/node_exporter /usr/local/bin/
sudo chown node_exporter:node_exporter /usr/local/bin/node_exporter

# Limpar arquivos temporários
rm -rf node_exporter-1.8.2.linux-amd64*
```

### Configurar como serviço

```bash
# Criar arquivo de serviço systemd
sudo tee /etc/systemd/system/node_exporter.service > /dev/null << 'EOF'
[Unit]
Description=Node Exporter
Wants=network-online.target
After=network-online.target

[Service]
User=node_exporter
Group=node_exporter
Type=simple
ExecStart=/usr/local/bin/node_exporter \
    --collector.systemd \
    --collector.processes \
    --web.listen-address=:9100

[Install]
WantedBy=multi-user.target
EOF

# Recarregar systemd e iniciar serviço
sudo systemctl daemon-reload
sudo systemctl enable node_exporter
sudo systemctl start node_exporter
sudo systemctl status node_exporter
```

### Verificar funcionamento

```bash
# Testar métricas localmente
curl http://localhost:9100/metrics

# Verificar se está escutando na porta
sudo netstat -tlnp | grep :9100
```

## cAdvisor - Métricas de Containers

### Instalação

```bash
# Baixar cAdvisor
sudo wget https://github.com/google/cadvisor/releases/download/v0.49.1/cadvisor-v0.49.1-linux-amd64 -O /usr/local/bin/cadvisor

# Dar permissões de execução
sudo chmod +x /usr/local/bin/cadvisor

# Criar usuário para cAdvisor
sudo useradd --no-create-home --shell /bin/false cadvisor
```

### Configurar como serviço

```bash
# Criar arquivo de serviço systemd
sudo tee /etc/systemd/system/cadvisor.service > /dev/null << 'EOF'
[Unit]
Description=cAdvisor
Wants=network-online.target
After=network-online.target

[Service]
User=root
Group=root
Type=simple
ExecStart=/usr/local/bin/cadvisor \
    --port=8080 \
    --logtostderr \
    --v=0 \
    --docker_only=true

[Install]
WantedBy=multi-user.target
EOF

# Recarregar systemd e iniciar serviço
sudo systemctl daemon-reload
sudo systemctl enable cadvisor
sudo systemctl start cadvisor
sudo systemctl status cadvisor
```

### Verificar funcionamento

```bash
# Testar métricas localmente
curl http://localhost:8080/metrics

# Verificar se está escutando na porta
sudo netstat -tlnp | grep :8080

# Acessar interface web (se necessário)
# http://IP_INSTANCIA:8080
```

## Configurar Security Groups

### Para Node Exporter (porta 9100)
```bash
# Via AWS CLI
aws ec2 authorize-security-group-ingress \
    --group-id sg-xxxxxxxxx \
    --protocol tcp \
    --port 9100 \
    --source-group sg-yyyyyyyyy
```

### Para cAdvisor (porta 8080)
```bash
# Via AWS CLI  
aws ec2 authorize-security-group-ingress \
    --group-id sg-xxxxxxxxx \
    --protocol tcp \
    --port 8080 \
    --source-group sg-yyyyyyyyy
```

**Ou via Console AWS:**
1. EC2 → Security Groups
2. Selecionar SG das instâncias com exporters
3. Inbound rules → Edit
4. Add rule:
   - Type: Custom TCP
   - Port: 9100 (Node Exporter) ou 8080 (cAdvisor)
   - Source: Security Group do Prometheus

## Atualizar configuração do Prometheus

Após instalar os exporters, editar o arquivo `prometheus.yml`:

```yaml
scrape_configs:
  - job_name: 'prometheus'
    static_configs:
      - targets: ['localhost:9090']

  - job_name: 'node-exporter'
    static_configs:
      - targets: ['10.0.1.100:9100', '10.0.1.101:9100']  # IPs privados das instâncias

  - job_name: 'cadvisor'
    static_configs:
      - targets: ['10.0.1.100:8080', '10.0.1.101:8080']  # IPs privados das instâncias
```

Recarregar configuração do Prometheus:
```bash
# Dentro do container do Prometheus
docker-compose exec prometheus promtool check config /etc/prometheus/prometheus.yml
docker-compose restart prometheus
```

## Verificação no Prometheus

1. Acessar Prometheus: `http://IP_PROMETHEUS:9090`
2. Status → Targets
3. Verificar se todos os exporters estão "UP"
4. Testar consultas PromQL:
   - `up` - Status de todos os targets
   - `node_cpu_seconds_total` - Métricas de CPU
   - `container_memory_usage_bytes` - Métricas de containers

## Troubleshooting

### Node Exporter não inicia
```bash
# Ver logs
sudo journalctl -u node_exporter -f

# Verificar permissões
ls -la /usr/local/bin/node_exporter

# Testar manualmente
sudo -u node_exporter /usr/local/bin/node_exporter
```

### cAdvisor não inicia
```bash
# Ver logs
sudo journalctl -u cadvisor -f

# Verificar se Docker está rodando
sudo systemctl status docker

# Testar manualmente
sudo /usr/local/bin/cadvisor --port=8080
```

### Prometheus não consegue coletar métricas
```bash
# Testar conectividade
telnet IP_TARGET 9100
telnet IP_TARGET 8080

# Verificar Security Groups
# Verificar IPs no prometheus.yml
# Verificar logs do Prometheus
docker-compose logs prometheus
```