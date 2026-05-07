# Paperclip + OpenCode – Agentes de IA em Container

Configuração Docker para execução de agentes **Paperclip AI** e **OpenCode** em ambiente containerizado, com persistência de dados e suporte a deploy em produção.

## Stack

| Ferramenta     | Versão         | Função                                      |
|----------------|----------------|---------------------------------------------|
| Paperclip AI   | `2026.428.0`   | Orquestração de agentes de IA autônomos     |
| OpenCode       | `1.14.40`      | CLI para interagir com LLMs (DeepSeek, etc) |
| Node.js        | `20-slim`      | Base da imagem Docker                        |
| PostgreSQL     | embedded       | Banco de dados gerenciado pelo Paperclip     |

---

## Início Rápido

```bash
git clone https://github.com/seu-usuario/paperclip
cd paperclip
cp .env.example .env          # edite as variáveis antes de subir
docker compose up -d
```

Interface disponível em `http://localhost:3100`.

---

## Estrutura do Repositório

```
paperclip/
├── Dockerfile              # Imagem baseada em node:20-slim com Paperclip + OpenCode
├── docker-compose.yaml     # Serviço com volume nomeado e bind mount de prompts
├── .env.example            # Variáveis de ambiente necessárias
├── README.md               # Esta documentação
└── prompts/                # Diretório montado em /prompts no container
```

---

## Operações Básicas

| Ação                    | Comando                                    |
|-------------------------|--------------------------------------------|
| Iniciar                 | `docker compose up -d`                     |
| Parar                   | `docker compose down`                      |
| Logs                    | `docker compose logs -f`                   |
| Reiniciar               | `docker compose restart`                   |
| Rebuild (sem cache)     | `docker compose build --no-cache`          |
| Resetar DB              | `docker compose down -v && docker compose up -d` |
| Acessar shell container | `docker exec -it paperclip-agent sh`       |

---

## Como Usar o OpenCode

O OpenCode está instalado globalmente dentro do container. Para usá-lo:

### 1. Acessar o container

```bash
docker exec -it paperclip-agent sh
```

### 2. Conectar com o Paperclip

Dentro do container, execute:

```bash
opencode
```

Depois dentro da CLI do OpenCode, use o comando `/connect` para conectar ao Paperclip.

### 3. Configurar DeepSeek como LLM Provider

Após conectar o OpenCode ao Paperclip, você pode configurar o DeepSeek (ou outro provedor compatível com OpenAI) diretamente pelo OpenCode usando `/connect` e seguindo as instruções interativas.

> **Nota:** O Paperclip suporta nativamente os provedores Claude (Anthropic) e OpenAI. O OpenCode expande essa capacidade permitindo conectar com outros provedores como DeepSeek.

---

## Arquitetura

```
Cliente (navegador / terminal)
        |
        | HTTP :3100 (Paperclip Web UI)
        | opencode (CLI via docker exec)
        v
  Container Docker
  ├── paperclipai run         <- processo principal (porta 3100)
  ├── opencode                <- CLI de interação com LLMs
  └── /data/.paperclip/       <- estado persistido via volume nomeado
        └── instances/
            └── default/
                ├── config.json
                ├── db/           (PostgreSQL embedded)
                ├── logs/
                ├── secrets/
                └── data/
```

O container executa os seguintes passos no startup:
1. `paperclipai onboard --yes` — provisionamento automático da instância.
2. `paperclipai run` — inicia o servidor HTTP Paperclip na porta 3100.
3. `opencode` — disponível como CLI para interação manual.

---

## Imagem Docker

**Base:** `node:20-slim`

**Pacotes globais instalados:**
- `paperclipai@2026.428.0` — CLI e servidor Paperclip
- `opencode-ai` — CLI do OpenCode para interação com LLMs

**Usuário de runtime:** `node` (não-root, UID 1000)

**Variáveis de ambiente internas:**

| Variável             | Valor padrão        | Descrição                                 |
|----------------------|---------------------|-------------------------------------------|
| `PAPERCLIP_HOME`     | `/data/.paperclip`  | Diretório raiz de dados da instância      |
| `PAPERCLIP_INSTANCE` | `default`           | Identificador da instância                |

**Porta exposta:** `3100/tcp`

Para fixar as versões, edite o `Dockerfile`:

```dockerfile
RUN npm install -g paperclipai@<versão> opencode-ai@<versão>
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
docker volume inspect paperclip_paperclip-data
```

Os prompts em `./prompts` são carregados diretamente do host, permitindo edição sem rebuild da imagem.

---

## Resetando o Banco de Dados

Se precisar resetar o banco e gerar um novo link de cadastro:

```bash
# Remove o container e o volume de dados
docker compose down -v

# Sobe novamente (gera novo link de convite automático)
docker compose up -d

# Ver o novo link de cadastro nos logs
docker compose logs --tail=30 paperclip
```

Procure nos logs por `Invite URL: http://localhost:3100/invite/...`

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
  -v paperclip_paperclip-data:/data \
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
  -v paperclip_paperclip-data:/data \
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

**OpenCode não encontrado**

Se o OpenCode não estiver disponível, faça o rebuild da imagem:

```bash
docker compose build --no-cache
docker compose up -d
```

---

## Licença

MIT
