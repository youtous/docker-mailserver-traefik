#!/usr/bin/env bash

. ./common.sh --source-only

# Handler watch for changes of given certificates from traefik, if a change occurs :
#   1. extract certificates and save them in a temporary directory
#   2. trigger "trigger-push.sh" for pushing certificates in matching mailserver containers
#   3. Finished! Certificates of the mailservers are renewed and services restarted

# helper for keeping restarting a command while KV is not ready
function start_handler_kv() {
  start_time=$SECONDS

  while true; do
    # cleanup SSL destination
    rm -Rf "${SSL_DEST:?/tmp/ssl}/*"

    # disable or not periodical push
    if [ "$PUSH_PERIOD" = "0" ]; then
      { errors=$("$@" 2>&1 >&3 3>&-); } 3>&1
    else
      { errors=$(timeout "$PUSH_PERIOD" "$@" 2>&1 >&3 3>&-); } 3>&1
    fi
    exit_code=$?


    # handle error
    if [ "$exit_code" -eq 0 ]; then
      echo "[ERROR] Unexcepted ending of the program. EXIT_CODE=$exit_code"
      exit 1
    elif [ "$exit_code" -eq 143 ]; then
      echo "[INFO] Periodically push initiated..."
    else
      # depending of the error, handle it
      # handle kv error at init
      must_continue=$(echo "$errors" | grep -Fq 'could not fetch Key/Value pair for key' && echo 1 || echo 0)

      if [ "$must_continue" ]; then
        # silence KV error
        echo "[INFO] KV Store (/$KV_PREFIX$KV_SUFFIX) not accessible. Waiting until KV is up and populated by traefik.."

        # check if restart does not timeout
        if [[ $(($SECONDS - $start_time)) -gt $INITIAL_TIMEOUT ]]; then
          echo "$errors" >/dev/stderr
          echo "[ERROR] Timed out on initial kv connection (initial timeout=${INITIAL_TIMEOUT}s), please check KV config and ensure KV Store is up"
          exit 1
        fi
      else
        # fatal error
        echo "$errors" >/dev/stderr
        echo "[ERROR] Fatal error: exit of the program EXIT_CODE=$exit_code"
        exit $exit_code
      fi
    fi

    # wait before restarting
    sleep 5
  done
}

# helper which keep restarting periodicaly the certificate puller every period
function start_handler() {

  while true; do
    # cleanup SSL destination
    rm -Rf "${SSL_DEST:?/tmp/ssl}/*"

    # disable or not periodical push
    if [ "$PUSH_PERIOD" = "0" ]; then
      "$@"
    else
      timeout "$PUSH_PERIOD" "$@"
    fi
    exit_code=$?

    # handle error
    if [ "$exit_code" -eq 0 ]; then
      echo "[ERROR] Unexcepted ending of the program. EXIT_CODE=$exit_code"
      exit 1
    elif [ "$exit_code" -eq 143 ]; then
      echo "[INFO] Periodically push initiated..."
    else
      echo "[ERROR] Fatal error: exit of the program EXIT_CODE=$exit_code"
      exit $exit_code
    fi

    # wait before restarting
    sleep 5
  done
}

### Beginning of the script

if isSwarmNode; then
  echo "[INFO] Running on a swarm cluster node."
else
  echo "[INFO] Running on a regular host."
fi

if [ "$DOMAINS" = "missingdomains" ]; then
  echo "[ERROR] DOMAINS var is not defined. Please define DOMAINS. Abort..."
  exit 1
fi
IFS=',' read -ra DOMAINS_ARRAY <<<"$DOMAINS"
echo "[INFO] ${#DOMAINS_ARRAY[@]} domain(s) to watch: $DOMAINS"

POST_HOOK="/trigger-push.sh"
CERT_NAME=fullchain
CERT_EXTENSION=.pem
KEY_NAME=privkey
KEY_EXTENSION=.pem

# ensure kv endpoint are defined when using kv store strategy
if [ -z "$KV_ENDPOINTS" ] && [ "$CERTS_SOURCE" != "file" ]; then
  echo "[ERROR] KV_ENDPOINTS var is not defined. Please define KV_ENDPOINTS. Abort..."
  exit 1
