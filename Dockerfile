# ============================================================
# Etapa 1: compilar el frontend (React/Vite con pnpm)
# ============================================================
FROM node:24-alpine AS frontend
RUN corepack enable
WORKDIR /src
COPY web ./web
WORKDIR /src/web/frontend
RUN pnpm install --frozen-lockfile --config.dangerouslyAllowAllBuilds=true
RUN pnpm build:backend

# ============================================================
# Etapa 2: compilar los binarios Go (gateway + consola web)
# ============================================================
FROM golang:1.26-alpine AS builder
RUN apk add --no-cache git
WORKDIR /src
COPY go.mod go.sum ./
RUN go mod download
COPY . .
# Traer el frontend ya compilado para que se embeba en la consola
COPY --from=frontend /src/web/backend/dist ./web/backend/dist
ENV CGO_ENABLED=0
RUN go generate ./...
RUN go build -tags goolm,stdjson -o /out/picoclaw ./cmd/picoclaw
RUN go build -tags stdjson -o /out/picoclaw-web ./web/backend

# ============================================================
# Etapa 3: imagen final
# ============================================================
FROM alpine:3.21
RUN apk add --no-cache ca-certificates curl tzdata
COPY --from=builder /out/picoclaw /usr/local/bin/picoclaw
COPY --from=builder /out/picoclaw-web /usr/local/bin/picoclaw-web

ENV PICOCLAW_HOME=/data/.picoclaw
EXPOSE 10000

# La consola web escucha en $PORT (Render) y lanza el gateway
# internamente en el puerto definido en el config (18790).
CMD ["sh", "-c", "mkdir -p $PICOCLAW_HOME && echo \"$PICOCLAW_CONFIG_CONTENT\" > $PICOCLAW_HOME/config.json && picoclaw-web -public -no-browser -console -port ${PORT:-10000} $PICOCLAW_HOME/config.json"]
