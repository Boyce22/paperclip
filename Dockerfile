FROM node:20-slim

WORKDIR /app

RUN npm install -g paperclipai@2026.428.0

COPY scripts/entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

EXPOSE 3100

ENV PAPERCLIP_HOME=/data/.paperclip
ENV PAPERCLIP_INSTANCE=default

ENTRYPOINT ["/entrypoint.sh"]