FROM node:20-slim

# Instala curl para healthchecks
RUN apt-get update && apt-get install -y curl && rm -rf /var/lib/apt/lists/*

# Prepara o diretório de dados
RUN mkdir -p /data/.paperclip/instances/default && chown -R node:node /data
WORKDIR /app

# Instala o Paperclip e OpenCode globalmente
RUN npm install -g paperclipai@2026.428.0 opencode-ai

# Define variáveis de ambiente para persistência
ENV PAPERCLIP_HOME=/data/.paperclip
ENV PAPERCLIP_INSTANCE=default
EXPOSE 3100

USER node

CMD sh -c "\
    paperclipai onboard --yes --bind lan && \
    sed -i 's/\"host\": \"127.0.0.1\"/\"host\": \"0.0.0.0\"/g' /data/.paperclip/instances/default/config.json && \
    paperclipai run"