fi

if [ "$PUSH_PERIOD" = "0" ]; then
  echo "[INFO] Periodically push to containers is disabled (PUSH_PERIOD=$PUSH_PERIOD)."
else
  echo "[INFO] Configured to automatically push existing certificates in containers every $PUSH_PERIOD (PUSH_PERIOD=$PUSH_PERIOD)."
fi

# watch for certificate renewed
echo "[INFO] $CERTS_SOURCE selected as certificates source"
if [ "$CERTS_SOURCE" = "file" ]; then

  # checking traefik target version
  echo "[INFO] Traefik v$TRAEFIK_VERSION selected as target"
  if [ "$TRAEFIK_VERSION" = 1 ]; then
    echo ""
  elif [ "$TRAEFIK_VERSION" = 2 ]; then
    echo ""
  else
    echo "[ERROR] Unknown selected traefik version v$TRAEFIK_VERSION"
    exit 1
  fi

  ACME_SOURCE=/tmp/traefik/acme.json

  start_time=$SECONDS
  while [ ! -f $ACME_SOURCE ] || [ ! -s $ACME_SOURCE ]; do
    echo "[INFO] $ACME_SOURCE is empty or does not exist. Waiting until file is created..."

    # check if not timeout
    if [[ $(($SECONDS - $start_time)) -gt $INITIAL_TIMEOUT ]]; then
      echo "$errors" >/dev/stderr
      echo "[ERROR] Timed out on initial acme ($ACME_SOURCE) watching (initial timeout=${INITIAL_TIMEOUT}s)"
      exit 1
    fi
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

  start_handler traefik-certs-dumper file \
    --version "v$TRAEFIK_VERSION" \
    --clean \
    --source "$ACME_SOURCE" \
    --dest "$SSL_DEST" \
    --domain-subdir \
    --watch \
    --crt-name "$CERT_NAME" \
    --crt-ext "$CERT_EXTENSION" \
    --key-name "$KEY_NAME" \
    --key-ext "$KEY_EXTENSION" \
    --post-hook "$POST_HOOK"

elif [ "$CERTS_SOURCE" = "consul" ]; then

  # shellcheck disable=SC2059
  printf "[INFO] $CERTS_SOURCE KV Store configuration: endpoints=$KV_ENDPOINTS, username=$KV_USERNAME,
          timeout=$KV_TIMEOUT, prefix=$KV_PREFIX, suffix=$KV_SUFFIX, tls=$KL_TLS_ENABLED,
          ca_optional=$KV_TLS_CA_OPTIONAL, tls_trust_insecure=$KV_TLS_TRUST_INSECURE\n\n"

  start_handler_kv traefik-certs-dumper kv "$CERTS_SOURCE" \
    --endpoints "$KV_ENDPOINTS" \
    --clean \
    --dest "$SSL_DEST" \
    --domain-subdir \
    --watch \
    --crt-name "$CERT_NAME" \
    --crt-ext "$CERT_EXTENSION" \
    --key-name "$KEY_NAME" \
    --key-ext "$KEY_EXTENSION" \
    --prefix "$KV_PREFIX" \
    --suffix "$KV_SUFFIX" \
    "$(if [ -n "$KV_TIMEOUT" ]; then echo "--connection-timeout $KV_TIMEOUT"; fi)" \
    "$(if [ -n "$KV_USERNAME" ]; then echo "--username $KV_USERNAME"; fi)" \
    "$(if [ -n "$KV_PASSWORD" ]; then echo "--password $KV_PASSWORD"; fi)" \
    "$(if [ -n "$KV_TLS_CA" ]; then echo "--tls.ca $KV_TLS_CA"; fi)" \
    "$(if [ -n "$KV_TLS_CERT" ]; then echo "--tls.cert $KV_TLS_CERT"; fi)" \
    "$(if [ -n "$KV_TLS_KEY" ]; then echo "--tls.key $KV_TLS_KEY"; fi)" \
    "$(if [ -n "$KV_CONSUL_TOKEN" ]; then echo "--token $KV_CONSUL_TOKEN"; fi)" \
    "$(if [ "$KL_TLS_ENABLED" -eq 1 ]; then echo "--tls"; fi)" \
    "$(if [ "$KV_TLS_CA_OPTIONAL" -eq 1 ]; then echo "--tls.ca.optional"; fi)" \
    "$(if [ "$KV_TLS_TRUST_INSECURE" -eq 1 ]; then echo "--tls.insecureskipverify"; fi)" \
    --post-hook "$POST_HOOK"

