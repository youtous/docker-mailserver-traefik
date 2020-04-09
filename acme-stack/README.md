# ACME Testing environment

_inspired from Traefik 1.7 acme stack_

## Objectives

In order to simulate ACME, we use **boulder** (https://github.com/letsencrypt/boulder) for simulating Let's encrypt.

The goal of this stack is to provide an environment for testing certificates extraction and management.
This environment will be useful for CI Tests.

The provided stack is based on the environment testing stack from **boulder** : https://github.com/letsencrypt/boulder/blob/master/docker-compose.yml plus
traefik, a basic **docker-mailserver** and the **mailserver-traefik** for certificates renewing.

## Directory content
Depending of the storage strategy used by traefik, different stacks are proposed.

### Traefik using file `acme.json` as storage solution
* **docker-compose.file.yml** : docker-Compose file which contains the described above stack.
* **acme.file.toml** : traefik configuration file.
* **manage_acme-file_docker_environment.sh** : shell script which helps setting up the stack

### Traefik using file **consul** kv store as storage solution
* **docker-compose.consul.yml** : docker-Compose file which contains the described above stack plus a _consul_ container.
* **acme.consul.toml** : traefik configuration file.
* **manage_acme-consul_docker_environment.sh** : shell script which helps setting up the stack

## Script Usage

The script **manage_acme-{consul/file}_docker_environment.sh** requires one argument. This argument can have 3 values :

* **--start** : Launch a new Docker environment Boulder + Traefik + (eventually Consul) + Mailstack (mailserver, autorenew-certs).
* **--stop** : Stop and delete the current Docker environment.
* **--restart--** : Concatenate **--stop** and **--start** actions.
* **--dev** : Launch a new Boulder Docker environment.
