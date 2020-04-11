FROM ldez/traefik-certs-dumper:v2.7.0

LABEL description "Automatically renew tomav/docker-mailserver certificates using traefik. " \
      maintainer="youtous <contact@youtous.me>"

ENV TRAEFIK_VERSION=1\
    CERTS_SOURCE=consul\
    DOMAINS=mail.youtous.dv\
    KV_ENDPOINTS=localhost:8500\
    KV_USERNAME=\
    KV_PASSWORD=\
    KV_TIMEOUT=\
    KV_PREFIX=traefik\
    KV_SUFFIX=/acme/account/object\
    KL_TLS_ENABLED=0\
    KV_TLS_CA=\
    KV_TLS_CA_OPTIONAL=0\
    KV_TLS_TRUST_INSECURE=0\
    KV_TLS_CERT=\
    KV_TLS_KEY=\
    KV_CONSUL_TOKEN=\
    KV_BOLTDB_BUCKET=\
    KV_BOLTDB_PERSIST_CONNECTION=0\
    KV_ETCD_VERSION=etcd\
    KV_ETCD_SYNC_PERIOD=\
    INITIAL_TIMEOUT=300\
    SSL_DEST=/tmp/ssl

# Install docker client, bash
RUN apk update && apk add --no-cache docker-cli bash

COPY handler.sh trigger-push.sh tomav-renew-certs.bash /
RUN chmod +x /handler.sh /trigger-push.sh /tomav-renew-certs.bash

VOLUME $SSL_DEST
VOLUME /tmp/traefik

# override entrypoint
WORKDIR /
ENTRYPOINT ["/usr/bin/env"]
CMD ["bash","/handler.sh"]