elif [ "$CERTS_SOURCE" = "boltdb" ]; then

  # shellcheck disable=SC2059
  printf "[INFO] $CERTS_SOURCE KV Store configuration: endpoints=$KV_ENDPOINTS, username=$KV_USERNAME,
          timeout=$KV_TIMEOUT, prefix=$KV_PREFIX, suffix=$KV_SUFFIX, bucket=$KV_BOLTDB_BUCKET,
          tls=$KL_TLS_ENABLED, ca_optional=$KV_TLS_CA_OPTIONAL, tls_trust_insecure=$KV_TLS_TRUST_INSECURE\n\n"

  start_handler_kv traefik-certs-dumper kv "$CERTS_SOURCE" \
    --endpoints "$KV_ENDPOINTS" \
    --clean \
    --dest "$SSL_DEST" \
    --domain-subdir \
    --watch \
    --crt-name "$CERT_NAME" \
    --crt-ext "$CERT_EXTENSION" \
    --key-name "$KEY_NAME" \
    --key-ext "$KEY_EXTENSION" \
    --prefix "$KV_PREFIX" \
    --suffix "$KV_SUFFIX" \
    "$(if [ -n "$KV_TIMEOUT" ]; then echo "--connection-timeout $KV_TIMEOUT"; fi)" \
    "$(if [ -n "$KV_USERNAME" ]; then echo "--username $KV_USERNAME"; fi)" \
    "$(if [ -n "$KV_PASSWORD" ]; then echo "--password $KV_PASSWORD"; fi)" \
    "$(if [ -n "$KV_TLS_CA" ]; then echo "--tls.ca $KV_TLS_CA"; fi)" \
    "$(if [ -n "$KV_TLS_CERT" ]; then echo "--tls.cert $KV_TLS_CERT"; fi)" \
    "$(if [ -n "$KV_TLS_KEY" ]; then echo "--tls.key $KV_TLS_KEY"; fi)" \
    "$(if [ -n "$KV_BOLTDB_BUCKET" ]; then echo "--bucket $KV_BOLTDB_BUCKET"; fi)" \
    "$(if [ "$KL_TLS_ENABLED" -eq 1 ]; then echo "--tls"; fi)" \
    "$(if [ "$KV_TLS_CA_OPTIONAL" -eq 1 ]; then echo "--tls.ca.optional"; fi)" \
    "$(if [ "$KV_TLS_TRUST_INSECURE" -eq 1 ]; then echo "--tls.insecureskipverify"; fi)" \
    "$(if [ "$KV_BOLTDB_PERSIST_CONNECTION" -eq 1 ]; then echo "--persist-connection"; fi)" \
    --post-hook "$POST_HOOK"

