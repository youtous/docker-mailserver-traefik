FROM ldez/traefik-certs-dumper:v2.7.0

LABEL description "Complete solution for automatically renew docker-mailserver certificates using traefik certificates. " \
      maintainer="youtous <contact@youtous.me>"

# Install docker client
RUN apk update && apk add --no-cache docker-cli

COPY handler.sh /
RUN chmod +x /handler.sh

VOLUME /tmp/ssl

# override entrypoint
WORKDIR /
ENTRYPOINT ["/usr/bin/env"]
CMD ["sh","/handler.sh"]