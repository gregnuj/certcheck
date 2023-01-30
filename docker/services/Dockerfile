FROM ubuntu:18.04
LABEL MAINTAINER="Greg Junge <gregnuj@gmail.com>"

# Install deps
RUN set -eux && \
    apt-get update && \
    apt-get install --no-install-recommends -y \
    curl gnupg2 software-properties-common

# Install nodejs 16.x
RUN set -eux && \
    curl -sL https://deb.nodesource.com/setup_16.x | bash && \
    apt-get update && \
    apt-get install --no-install-recommends -y nodejs

WORKDIR /app

COPY . .

RUN set -eux && \
    npm install

CMD ["node", "index.js"]