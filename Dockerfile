FROM ldez/traefik-certs-dumper:v2.7.0

LABEL description "Automatically renew tomav/docker-mailserver certificates using traefik. " \
      maintainer="youtous <contact@youtous.me>"

ENV TRAEFIK_VERSION=1\
    CERTS_SOURCE=consul\
    DOMAINS=mail.youtous.dv\
    KV_ENDPOINTS=[localhost:8500]\
    KV_USERNAME=\
    KV_PASSWORD=\
    KV_TIMEOUT=\
    KV_SUFFIX=\
    KV_PREFIX=\
    KV_TLS_CA=\
    KV_TLS_CA_OPTIONAL=0\
    KV_TLS_TRUST_INSECURE=0\
    KV_TLS_CERT=\
    KV_TLS_TRUST_KEY=\
    KV_CONSUL_TOKEN=\
    KV_BOLTDB_BUCKET=\
    KV_BOLTDB_PERSIST_CONNECTION=0\
    KV_ETCD_VERSION=etcd\
    KV_ETCD_SYNC_PERIOD=

# Install docker client, bash
RUN apk update && apk add --no-cache docker-cli bash

COPY handler.sh /
RUN chmod +x /handler.sh
COPY trigger-push.sh /
RUN chmod +x /trigger-push.sh
COPY tomav-renew-certs.bash /
RUN chmod +x /tomav-renew-certs.bash

ENV SSL_DEST=/tmp/ssl
VOLUME $SSL_DEST

# override entrypoint
WORKDIR /
ENTRYPOINT ["/usr/bin/env"]
CMD ["bash","/handler.sh"]