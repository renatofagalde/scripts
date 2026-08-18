# syntax=docker/dockerfile:1.7
# Vai na raiz do módulo Go de cada repo: <repo>/app/Dockerfile
# Build 100% offline a partir da pasta vendor/ (rode `go mod vendor` antes).

FROM golang:1.22-alpine AS build
RUN apk add --no-cache ca-certificates

ARG CMD_PATH=./cmd/app
# GOPROXY=off garante que nada saia pra rede: se faltar algo no vendor/, falha na hora.
ENV CGO_ENABLED=0 \
    GOFLAGS=-mod=vendor \
    GOPROXY=off

WORKDIR /src
COPY . .
RUN go build -trimpath -o /out/app ${CMD_PATH}

# --- imagem final enxuta ---
FROM alpine:3.20
RUN apk add --no-cache ca-certificates
COPY --from=build /out/app /app
ENTRYPOINT ["/app"]
