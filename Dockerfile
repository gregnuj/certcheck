FROM golang:1.18-buster as builder
LABEL MAINTAINER="Greg Junge <gregnuj@gmail.com>"
   
WORKDIR /build
COPY ./checkcerts .

# download dependencies to cache as layer
COPY go.mod go.sum ./
RUN --mount=type=cache,target=/root/.cache/go-build \
    --mount=type=cache,target=/root/go/pkg/mod \
    go mod download -x

RUN set -eux && \
    go build -o /go/bin/checkcerts ./...

###########################################################

FROM ubuntu:18.04
LABEL MAINTAINER="Greg Junge <gregnuj@gmail.com>"

## Install project requirements
RUN set -eux && \
    apt-get update && \
    apt-get install --no-install-recommends -y \
    bash ca-certificates curl cron jq openssl socat && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/* 

COPY --from=builder /go/bin/checkcerts /usr/local/bin/checkcerts.go
COPY --chown=root:root --chmod=0644 ./scripts/crontab /etc/cron.d/checkcerts
COPY --chown=root:root --chmod=0755 ./scripts/entrypoint /usr/local/bin/entrypoint
COPY --chown=root:root --chmod=0755 ./scripts/checkcerts.sh /usr/local/bin/checkcerts.sh

ENTRYPOINT [ "/usr/local/bin/entrypoint" ]
CMD [ "cron", "-f" ]