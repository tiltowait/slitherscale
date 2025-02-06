FROM node:22-alpine AS builder

WORKDIR /app

COPY . .

RUN npm ci
RUN npm run build
RUN npm prune --omit=dev

FROM node:22-alpine

COPY --from=builder /app/build ./build
COPY --from=builder /app/package*.json .
RUN npm ci --omit=dev

USER node

ENTRYPOINT ["node", "build"]