elif [ "$CERTS_SOURCE" = "etcd" ]; then

  # shellcheck disable=SC2059
  printf "[INFO] $CERTS_SOURCE KV Store configuration: version=$KV_ETCD_VERSION, endpoints=$KV_ENDPOINTS, username=$KV_USERNAME,
          timeout=$KV_TIMEOUT, sync-period=$KV_ETCD_SYNC_PERIOD, prefix=$KV_PREFIX, suffix=$KV_SUFFIX, tls=$KL_TLS_ENABLED,
          ca_optional=$KV_TLS_CA_OPTIONAL, tls_trust_insecure=$KV_TLS_TRUST_INSECURE\n\n"

  start_handler_kv traefik-certs-dumper kv "$CERTS_SOURCE" \
    --endpoints "$KV_ENDPOINTS" \
    --clean \
    --dest "$SSL_DEST" \
    --domain-subdir \
    --watch \
    --crt-name "$CERT_NAME" \
    --crt-ext "$CERT_EXTENSION" \
    --key-name "$KEY_NAME" \
    --key-ext "$KEY_EXTENSION" \
    --prefix "$KV_PREFIX" \
    --suffix "$KV_SUFFIX" \
    --etcd-version "$KV_ETCD_VERSION" \
    "$(if [ -n "$KV_TIMEOUT" ]; then echo "--connection-timeout $KV_TIMEOUT"; fi)" \
    "$(if [ -n "$KV_USERNAME" ]; then echo "--username $KV_USERNAME"; fi)" \
    "$(if [ -n "$KV_PASSWORD" ]; then echo "--password $KV_PASSWORD"; fi)" \
    "$(if [ -n "$KV_TLS_CA" ]; then echo "--tls.ca $KV_TLS_CA"; fi)" \
    "$(if [ -n "$KV_TLS_CERT" ]; then echo "--tls.cert $KV_TLS_CERT"; fi)" \
    "$(if [ -n "$KV_TLS_KEY" ]; then echo "--tls.key $KV_TLS_KEY"; fi)" \
    "$(if [ -n "$KV_ETCD_SYNC_PERIOD" ]; then echo "--sync-period $KV_ETCD_SYNC_PERIOD"; fi)" \
    "$(if [ "$KL_TLS_ENABLED" -eq 1 ]; then echo "--tls"; fi)" \
    "$(if [ "$KV_TLS_CA_OPTIONAL" -eq 1 ]; then echo "--tls.ca.optional"; fi)" \
    "$(if [ "$KV_TLS_TRUST_INSECURE" -eq 1 ]; then echo "--tls.insecureskipverify"; fi)" \
    --post-hook "$POST_HOOK"

elif [ "$CERTS_SOURCE" = "zookeeper" ]; then

  # shellcheck disable=SC2059
  printf "[INFO] $CERTS_SOURCE KV Store configuration: endpoints=$KV_ENDPOINTS, username=$KV_USERNAME,
          timeout=$KV_TIMEOUT, prefix=$KV_PREFIX, suffix=$KV_SUFFIX, tls=$KL_TLS_ENABLED,
          ca_optional=$KV_TLS_CA_OPTIONAL, tls_trust_insecure=$KV_TLS_TRUST_INSECURE\n\n"

  start_handler_kv traefik-certs-dumper kv "$CERTS_SOURCE" \
    --endpoints "$KV_ENDPOINTS" \
    --clean \
    --dest "$SSL_DEST" \
    --domain-subdir \
    --watch \
    --crt-name "$CERT_NAME" \
    --crt-ext "$CERT_EXTENSION" \
    --key-name "$KEY_NAME" \
    --key-ext "$KEY_EXTENSION" \
    --prefix "$KV_PREFIX" \
    --suffix "$KV_SUFFIX" \
    "$(if [ -n "$KV_TIMEOUT" ]; then echo "--connection-timeout $KV_TIMEOUT"; fi)" \
    "$(if [ -n "$KV_USERNAME" ]; then echo "--username $KV_USERNAME"; fi)" \
    "$(if [ -n "$KV_PASSWORD" ]; then echo "--password $KV_PASSWORD"; fi)" \
    "$(if [ -n "$KV_TLS_CA" ]; then echo "--tls.ca $KV_TLS_CA"; fi)" \
    "$(if [ -n "$KV_TLS_CERT" ]; then echo "--tls.cert $KV_TLS_CERT"; fi)" \
    "$(if [ -n "$KV_TLS_KEY" ]; then echo "--tls.key $KV_TLS_KEY"; fi)" \
    "$(if [ "$KL_TLS_ENABLED" -eq 1 ]; then echo "--tls"; fi)" \
    "$(if [ "$KV_TLS_CA_OPTIONAL" -eq 1 ]; then echo "--tls.ca.optional"; fi)" \
    "$(if [ "$KV_TLS_TRUST_INSECURE" -eq 1 ]; then echo "--tls.insecureskipverify"; fi)" \
    --post-hook "$POST_HOOK"
else
  echo "[ERROR] Unknown selected certificates source '$CERTS_SOURCE'"
  exit 1
fi

echo "[ERROR] Fatal error, the program will exit..."
exit 1
