FROM node:22-alpine

ARG OPENCODE_VERSION=1.15.5

RUN npm config set strict-ssl false && npm install -g opencode-ai@${OPENCODE_VERSION}

WORKDIR /app

COPY entrypoint.sh /entrypoint.sh
RUN sed -i 's/\r$//' /entrypoint.sh && chmod +x /entrypoint.sh

EXPOSE 4096 1455

CMD ["/entrypoint.sh"]
