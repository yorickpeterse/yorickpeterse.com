FROM golang:alpine AS builder
WORKDIR /
RUN apk add --update --no-cache tar make
ADD https://github.com/errata-ai/vale/archive/v2.4.0.tar.gz v2.4.0.tar.gz
RUN tar -xf v2.4.0.tar.gz && cd vale-2.4.0 && \
    go build -ldflags "-s -w -X main.version=" -o bin/vale

FROM alpine:edge
COPY --from=builder /vale-2.4.0/bin/vale /usr/bin/vale
