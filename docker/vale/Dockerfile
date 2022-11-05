# We build our own image because of
# https://github.com/errata-ai/vale/issues/128.
FROM golang:alpine AS builder
WORKDIR /
RUN apk add --update --no-cache tar make
ADD https://github.com/errata-ai/vale/archive/v2.20.1.tar.gz v2.20.1.tar.gz
RUN tar -xf v2.20.1.tar.gz && cd vale-2.20.1 && make

FROM alpine:edge
COPY --from=builder /vale-2.20.1/bin/vale /usr/bin/vale
