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

### Por que usar cAdvisor em container?

- **Acesso nativo ao Docker**: Acesso direto ao socket e APIs do Docker
- **Isolamento**: Não interfere no sistema host
- **Facilidade de gerenciamento**: Mais fácil de atualizar e configurar
- **Padrão da indústria**: Forma recomendada pela comunidade
- **Menos dependências**: Não precisa instalar binários no host

### Instalação via Docker Container

```bash
# Executar cAdvisor como container Docker
docker run -d \
  --name=cadvisor \
  --restart=unless-stopped \
  --volume=/:/rootfs:ro \
  --volume=/var/run:/var/run:ro \
  --volume=/sys:/sys:ro \
  --volume=/var/lib/docker/:/var/lib/docker:ro \
  --volume=/dev/disk/:/dev/disk:ro \
  --publish=8080:8080 \
  --privileged \
  --device=/dev/kmsg \
  gcr.io/cadvisor/cadvisor:latest
```

### Verificar funcionamento

```bash
# Verificar se container está rodando
docker ps | grep cadvisor

# Testar métricas localmente
curl http://localhost:8080/metrics

# Verificar se está escutando na porta
sudo netstat -tlnp | grep :8080

# Ver logs do container
docker logs cadvisor

# Acessar interface web (opcional)
# http://IP_INSTANCIA:8080
```

### Configurar para iniciar automaticamente

O cAdvisor já está configurado com `--restart=unless-stopped`, mas se quiser garantir que inicie com o sistema:

```bash
# Criar script de inicialização
sudo tee /etc/systemd/system/cadvisor-docker.service > /dev/null << 'EOF'
[Unit]
Description=cAdvisor Docker Container
Requires=docker.service
After=docker.service

[Service]
Type=oneshot
RemainAfterExit=yes
ExecStart=/usr/bin/docker start cadvisor
ExecStop=/usr/bin/docker stop cadvisor
TimeoutStartSec=0

[Install]
WantedBy=multi-user.target
EOF

# Habilitar serviço
sudo systemctl enable cadvisor-docker
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
# Ver logs do container
docker logs cadvisor

# Verificar se Docker está rodando
sudo systemctl status docker

# Verificar se container existe
docker ps -a | grep cadvisor

# Reiniciar container
docker restart cadvisor

# Remover e recriar container se necessário
docker rm -f cadvisor
# Depois executar novamente o comando docker run
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