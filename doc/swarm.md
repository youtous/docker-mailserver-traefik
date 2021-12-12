# Usage in a Swarm cluster

The *cert-renewer* detects if the swarm mode is activated.

In swarm mode, containers are deployed across multiple nodes; in order to push certificates in the *mailserver* containers,
the *cert-renewer* must be on the **same node** as the *mailserver*. You can use [deployment constraints](https://success.docker.com/article/using-contraints-and-labels-to-control-the-placement-of-containers) to achieve it.

You can have multiple *mailservers* getting their certificates from a single *cert-renew* if they are all on the same node, otherwise, use deploy constraints to
always have a *cert-renewer* on the *mailserver* nodes.

_docker-compose.swarm.yml_
```yaml

version: "3.7"

services:

  cert-renewer:
    image: mailserver-traefik:latest
    deploy:
      placement:
        constraints:    # use a node label to identify deployment placement 
          - node.role == manager
          - node.labels.mailserver.mailserver-data == true
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock
      - ./acme.json:/tmp/traefik/acme.json
    environment:
      - TRAEFIK_VERSION=1
      - CERTS_SOURCE=file
      - DOMAINS=mail.localhost.com
    networks:
      - internal

  mailserver:
    image: mailserver/docker-mailserver:latest
    command: > # Since v10.3.0, a empty certs must be present to allow mailserver to load, see https://github.com/docker-mailserver/docker-mailserver/blob/a4095a7d48082fe0dbfd2146cf9be4ed743736d1/target/scripts/startup/setup-stack.sh#L989
      sh -c '
        mkdir -p $$(dirname "$$SSL_KEY_PATH") &&
        touch -a "$$SSL_KEY_PATH" &&
        touch -a "$$SSL_CERT_PATH" &&
        supervisord -c /etc/supervisor/supervisord.conf
      '
    deploy:
      placement:
        constraints:
          - node.role == manager
          - node.labels.mailserver.mailserver-data == true
      labels:
        - "mailserver-traefik.renew.domain=mail.localhost.com"
        # traefik v1 using labels
        - "traefik.frontend.rule=Host:mail.localhost.com" # traefik ACME will handle creation of certificates for this domain
        - "traefik.frontend.redirect.replacement=https://webmail.localhost.com/" # redirect access to smtp/imap domain to and other domain (e.g. webmail or autoconfig)
        - "traefik.frontend.redirect.regex=.*"
        - "traefik.enable=true"
        - "traefik.port=443"
    ports:
      - "25:25"
      - "143:143"
      - "587:587"
      - "993:993"
    volumes:
      - maildata:/var/mail
      - maillogs:/var/log/mail
    env_file:
      - .mailserver.env
    environment:
      - SSL_TYPE=manual
      - SSL_CERT_PATH=/var/mail-state/manual-ssl/cert
      - SSL_KEY_PATH=/var/mail-state/manual-ssl/key
      - OVERRIDE_HOSTNAME=mail.localhost.com
    networks:
      bluenet:

networks:
  internal: # no internet acess
    internal: true
  bluenet:
    ipam:
      config:
        - subnet: 10.77.77.0/24

volumes:
  maildata:
    driver: local
  maillogs:
    driver: local

```