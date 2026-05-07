FROM node:20-slim

RUN mkdir -p /data && chown -R node:node /data

WORKDIR /app

RUN npm install -g paperclipai@2026.428.0

EXPOSE 3100

ENV PAPERCLIP_HOME=/data/.paperclip
ENV PAPERCLIP_INSTANCE=default

USER node

CMD ["sh", "-c", "mkdir -p /data/.paperclip/instances/default && paperclipai onboard --yes && paperclipai run"]