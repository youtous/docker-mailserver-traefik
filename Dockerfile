FROM ldez/traefik-certs-dumper:v2.7.0

LABEL description "Complete solution for automatically renew docker-mailserver certificates using traefik certificates. " \
      maintainer="youtous <contact@youtous.me>"

ENV TRAEFIK_VERSION=1\
    CERTS_SOURCE=consul\
    DOMAIN=mail.youtous.dv\
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
COPY trigger-renew.sh /
RUN chmod +x /trigger-renew.sh

VOLUME /tmp/ssl

# override entrypoint
WORKDIR /
ENTRYPOINT ["/usr/bin/env"]
CMD ["bash","/handler.sh"]