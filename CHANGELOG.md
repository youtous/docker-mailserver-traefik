# CHANGELOG - youtous/docker-mailserver-traefik/

## v1.4.0

* handle docker-mailserver v10.2.0+ : new internal ssl location (backward compatible if you use an older version)
* update traefik-certs-dumper to v2.8.1
* added docker image multi-arch: amd64,arm64,386
* improved tests: docker-compose v2, openssl tests on certificates
* improved documentation, CHANGELOG created