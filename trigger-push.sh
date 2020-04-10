#!/usr/bin/env bash

# The trigger script is called when certificates have been changed from traefik.
# For each domain, this script will push certificates in matching containers (using label directive)
# then, the tomav-renew-certs script will be executed in the target container allowing the mailserver to renew its certificates.

LABEL="mailserver-traefik.renew.domain"
RENEW_CERTIFICATES_SCRIPT="/tomav-renew-certs.bash"

IFS=',' read -ra DOMAINS_ARRAY <<< "$DOMAINS"
for domain in "${DOMAINS_ARRAY[@]}" ; do

  cert_name_directory="$SSL_DEST/$domain"
  
  if [ ! -d "$cert_name_directory" ]; then
        echo "[INFO] certificate for $domain not yet generated, skipping push..."
        continue
  fi

  # listing dockermailserver containers using label
  targets_id=( $(docker ps --filter="label=${LABEL}=${domain}" --format "{{ .ID }}") )

  echo "[INFO] Pushing $domain to ${#targets_id[@]} subscribed containers"
  for container_id in "${targets_id[@]}" ; do

      echo "[INFO] Pushing $domain certificate in container $container_id"
      # copy certificate and renew script to container
      docker cp "$RENEW_CERTIFICATES_SCRIPT" "$container_id":/
      docker cp "$cert_name_directory/." "$container_id":/tmp/ssl/

      # execute renew certificates on mailserver
      docker exec "$container_id" "$RENEW_CERTIFICATES_SCRIPT"
  done

done