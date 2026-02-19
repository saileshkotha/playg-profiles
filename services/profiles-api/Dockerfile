FROM node:24-slim AS builder

RUN corepack enable && corepack prepare pnpm@9.15.4 --activate

WORKDIR /app

COPY package.json pnpm-workspace.yaml ./
COPY services/profiles-api/package.json services/profiles-api/

RUN pnpm install --frozen-lockfile

COPY services/profiles-api/tsconfig.json services/profiles-api/
COPY services/profiles-api/src/ services/profiles-api/src/

RUN pnpm --filter profiles-api build

RUN pnpm --filter profiles-api deploy --prod /app/pruned

# ---------- runtime ----------
FROM node:24-slim

RUN groupadd --system appgroup && useradd --system --gid appgroup appuser

WORKDIR /app

ENV NODE_ENV=production

COPY --from=builder /app/pruned/node_modules ./node_modules
COPY --from=builder /app/services/profiles-api/dist ./dist
COPY --from=builder /app/pruned/package.json ./

RUN chown -R appuser:appgroup /app

USER appuser

EXPOSE 8080

ENTRYPOINT ["node", "dist/main.js"]
