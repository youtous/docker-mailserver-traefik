#!/usr/bin/env bash

# Handler watch for changes of given certificates from traefik, if a change occurs :
#   1. extract certificates and save them in a temporary directory
#   2. trigger "trigger-push.sh" for pushing certificates in matching mailserver containers
#   3. Finished! Certificates of the mailservers are renewed and services restarted

echo "[INFO] Traefik v$TRAEFIK_VERSION selected as target"
if [ "$TRAEFIK_VERSION" = 1 ]; then
  echo ""
elif [ "$TRAEFIK_VERSION" = 2 ]; then
  echo ""
else
    echo "[ERROR] Unknown selected traefik version v$TRAEFIK_VERSION"
    exit 1
fi

IFS=',' read -ra DOMAINS_ARRAY <<< "$DOMAINS"
echo "[INFO] ${#DOMAINS_ARRAY[@]} domain(s) to watch: $DOMAINS"

POST_HOOK="/trigger-push.sh"
CERT_NAME=fullchain
CERT_EXTENSION=.pem
KEY_NAME=privkey
KEY_EXTENSION=.pem

# cleanup SSL destination
rm -Rf "$SSL_DEST/*"

# watch for certificate renewed
echo "[INFO] $CERTS_SOURCE selected as certificates source"
if [ "$CERTS_SOURCE" = "file" ]; then
  ACME_SOURCE=/tmp/acme.json

  while [ ! -f $ACME_SOURCE ] || [ ! -s $ACME_SOURCE ]; do
      echo "[INFO] $ACME_SOURCE is empty or does not exists. Waiting until file is created..."
      sleep 5
  done

  # check generated config is valid
  EMPTY_KEY="\"KeyType\": \"\""
  while true; do
      if grep -q "$EMPTY_KEY" "$ACME_SOURCE"; then
        echo "[INFO] Traefik acme is generating. Waiting until completed..."
        sleep 5
      else
        break
      fi
  done

  traefik-certs-dumper file\
    --version "v$TRAEFIK_VERSION"\
    --clean\
    --source $ACME_SOURCE\
    --dest $SSL_DEST\
    --domain-subdir --watch\
    --crt-name=$CERT_NAME\
    --crt-ext $CERT_EXTENSION\
    --key-name=$KEY_NAME\
    --key-ext=$KEY_EXTENSION\
    --post-hook $POST_HOOK

elif [ "$CERTS_SOURCE" = "consul" ]; then

  # shellcheck disable=SC2059
  printf "[INFO] KV Store configuration: endpoints=$KV_ENDPOINTS, username=$KV_USERNAME,
          timeout=$KV_TIMEOUT, prefix=$KV_PREFIX, suffix=$KV_SUFFIX
          ca_optional=$KV_TLS_CA_OPTIONAL, tls_trust_insecure=$KV_TLS_TRUST_INSECURE
          "

  traefik-certs-dumper kv "$CERTS_SOURCE"\
    --endpoints "$KV_ENDPOINTS"\
    --clean\
    --dest $SSL_DEST\
    --domain-subdir --watch\
    --crt-name=$CERT_NAME\
    --crt-ext $CERT_EXTENSION\
    --key-name=$KEY_NAME\
    --key-ext=$KEY_EXTENSION\
    --post-hook $POST_HOOK

elif [ "$CERTS_SOURCE" = "boltdb" ]; then
    echo ""
elif [ "$CERTS_SOURCE" = "etcd" ]; then
    echo ""
elif [ "$CERTS_SOURCE" = "zookeeper" ]; then
    echo ""
else
    echo "[ERROR] Unknown selected certificates source '$CERTS_SOURCE'"
    exit 1
fi

