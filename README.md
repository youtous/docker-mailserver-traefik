# youtous/mailserver-traefik


[![pipeline status](https://gitlab.com/youtous/docker-mailserver-traefik/badges/master/pipeline.svg)](https://gitlab.com/youtous/docker-mailserver-traefik/-/commits/master)
[![Docker image size](https://img.shields.io/docker/image-size/youtous/mailserver-traefik)](https://hub.docker.com/r/youtous/mailserver-traefik/)
[![Docker hub](https://img.shields.io/badge/hub-youtous%2Fmailserver--traefik-099cec?logo=docker)](https://hub.docker.com/r/youtous/mailserver-traefik/)
[![Licence](https://img.shields.io/github/license/youtous/docker-mailserver-traefik)](https://github.com/youtous/docker-mailserver-traefik/blob/master/LICENSE)

Docker image which automatically renews [tomav/docker-mailserver ](https://github.com/tomav/docker-mailserver/) certificates using [traefik](https://github.com/containous/traefik).


### Features

- Automatically push certificates to *mailserver* containers on container creation or on cert renewal
- Supports _traefik_ v1 and v2
- Handles all ACME storage strategies 
- Restarts dovecot and postfix after certificate update
- Wiring using a single label on the mailserver!
- Lightweight docker image 

### Installation

#### Using docker cli 

Set a label on mailserver container and define SSL configuration:
```
docker run -d --name mailserver --label mailserver-traefik.renew.domain=mail.localhost.com -e SSL_TYPE=manual -e SSL_KEY_PATH=/etc/postfix/ssl/key -e SSL_CERT_PATH=/etc/postfix/ssl/cert tvial/docker-mailserver
```

Then start the traefik certificate renewer:
```
docker run -d --name cert-renewer-traefik -e DOMAINS=mail.localhost.com -v /var/run/docker.sock:/var/run/docker.sock -v "$PWD/acme.json:/tmp/traefik/:ro" youtous/mailserver-traefik
```

#### Using docker-compose
```yaml
services:
  cert-renewer-traefik:
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

      - "traefik.enable=true" # use traefik v2 for certificate generation
      - "traefik.http.routers.mail.rule=Host(`mail.localhost.com`)" 
      - "traefik.http.routers.mail.entrypoints=websecure"
    environment:
      - SSL_TYPE=manual # enable SSL on the mailserver
      - SSL_CERT_PATH=/etc/postfix/ssl/cert
      - SSL_KEY_PATH=/etc/postfix/ssl/key
```
### Usage

On the *mailserver* container : define the **label** and **set SSL environment**:
```yaml
  mailserver:
    image: tvial/docker-mailserver:latest
    labels:
      - "mailserver-traefik.renew.domain=mail.localhost.com" # required label for hooking up the mailserver service
    environment:
      - SSL_TYPE=manual # required env values, enable SSL on the mailserver
      - SSL_CERT_PATH=/etc/postfix/ssl/cert
      - SSL_KEY_PATH=/etc/postfix/ssl/key
```

On the *cert-renewer-traefik* container, configure the following environment variables and map docker socket:
```yaml
  cert-renewer-traefik:
    image: youtous/mailserver-traefik:latest
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock # required
      - ./acme.json:/tmp/traefik/:ro # (only if you use file storage acme.json)
    environment:
      - CERTS_SOURCE=file
      - DOMAINS=mail.localhost.com
```

| Variable | Description | Type | Default value | Values |
| -------- | ----------- | ---- | ------------- | ------ |
| **DOMAINS** | domain to watch, separate domains using a coma | *required* |  | any _tld_ seperated by a coma. e.g.: mail.server.com,mail.localhost.com
| **CERTS_SOURCE** | source used to retrieve certificates | *optional* | file | file, consul, etc, zookeeper, boltdb
| **PUSH_PERIOD** | by default, certificates will be pushed when a change is detected and every *PUSH_PERIOD*, allowing new containers to get existing certificates | *optional* | 15m | *0* = disabled (certificates are pushed only when updated)<br> *<int>m/s/h* - see [man timeout](https://linux.die.net/man/1/timeout) )

Other environment variables depends on the **CERTS_SOURCE** selected.

#### Using file storage _acme.json_

- Mount `acme.json` on `/tmp/traefik/acme.json` read-only: `-v "$PWD/acme.json:/tmp/traefik/:ro"`

- Specific environment variables:

| Variable | Description | Type | Default value | Values |
| -------- | ----------- | ---- | ------------- | ------ |
| **TRAEFIK_VERSION** | traefik version | *optional* | 2 | 1 or 2

By default, traefik v2 is selected, change it depending of your traefik version.

#### Using a KV Store

- KV Stores _(consul, etcd, boltdb, zookeeper)_ share lot of common options, main configuration resides in:

| Variable | Description | Type | Default value | Values |
| -------- | ----------- | ---- | ------------- | ------ |
| **KV_ENDPOINTS** | endpoints to connect | *required* |  |  `address:port`, e.g.:<br>`consul:8500`<br>`etcd:2139`<br>`198.168.2.36:2139`
| **KV_PREFIX** | [prefix used](https://docs.traefik.io/v1.7/configuration/backends/consul/) in KV store | *optional* | traefik | *string*
| **KV_SUFFIX** | suffix used in KV store | *optional* | /acme/account/object | *string*
| **KV_USERNAME** | KV store username | *optional* |  | *string*
| **KV_PASSWORD** | KV store password | *optional* |  | *string*

- For other options, see [complete KV Store configuration](doc/kvstore.md).

### Examples

#### Using file
See [Using docker-compose](#using-docker-compose)

#### Using a KV Store
*docker-compose.yml*
```yaml
  cert-renewer-traefik:
    image: youtous/mailserver-traefik:latest
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock # required
    environment:
      - CERTS_SOURCE=consul
      - KV_ENDPOINTS=consul-leader:8500
      - DOMAINS=mail.localhost.com,mailserver2.localhost.com # using multi domains

  mailserver:
    image: tvial/docker-mailserver:latest
    hostname: mail
    domainname: localhost.com
    labels:
      - "mailserver-traefik.renew.domain=mail.localhost.com" # required, tag this service

      - "traefik.frontend.rule=Host:mail.localhost.com" # traefik ACME will handle creation of certificates for this domain
      - "traefik.frontend.redirect.replacement=https://webmail.localhost.com/" # redirect access to smtp/imap domain to and other domain (e.g. webmail or autoconfig)
      - "traefik.frontend.redirect.regex=.*"
      - "traefik.enable=true"
    ports:
      - "25:25"
      - "143:143"
      - "587:587"
      - "993:993"
    volumes:
      - maildata:/var/mail
      - mailstate:/var/mail-state
      - maillogs:/var/log/mail
    env_file:
      - .mailserver.env
    environment:
      - SSL_TYPE=manual # required, do not change SSL_TYPE,SSL_CERT_PATH,SSL_KEY_PATH values
      - SSL_CERT_PATH=/etc/postfix/ssl/cert
      - SSL_KEY_PATH=/etc/postfix/ssl/key
```
When a new certificate is issued, *cert-renewer-traefik* will push it into the *mailserver* then restart dovecot and postfix services. The mailserver certificates will always be up to date :)

You can attach a traefik rule directly on the *mailserver* service in order to get certificates automatically requested by traefik or use [traefik static configuration](https://docs.traefik.io/v1.7/configuration/acme/#domains).

*cert-renewer-traefik* service does not require to be running in the *mailserver* stack, it can handles many *mailserver* and many domains. See: [See also](#see-also).


### See also

- See [test-stack](/test-stack/README.md) for more examples. 
  This testing environment simulates a complete stack : traefik + acme server acting like Let's Encrypt, have a look! 
- [Configuration for multidomains](/test/files/docker-compose.traefik.v1.multidomains.yml)
- [Configuration for multiservers](/test/files/docker-compose.traefik.v1.multiservers.yml)
- Use `make tests` to run tests (docker-compose is required).
- [tests](/test) - Tests directory contains useful resources listing different usages (multidomains, multiservers, etc).
- [traefik-certs-dumper](https://github.com/ldez/traefik-certs-dumper) - Used in this image for watching certificates
### Licence
MIT