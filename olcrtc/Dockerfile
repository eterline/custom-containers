# Stage 1: Build
FROM golang:1.27.1-alpine AS builder

ARG GO_FLAGS="-s -w"

WORKDIR /src

ENV CGO_ENABLED=1 \
    GOOS=linux

COPY olcrtc/go.mod olcrtc/go.sum ./

RUN apk add --no-cache build-base gcc && go mod download

COPY olcrtc/ ./

RUN mkdir -p /out && \
    go build -trimpath -ldflags="${GO_FLAGS}" \
    -o /out/olcrtc \
    ./cmd/olcrtc


FROM alpine:3.23.5 AS runtime

ENV TZ=Asia/Irkutsk

WORKDIR /olcrtc

RUN apk add --no-cache \
        ca-certificates \
        tzdata \
    && addgroup -S olcrtc \
    && adduser -S -D -H \
        -s /sbin/nologin \
        -G olcrtc \
        olcrtc \
    && mkdir -p /etc/olcrtc \
    && chown -R olcrtc:olcrtc /etc/olcrtc

COPY --from=builder /out/olcrtc /usr/local/bin/olcrtc

COPY --chown=olcrtc:olcrtc /config/. /olcrtc/.

USER olcrtc:olcrtc

ENTRYPOINT ["/usr/local/bin/olcrtc"]