# Testing environment

## Objectives

This stack simulates an Traefik environnment and a docker-mailserver environnement. It embeds an ACME server (pebble) acting like Let's Encrypt
in order to simulate certificates generate.

The goal of this stack is to provide an environment for testing certificates extraction and management using the automatic mailserver-traefik certificate renewer.

Learn more about **peeble**: https://github.com/letsencrypt/pebble


## Basic Usage

The **Makefile** helps to use the stack.

1. Start the stack : `make start`
1. Done! Certificates will be generated and shared to the tagged **docker-mailserver** container.

Usage: ` make <target>`
```
  stop             Stop the stack.
  start            Start the entire stack.
  start-acme       Start ACME part of the stack.
  start-traefik    Start traefik part of the stack.
  start-mailserver  Start mailserver part of the stack.
  restart          Restart the entire stack.
  rebuild          Rebuild the docker stack, remove old images. This command will stop the stack.
  build            Build the docker stack, remove old images. This command will stop the stack.
  test             Run all the tests of the application.
  init-traefik-env  Init traefik env, create needed files
  help             Show this help prompt.
```

You can detach the stack using `ARGS=-d`, for instance `make start ARGS=-d` will start the stack detached.

_Take a look of the Makefile content for the list used commands ;)_

### Storage strategies

List of storage strategies:
- **`file.v2`** : traefik v2 using a `acme.json` file
- **`file`** : traefik v1 using a `acme.json` file
- **`consul`** : traefik v1 using a consul instance

By default, `acme.json` file is used by _traefik_ as storage strategy. 
However, other storage solutions such as _consul_ are available.

For using _consul_, set the variable `STORAGE_STRATEGY=consul` then use `make start`.
```bash
STORAGE_STRATEGY=consul make start

# or using environement variable

set -x STORAGE_STRATEGY "consul"
make start
```

### Defining hosts
In this stack example, certificates are generated for subdomains of `localhost.com`.
In order to access these domain from the docker host, you have to edit the hosts file.

Add this to the content of `/etc/hosts`
```
# /etc/hosts
# traefik dev
127.0.0.1       localhost.com
127.0.0.1       traefik.localhost.com
127.0.0.1       acme.localhost.com
127.0.0.1       consul.localhost.com
```

## Directory content
Depending of the storage strategy used by traefik, different stacks are proposed.

#### Traefik using `acme.json` file as storage strategy
* **docker-compose.file.yml** : docker-compose file which contains the described above stack.
* **docker-compose.file.v2.yml** : same as `docker-compose.file.yml` but using **traefik v2**.
* **acme.file.toml** : traefik configuration file.
* **traefik.v2.file.toml** : traefik v2 configuration file.

#### Traefik using _consul_ as storage strategy
* **docker-compose.consul.yml** : docker-compose file which contains the described above stack plus a _consul_ container.
* **acme.consul.toml** : traefik configuration file.


