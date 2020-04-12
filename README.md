# youtous/mailserver-traefik
[![Build Status](https://travis-ci.com/youtous/docker-mailserver-traefik.svg?branch=master)](https://travis-ci.com/youtous/docker-mailserver-traefik)
[![Docker image size](https://img.shields.io/docker/image-size/youtous/mailserver-traefik)](https://hub.docker.com/r/youtous/mailserver-traefik/)
[![Licence](https://img.shields.io/github/license/youtous/docker-mailserver-traefik)](https://github.com/youtous/docker-mailserver-traefik/blob/master/LICENSE)

Docker image which automatically renew [tomav/docker-mailserver ](https://github.com/tomav/docker-mailserver/) certificates using [traefik](https://github.com/containous/traefik).

### Features

- Supports _traefik_ v1 and v2
- Handles all ACME storage strategies 
- Restart dovecot and postfix after certificate update
- Wires using a single label on the mailserver!
- Lightweight docker image 

### Installation from Docker

```yaml
services:
  mailserver-traefik:
    image: youtous/mailserver-traefik:latest
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock
      - ./acme.json:/tmp/traefik/:ro # link traefik acme.json file (read-only)
    environment:
      - TRAEFIK_VERSION=2
      - CERTS_SOURCE=file
      - DOMAINS=mail.localhost.com

  mailserver:
    image: tvial/docker-mailserver:latest
    hostname: mail
    domainname: localhost.com
    labels:
      - "mailserver-traefik.renew.domain=mail.localhost.com" # tag the service 

      - "traefik.enable=true" # use traefik for certificate generation
      - "traefik.http.routers.mail.rule=Host(`mail.localhost.com`)" 
      - "traefik.http.routers.mail.entrypoints=websecure"
    environment:
      - SSL_TYPE=manual # enable SSL on the mailserver
      - SSL_CERT_PATH=/etc/postfix/ssl/cert
      - SSL_KEY_PATH=/etc/postfix/ssl/key
```
### Usage

### Examples

See [test-stack](https://github.com/youtous/docker-mailserver-traefik/tree/master/test-stack) for different examples.

### See also

- [traefik-certs-dumper](https://github.com/ldez/traefik-certs-dumper) - Used in this image for watching certificates
- [tests](https://github.com/youtous/docker-mailserver-traefik/tree/master/test) - Tests directory contains useful resources listing different usages (multidomains, multiservers, etc).
### Licence
MIT