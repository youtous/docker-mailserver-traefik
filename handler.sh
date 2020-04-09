#!/bin/sh

# Handler watch for changes of given certificates, if a change occurs :
#   1. extract the certificate and save it as a docker secret
#   2. Mount the docker secret on the docker-mailserver stack
#   3. Launch docker-mailserver renew certificates script
#   4. Finished! Certificates of the docker-mailserver are renewed and services restarted


# docker secret create _mailserver-traefik__crt
ls /tmp
echo "hello world!"

while true; do
  sleep 2
done