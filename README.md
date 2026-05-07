# Paperclip – Agentes de IA em Container

Configuração Docker para execução de agentes Paperclip AI em ambiente containerizado, com persistência de dados e suporte a deploy em produção.

## Início Rápido

```bash
git clone https://github.com/seu-usuario/paperclip
cd paperclip
cp .env.example .env          # edite as variáveis antes de subir
docker compose up -d
```

Interface disponível em `http://localhost:3100`.

## Estrutura do Repositório

```
paperclip/
├── Dockerfile              # Imagem baseada em node:20-slim com paperclipai CLI
├── docker-compose.yaml     # Serviço com volume nomeado e bind mount de prompts
├── .env.example            # Variáveis de ambiente necessárias
└── prompts/                # Diretório montado em /prompts no container
```

## Operações Básicas

| Ação        | Comando                          |
|-------------|----------------------------------|
| Iniciar     | `docker compose up -d`           |
| Parar       | `docker compose down`            |
| Logs        | `docker compose logs -f`         |
| Reiniciar   | `docker compose restart`         |
| Rebuild     | `docker compose build --no-cache`|

---

# Guia Técnico de Funcionamento e Deploy

## Índice

1. [Arquitetura](#arquitetura)
2. [Imagem Docker](#imagem-docker)
3. [Volumes e Persistência](#volumes-e-persistência)
4. [Variáveis de Ambiente](#variáveis-de-ambiente)
5. [Deploy em VPS](#deploy-em-vps)
6. [Proxy Reverso e TLS](#proxy-reverso-e-tls)
7. [Monitoramento e Logs](#monitoramento-e-logs)
8. [Backup e Restauração](#backup-e-restauração)
9. [Solução de Problemas](#solução-de-problemas)

---

## Arquitetura

```
Cliente (navegador)
        |
        | HTTP :3100
        v
  Container Docker
  ├── paperclipai run       <- processo principal (porta 3100)
  └── /data/.paperclip/    <- estado persistido via volume nomeado
        └── instances/
            └── default/
                └── logs/
```

O container executa dois comandos em sequência no startup:
1. `paperclipai onboard --yes` — provisionamento automático da instância sem interação.
2. `paperclipai run` — inicia o servidor HTTP.

---

## Imagem Docker

**Base:** `node:20-slim`

**Versão da CLI:** `paperclipai@2026.428.0` (fixada para builds reproduzíveis)

**Usuário de runtime:** `node` (não-root, UID 1000)

**Variáveis de ambiente internas:**

| Variável             | Valor padrão        | Descrição                                 |
|----------------------|---------------------|-------------------------------------------|
| `PAPERCLIP_HOME`     | `/data/.paperclip`  | Diretório raiz de dados da instância      |
| `PAPERCLIP_INSTANCE` | `default`           | Identificador da instância                |

**Porta exposta:** `3100/tcp`

Para fixar a versão da CLI em uma versão diferente, edite a linha no `Dockerfile`:

```dockerfile
RUN npm install -g paperclipai@<versão>
```

---

## Volumes e Persistência

O `docker-compose.yaml` define dois pontos de montagem:

| Origem (host)     | Destino (container) | Tipo          | Finalidade                          |
|-------------------|---------------------|---------------|-------------------------------------|
| `paperclip-data`  | `/data`             | Volume nomeado| Dados persistentes da instância     |
| `./prompts`       | `/prompts`          | Bind mount    | Prompts de agente editáveis no host |

O volume `paperclip-data` é gerenciado pelo Docker Engine. Para inspecionar:

```bash
docker volume inspect paperclipai_paperclip-data
```

Os prompts em `./prompts` são carregados diretamente do host, permitindo edição sem rebuild da imagem.

---

## Variáveis de Ambiente

Copie `.env.example` para `.env` antes de subir o serviço:

```bash
cp .env.example .env
```

| Variável                      | Obrigatório | Descrição                                               |
|-------------------------------|-------------|---------------------------------------------------------|
| `PAPERCLIP_AGENT_JWT_SECRET`  | Sim         | Secret para assinatura de tokens JWT dos agentes        |
| `DATABASE_URL`                | Não         | Connection string PostgreSQL; se ausente, usa embedded  |

Formato da `DATABASE_URL`:

```
postgresql://<user>:<password>@<host>:<port>/<database>
```

---

## Deploy em VPS

### Pré-requisitos (Ubuntu 22.04 / 24.04)

```bash
sudo apt update && sudo apt upgrade -y
sudo apt install -y docker.io docker-compose-v2
sudo usermod -aG docker $USER
newgrp docker
```

### Banco de Dados PostgreSQL Externo (Recomendado para Produção)

Usar PostgreSQL externo ao container elimina o risco de perda de dados em recriações do container e facilita backups e replicas.

```bash
sudo apt install -y postgresql-16
sudo -u postgres psql <<'SQL'
CREATE USER paperclip_user WITH PASSWORD 'senha_forte';
CREATE DATABASE paperclip_db OWNER paperclip_user;
SQL
```

Adicione ao `.env`:

```env
DATABASE_URL=postgresql://paperclip_user:senha_forte@localhost:5432/paperclip_db
```

Se o PostgreSQL estiver no host e o container precisar acessá-lo, use `host.docker.internal` (Docker Desktop) ou o IP da interface `docker0` (Linux):

```bash
# Linux: descobrir IP da bridge docker0
ip addr show docker0 | grep 'inet '
```

### Deploy

```bash
git clone https://github.com/seu-usuario/paperclip
cd paperclip
cp .env.example .env
# edite .env com as variáveis de produção
docker compose up -d
```

---

## Proxy Reverso e TLS

### Nginx

```nginx
server {
    listen 80;
    server_name seu-dominio.com;

    location / {
        proxy_pass         http://127.0.0.1:3100;
        proxy_http_version 1.1;
        proxy_set_header   Upgrade $http_upgrade;
        proxy_set_header   Connection "upgrade";
        proxy_set_header   Host $host;
        proxy_set_header   X-Real-IP $remote_addr;
        proxy_set_header   X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header   X-Forwarded-Proto $scheme;
        proxy_read_timeout 3600s;
    }
}
```

Provisionamento de certificado TLS via Let's Encrypt:

```bash
sudo apt install -y certbot python3-certbot-nginx
sudo certbot --nginx -d seu-dominio.com
```

O Certbot reescreve o bloco `server` para adicionar o listener na porta 443 e redirecionar HTTP para HTTPS automaticamente. A renovação automática é configurada via `systemd timer` durante a instalação.

---

## Monitoramento e Logs

**Logs do container em tempo real:**

```bash
docker compose logs -f paperclip
```

**Métricas de recursos:**

```bash
docker stats paperclip-agent
```

**Logs internos da instância** (dentro do container):

```
/data/.paperclip/instances/default/logs/
```

Para acessar diretamente:

```bash
docker exec -it paperclip-agent ls /data/.paperclip/instances/default/logs/
```

---

## Backup e Restauração

### Backup do Volume

```bash
# Para o serviço antes do backup para garantir consistência
docker compose stop

# Cria um tar do volume via container temporário
docker run --rm \
  -v paperclipai_paperclip-data:/data \
  -v "$(pwd)":/backup \
  node:20-slim \
  tar -czf /backup/paperclip-backup-$(date +%Y%m%d%H%M%S).tar.gz /data

docker compose start
```

### Backup do Banco PostgreSQL Externo

```bash
pg_dump -U paperclip_user -h localhost paperclip_db \
  | gzip > db_backup_$(date +%Y%m%d%H%M%S).sql.gz
```

### Restauração do Volume

```bash
docker compose down

docker run --rm \
  -v paperclipai_paperclip-data:/data \
  -v "$(pwd)":/backup \
  node:20-slim \
  tar -xzf /backup/paperclip-backup-<timestamp>.tar.gz -C /

docker compose up -d
```

---

## Solução de Problemas

**`exec format error` no startup**

O arquivo de entrypoint contém quebras de linha CRLF (Windows). Converta para LF:

```bash
sed -i 's/\r//' scripts/entrypoint.sh
```

Ou configure o Git para não converter line endings:

```bash
git config core.autocrlf false
git rm --cached scripts/entrypoint.sh
git checkout scripts/entrypoint.sh
```

**Porta 3100 já em uso**

```bash
# Linux/macOS
sudo lsof -i :3100

# Windows
netstat -aon | findstr :3100
```

Altere o mapeamento de porta no `docker-compose.yaml` se necessário:

```yaml
ports:
  - "3101:3100"   # <host>:<container>
```

**Erro de permissão no volume**

O container executa como usuário `node` (UID 1000). Se o diretório de dados no host tiver dono diferente:

```bash
sudo chown -R 1000:1000 ./data
```

**Container reinicia em loop (`restart: unless-stopped`)**

Inspecione os logs para identificar a causa raiz antes de desabilitar o restart policy:

```bash
docker compose logs --tail=100 paperclip
```

---

## Licença

MIT
