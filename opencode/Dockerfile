FROM node:22-alpine

RUN npm config set strict-ssl false && npm install -g opencode-ai

WORKDIR /app

COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

EXPOSE 4096 1455

CMD ["/entrypoint.sh"]
