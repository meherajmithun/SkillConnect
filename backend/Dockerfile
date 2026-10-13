FROM node:22-bookworm-slim
WORKDIR /app
COPY package.json package-lock.json ./
COPY backend/package.json backend/package.json
RUN npm ci --omit=dev
COPY backend/ backend/
RUN mkdir -p backend/data backend/media && chown -R node:node /app/backend
WORKDIR /app/backend
USER node
EXPOSE 8000
CMD ["node", "src/server.js"]
