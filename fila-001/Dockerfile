# syntax=docker/dockerfile:1.7
# Coloque este Dockerfile na raiz de CADA repo Go (ou use build.dockerfile_inline).

FROM golang:1.22-alpine AS build
RUN apk add --no-cache git ca-certificates

ARG CMD_PATH=./cmd/app
ARG GOPRIVATE_GLOB=github.com/SEU-ORG/*
ENV GOPRIVATE=${GOPRIVATE_GLOB} \
    CGO_ENABLED=0

WORKDIR /src

# go mod download com acesso à org privada.
# O token vem via BuildKit secret (nunca vira layer da imagem final, pois é multi-stage).
# O git config abaixo faz o go usar HTTPS+token no lugar de SSH para a org.
COPY go.mod go.sum ./
RUN --mount=type=secret,id=gh_token \
    git config --global \
      url."https://x-access-token:$(cat /run/secrets/gh_token)@github.com/".insteadOf \
      "https://github.com/" && \
    go mod download

COPY . .
RUN go build -trimpath -o /out/app ${CMD_PATH}

# --- imagem final enxuta ---
FROM alpine:3.20
RUN apk add --no-cache ca-certificates
COPY --from=build /out/app /app
ENTRYPOINT ["/app"]
