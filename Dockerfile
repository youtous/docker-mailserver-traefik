FROM ldez/traefik-certs-dumper:v2.8.1

LABEL org.label-schema.description="Automatically renew mailserver/docker-mailserver certificates using traefik." \
 maintainer="youtous <contact@youtous.me>" \
 org.label-schema.build-date=$BUILD_DATE \
 org.label-schema.name="youtous/mailserver-traefik" \
 org.label-schema.url="https://github.com/youtous/docker-mailserver-traefik/" \
 org.label-schema.vcs-url="https://github.com/youtous/docker-mailserver-traefik" \
 org.label-schema.vcs-ref=$VCS_REF \
 org.label-schema.version=$VCS_VERSION

ENV TRAEFIK_VERSION=2\
    CERTS_SOURCE=file\
    DOMAINS=missingdomains\
    KV_ENDPOINTS=\
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
    KV_BOLTDB_BUCKET=traefik\
    KV_BOLTDB_PERSIST_CONNECTION=0\
    KV_ETCD_VERSION=etcd\
    KV_ETCD_SYNC_PERIOD=\
    INITIAL_TIMEOUT=300\
    PUSH_PERIOD=15m\
    SSL_DEST=/tmp/ssl\
    DEBUG=0

# Install docker client, bash
RUN apk update && apk add --no-cache docker-cli bash

COPY handler.sh trigger-push.sh common.sh tomav-renew-certs.bash /
RUN chmod +x /handler.sh /trigger-push.sh /common.sh /tomav-renew-certs.bash

VOLUME $SSL_DEST
VOLUME /tmp/traefik

# override entrypoint
WORKDIR /
ENTRYPOINT ["/usr/bin/env"]
CMD ["bash","/handler.sh"]