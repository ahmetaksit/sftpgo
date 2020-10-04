FROM golang:1.15-alpine AS builder

ENV GOFLAGS="-mod=readonly"

RUN apk add --update --no-cache bash ca-certificates curl git gcc g++

RUN mkdir -p /workspace
WORKDIR /workspace

ARG GOPROXY

COPY go.mod go.sum ./
RUN go mod download

COPY . .

RUN go build -ldflags "-s -w -X github.com/drakkan/sftpgo/version.commit=`git describe --always --dirty` -X github.com/drakkan/sftpgo/version.date=`date -u +%FT%TZ`" -o sftpgo


FROM alpine:3.12

RUN apk add --update --no-cache ca-certificates tzdata bash

SHELL ["/bin/bash", "-c"]

# set up nsswitch.conf for Go's "netgo" implementation
# https://github.com/gliderlabs/docker-alpine/issues/367#issuecomment-424546457
RUN test ! -e /etc/nsswitch.conf && echo 'hosts: files dns' > /etc/nsswitch.conf

RUN mkdir -p /data /etc/sftpgo /srv/sftpgo/web /srv/sftpgo/backups

RUN addgroup -g 1000 -S sftpgo
RUN adduser -u 1000 -h /srv/sftpgo -s /sbin/nologin -G sftpgo -S -D -H sftpgo

VOLUME ["/data", "/srv/sftpgo/backups"]

# Override some configuration details
ENV SFTPGO_CONFIG_DIR=/etc/sftpgo
ENV SFTPGO_LOG_FILE_PATH=""
ENV SFTPGO_HTTPD__TEMPLATES_PATH=/srv/sftpgo/web/templates
ENV SFTPGO_HTTPD__STATIC_FILES_PATH=/srv/sftpgo/web/static

# Sane defaults, but users should still be able to override this from env vars
ENV SFTPGO_DATA_PROVIDER__USERS_BASE_DIR=/data
ENV SFTPGO_HTTPD__BACKUPS_PATH=/srv/sftpgo/backups

COPY --from=builder /workspace/sftpgo.json /etc/sftpgo/sftpgo.json
COPY --from=builder /workspace/templates /srv/sftpgo/web/templates
COPY --from=builder /workspace/static /srv/sftpgo/web/static
COPY --from=builder /workspace/sftpgo /usr/local/bin/

RUN chown -R sftpgo:sftpgo /data /etc/sftpgo /srv/sftpgo/web /srv/sftpgo/backups

USER sftpgo

CMD sftpgo serve