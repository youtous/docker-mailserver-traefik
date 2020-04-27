# youtous/mailserver-traefik


[![pipeline status](https://gitlab.com/youtous/docker-mailserver-traefik/badges/master/pipeline.svg)](https://gitlab.com/youtous/docker-mailserver-traefik/-/commits/master)
[![Docker image size](https://img.shields.io/docker/image-size/youtous/mailserver-traefik)](https://hub.docker.com/r/youtous/mailserver-traefik/)
[![Docker hub](https://img.shields.io/badge/hub-youtous%2Fmailserver--traefik-099cec?logo=docker)](https://hub.docker.com/r/youtous/mailserver-traefik/)
[![Licence](https://img.shields.io/github/license/youtous/docker-mailserver-traefik)](https://github.com/youtous/docker-mailserver-traefik/blob/master/LICENSE)

Docker image which automatically renews [tomav/docker-mailserver ](https://github.com/tomav/docker-mailserver/) certificates using [traefik](https://github.com/containous/traefik).


### Features

- Automatically push certificates to *mailserver* containers on container creation or on cert renewal
- Tested on _docker compose_ and _docker swarm_
- Supports _traefik_ v1 and v2
- Handles all ACME storage strategies 
- Restarts dovecot and postfix after certificate update
- Wiring using a single label on the mailserver!
- Lightweight docker image 

### Installation

#### Using docker cli 

Set a label on mailserver container and define SSL configuration:
```
docker run -d --name mailserver --label mailserver-traefik.renew.domain=mail.localhost.com -e SSL_TYPE=manual -e SSL_KEY_PATH=/var/mail-state/manual-ssl/key -e SSL_CERT_PATH=/var/mail-state/manual-ssl/cert tvial/docker-mailserver
```

Then start the traefik certificate renewer:
```
docker run -d --name cert-renewer-traefik -e DOMAINS=mail.localhost.com -v /var/run/docker.sock:/var/run/docker.sock -v "$PWD/acme.json:/tmp/traefik/acme.json:ro" youtous/mailserver-traefik
```

#### Using docker-compose
```yaml
services:
  cert-renewer-traefik:
    image: youtous/mailserver-traefik:latest
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock
      - ./acme.json:/tmp/traefik/acme.json:ro # link traefik acme.json file (read-only)
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

      # traefik configuration using labels, not required
      - "traefik.enable=true" # use traefik v2 for certificate generation
      - "traefik.port=443" # dummy port, required generating certs with traefik
      - "traefik.http.routers.mail.rule=Host(`mail.localhost.com`)" 
      - "traefik.http.routers.mail.entrypoints=websecure"
      - "traefik.http.routers.mail.middlewares=redirect-webmail@docker" # redirect to webmail
      - "traefik.http.middlewares.redirect-webmail.redirectregex.regex=.*"
      - "traefik.http.middlewares.redirect-webmail.redirectregex.replacement=https://webmail.localhost.com/"
    environment:
      - SSL_TYPE=manual # enable SSL on the mailserver
      - SSL_CERT_PATH=/var/mail-state/manual-ssl/cert
      - SSL_KEY_PATH=/var/mail-state/manual-ssl/key
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
      - SSL_CERT_PATH=/var/mail-state/manual-ssl/cert
      - SSL_KEY_PATH=/var/mail-state/manual-ssl/key
```

On the *cert-renewer-traefik* container, configure the following environment variables and map docker socket:
```yaml
  cert-renewer-traefik:
    image: youtous/mailserver-traefik:latest
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock # required
      - ./acme.json:/tmp/traefik/acme.json:ro # (only if you use file storage acme.json)
    environment:
      - CERTS_SOURCE=file
      - DOMAINS=mail.localhost.com
```

| Variable | Description | Type | Default value | Values |
| -------- | ----------- | ---- | ------------- | ------ |
| **DOMAINS** | domains to watch, separate domains using a comma | *required* |  | any _tld_ separated by a coma. e.g.: mail.server.com,mail.localhost.com
| **CERTS_SOURCE** | source used to retrieve certificates | *optional* | file | file, consul, etc, zookeeper, boltdb
| **PUSH_PERIOD** | by default, certificates will be pushed when a change is detected and every *PUSH_PERIOD*, allowing new containers to get existing certificates | *optional* | 15m | *0* = disabled (certificates are pushed only when updated)<br> *<int>m/s/h* - see [man timeout](https://linux.die.net/man/1/timeout) )

Other environment variables depends on the **CERTS_SOURCE** selected.

#### Using file storage _acme.json_

- Mount `acme.json` on `/tmp/traefik/acme.json` read-only: `-v "$PWD/acme.json:/tmp/traefik/acme.json:ro"`

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

#### Wildcard certificates

When using wildcard certificates, top domain is used for `DOMAINS` and for the `mailserver-traefik.renew.domain` label.<br>
For instance, `*.localhost.com` certificate used by the mailserver `mail.localhost.com` will be configured as follows:

```yaml
services:
  cert-renewer-traefik:
    image: youtous/mailserver-traefik:latest
    <...>
    environment:
      <...>
      - DOMAINS=localhost.com

  mailserver:
    image: tvial/docker-mailserver:latest
    labels:
      - "mailserver-traefik.renew.domain=localhost.com" # use the top domain NOT mail.localhost.com 
```

### Examples

#### Using file
See [Using docker-compose](#using-docker-compose)

#### Usage in a swarm cluster
See [swarm cluster](/doc/swarm.md).

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
      
      # traefik v1 using labels
      - "traefik.frontend.rule=Host:mail.localhost.com" # traefik ACME will handle creation of certificates for this domain
      - "traefik.frontend.redirect.replacement=https://webmail.localhost.com/" # redirect access to smtp/imap domain to and other domain (e.g. webmail or autoconfig)
      - "traefik.frontend.redirect.regex=.*"
      - "traefik.enable=true"
      - "traefik.port=443" # dummy port, not used
    environment:
      - SSL_TYPE=manual # required, do not change SSL_TYPE,SSL_CERT_PATH,SSL_KEY_PATH values
      - SSL_CERT_PATH=/var/mail-state/manual-ssl/cert
      - SSL_KEY_PATH=/var/mail-state/manual-ssl/key
```
When a new certificate is issued, *cert-renewer-traefik* will push it into the *mailserver* then restart dovecot and postfix services. The mailserver certificates will always be up to date :)

You can attach a traefik rule directly on the *mailserver* service in order to get certificates automatically requested by traefik or use [traefik static configuration](https://docs.traefik.io/v1.7/configuration/acme/#domains).

*cert-renewer-traefik* service does not require to be running in the *mailserver* stack, it can handles many *mailserver* and many domains. See: [See also](#see-also).

#### Using ONE_DIR

When `ONE_DIR=1` is enabled on *mailserver*, state of the container will be consolidated across runs using a docker volume.<br/>
The *cert-renewer-traefik* detects when the *mailserver* has `ONE_DIR` enabled and will copy the certificates.<br/>
That's why it's important not to change `SSL_CERT_PATH=/var/mail-state/manual-ssl/cert` and `SSL_KEY_PATH=/var/mail-state/manual-ssl/key`.

When `ONE_DIR` is disabled, certificates will be lost at the end of the container's lifetime. Even if `ONE_DIR` is disabled, you must set 
`SSL_CERT_PATH` and `SSL_KEY_PATH` with the indicated values.

### See also

- See [test-stack](/test-stack/README.md) for more examples. 
  This testing environment simulates a complete stack : traefik + acme server acting like Let's Encrypt, have a look! 
- [Configuration for multidomains](/test/files/docker-compose.traefik.v1.multidomains.yml)
- [Configuration for multiservers](/test/files/docker-compose.traefik.v1.multiservers.yml)
- Use `make tests` to run tests (docker-compose is required, swarm will be activated then disabled).
- [tests](/test) - Tests directory contains useful resources listing different usages (multidomains, multiservers, etc).
- [traefik-certs-dumper](https://github.com/ldez/traefik-certs-dumper) - Used in this image for watching certificates
### Licence
MIT