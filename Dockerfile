FROM golang:1.14-alpine AS builder

WORKDIR /build
ENV CGO_ENABLED=1 \
  GOOS=linux \
  GOARCH=amd64

COPY go.mod go.sum ./
COPY api/go.mod api/go.sum ./api/
COPY sdk/go.mod sdk/go.sum ./sdk/

RUN go mod download
RUN apk add git gcc musl-dev 

COPY . .
RUN sh -c 'VERSION_PKG_PATH=github.com/hashicorp/vault/sdk/version;\
    set -x;\
    go build -o ./bin/vault -ldflags "\
      -X $VERSION_PKG_PATH.GitCommit=$(git rev-parse --short HEAD)\
      -X $VERSION_PKG_PATH.Version=$(cat .tags)"'

FROM alpine:3.12

RUN apk add ca-certificates libcap su-exec dumb-init tzdata

RUN addgroup vault && \
    adduser -S -G vault vault

RUN mkdir -p /vault/logs && \
    mkdir -p /vault/file && \
    mkdir -p /vault/config && \
    chown -R vault:vault /vault

VOLUME /vault/logs
VOLUME /vault/file
EXPOSE 8200
COPY docker-entrypoint.sh /usr/local/bin/docker-entrypoint.sh
ENTRYPOINT ["docker-entrypoint.sh"]

COPY --from=builder /build/bin/vault /bin/vault

CMD ["server", "-dev"]
