# Obraz stacka Portainera "mcp-nsa" (NAS). Serwer z repo mowi tylko stdio - supergateway wystawia go po
# Streamable HTTP (/mcp) bezstanowo: kazde zadanie obsluguje krotki proces potomny, wiec restart kontenera
# nie zrywa sesji klientow (claude.ai, ChatGPT). Zrodla bez zmian; Dockerfile (bez .nas) zostaje dla Glama.
FROM node:24-bookworm-slim AS build
WORKDIR /app
COPY package.json package-lock.json tsconfig.json ./
COPY src ./src
RUN npm ci --ignore-scripts --no-audit --no-fund && npx tsc && npm prune --omit=dev

FROM node:24-bookworm-slim
RUN npm install -g supergateway@4.1.0 --no-audit --no-fund && npm cache clean --force
WORKDIR /app
COPY --from=build /app/package.json ./
COPY --from=build /app/node_modules ./node_modules
COPY --from=build /app/dist ./dist
USER 1029:100
ENV NODE_NO_WARNINGS=1
EXPOSE 8000
CMD ["supergateway", "--stdio", "node /app/dist/index.js", "--outputTransport", "streamableHttp", "--port", "8000", "--streamableHttpPath", "/mcp", "--healthEndpoint", "/healthz", "--logLevel", "info"]
