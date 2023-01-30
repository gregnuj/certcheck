FROM ubuntu:18.04
LABEL MAINTAINER="Greg Junge <gregnuj@gmail.com>"

## Install project requirements
RUN set -eux && \
    apt-get update && \
    apt-get install --no-install-recommends -y \
    bash ca-certificates curl cron jq openssl socat && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/* 

COPY --chown=root:root --chmod=0644 ./crontab /etc/cron.d/checkcerts
COPY --chown=root:root --chmod=0755 ./entrypoint /usr/local/bin/entrypoint
COPY --chown=root:root --chmod=0755 ./checkcerts.sh /usr/local/bin/checkcerts.sh

ENTRYPOINT [ "/usr/local/bin/entrypoint" ]
CMD [ "cron", "-f" ]