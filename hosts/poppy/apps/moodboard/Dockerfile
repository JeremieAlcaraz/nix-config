# ── Stage 1: Build ────────────────────────────────────────────────────
FROM oven/bun:1 AS build

WORKDIR /app

# Install dependencies first (layer cache)
COPY package.json bun.lock ./
RUN bun install --frozen-lockfile

# Copy source and build
COPY . .
RUN bun run build

# ── Stage 2: Runtime ─────────────────────────────────────────────────
FROM oven/bun:1-alpine AS runtime

WORKDIR /app

# Install production dependencies only
COPY package.json bun.lock ./
RUN bun install --frozen-lockfile --production

# Copy built frontend
COPY --from=build /app/dist ./dist

# Copy server and config
COPY server/prod.ts ./server/prod.ts
COPY src/types ./src/types
COPY infra/garage/garage.toml ./infra/garage/garage.toml

# Copy assets directory structure (manifest, external links)
COPY assets/ ./assets/

# Ensure .local exists for runtime data
RUN mkdir -p .local/garage

ENV PORT=3005
EXPOSE 3005

CMD ["bun", "run", "server/prod.ts"]