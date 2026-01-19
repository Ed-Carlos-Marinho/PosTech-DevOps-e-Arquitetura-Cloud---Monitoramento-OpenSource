# Zabbix Docker Compose

Stack completa do Zabbix para monitoramento usando Docker Compose, parte da Aula 01 do módulo Monitoramento OpenSource.

## Componentes da Stack

### Serviços
- **zabbix-db**: MySQL 8.0 (banco de dados)
- **zabbix-server**: Engine de monitoramento
- **zabbix-web**: Interface web (porta 8080)
- **zabbix-agent**: Agente local de monitoramento

### Volumes
- **zabbix-db-data**: Dados do MySQL
- **zabbix-server-data**: Dados do Zabbix Server

## Como usar

### 1. Iniciar a stack
```bash
# Subir todos os serviços
docker-compose up -d

# Verificar status
docker-compose ps

# Ver logs em tempo real
docker-compose logs -f
```

### 2. Acessar interface web
- **URL**: `http://SEU_IP`
- **Usuário**: `Admin`
- **Senha**: `zabbix`

### 3. Gerenciar serviços
```bash
# Parar serviços
docker-compose down

# Parar e remover volumes (CUIDADO: apaga dados)
docker-compose down -v

# Atualizar imagens
docker-compose pull
docker-compose up -d
```

## Configuração inicial

### 1. Primeiro acesso
1. Acesse `http://SEU_IP`
2. Login: `Admin` / `zabbix`
3. Altere a senha padrão

### 2. Configurar monitoramento
1. **Administration** → **Users** → Alterar senha
2. **Configuration** → **Hosts** → Adicionar hosts
3. **Configuration** → **Actions** → Configurar alertas

### 3. Verificar agente local
- Host: "Zabbix server"
- IP: Detectado automaticamente
- Status: Deve aparecer como "Available"

## Portas utilizadas

- **80**: Interface web Zabbix
- **10051**: Zabbix server (comunicação com agentes)
- **10050**: Zabbix agent local
- **3306**: MySQL (interno, não exposto)

## Troubleshooting

### Erro "dbversion table not found"
Este erro indica que o banco não foi inicializado corretamente. Para corrigir:

```bash
# Parar todos os serviços
docker-compose down

# Remover volumes (CUIDADO: apaga todos os dados)
docker-compose down -v

# Subir apenas o banco primeiro
docker-compose up -d zabbix-db

# Aguardar o banco estar pronto (verificar logs)
docker-compose logs -f zabbix-db

# Quando o banco estiver pronto, subir o resto
docker-compose up -d
```

### Serviços não iniciam
```bash
# Ver logs específicos
docker-compose logs zabbix-server
docker-compose logs zabbix-db

# Verificar recursos
docker stats
```

### Interface web não carrega
```bash
# Verificar se web está rodando
docker-compose ps zabbix-web

# Ver logs do web
docker-compose logs zabbix-web

# Verificar se Zabbix Server está conectado ao banco
docker-compose logs zabbix-server | grep -i "database"
```

### Banco de dados
```bash
# Conectar no MySQL
docker-compose exec zabbix-db mysql -u zabbix -p zabbix

# Backup do banco
docker-compose exec zabbix-db mysqldump -u root -p zabbix > backup.sql
```

## Monitoramento básico

### Hosts padrão
- **Zabbix server**: Monitora a própria instância
- **Templates**: Linux, MySQL, Zabbix server

### Métricas importantes
- CPU usage
- Memory usage
- Disk space
- Network traffic
- MySQL performance

## Security Groups

Para funcionar corretamente, libere as portas:
- **8080**: Interface web
- **10050**: Agente Zabbix (se monitorar outros hosts)