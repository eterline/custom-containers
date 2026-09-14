# Stage 1: Загрузка репозитория singbox и сборка с флагами API
# ========================================================
FROM golang:1.27.1-alpine AS singbox-prepare

#  Статическая линковка для работы в alpine
ENV CGO_ENABLED=1

ARG SINGBOX_VERSION="v1.13.6"
ARG GO_FLAGS="-s -w"
ARG SINGBOX_TAGS="with_grpc"

RUN apk --no-cache --update add \
  build-base \
  gcc \
  curl \
  unzip

WORKDIR /build

RUN curl -L -o "$SINGBOX_VERSION.zip" -O "https://github.com/SagerNet/sing-box/archive/refs/tags/$SINGBOX_VERSION.zip" && \
    unzip "$SINGBOX_VERSION.zip" && rm "$SINGBOX_VERSION.zip" && cd $(ls) && \
    go build -trimpath -ldflags="$GO_FLAGS" -tags "$SINGBOX_TAGS" -o /build/sing-box ./cmd/sing-box

# Stage 2: сборка Runtime контейнера для singbox
# ========================================================
FROM alpine:3.23.5

# По умолчанию время с Иркутска
ENV TZ=Asia/Irkutsk 
WORKDIR /app

RUN apk add --no-cache --update ca-certificates && \
    mkdir /etc/sing-box

COPY --from=singbox-prepare /build/sing-box /usr/local/bin/sing-box

ENTRYPOINT [ "sing-box", "run", "-C", "/etc/sing-box" ]