#!/bin/bash

# This script is installed on the mailserver, it must be called after pushing new certificates
# on the mailserver.
# When the script is called, it checks if submited certificates are different and eventually update postfix/dovecot
# certificates.

# Forked from https://github.com/hanscees/dockerscripts/blob/master/scripts/tomav-renew-certs


Currentcert=/etc/postfix/ssl/cert # should not be changed, hardcoded in mailserver
Newcert=/tmp/ssl/fullchain.pem
Currentkey=/etc/postfix/ssl/key
Newkey=/tmp/ssl/privkey.pem
Backupkey="$Newkey.backup"
Backupcert="$Newcert.backup"
FQDN=$(hostname --fqdn)

if [ ! -f "$Newcert" ]; then
    echo "[ERROR] $FQDN - renew certificates script called without submitting a new certificate in $Newcert"
    exit 1
fi
if [ ! -f "$Newkey" ]; then
    echo "[ERROR] $FQDN - renew certificates script called without submitting a new key in $Newkey"
    exit 1
fi


echo "[INFO] $FQDN - new certificate '$Newcert' received on mailserver container"

# create cert directory if does not exists
mkdir -p "$(dirname $Currentcert)"
mkdir -p "$(dirname $Currentkey)"

FP_NewC=$(openssl x509 -fingerprint -nocert -in $Newcert)
if [ -f $Currentcert ]; then
  # take fingerprints if existing certs
  FP_CurrentC=$(openssl x509 -fingerprint -nocert -in $Currentcert)

  #fingerprint should be a long string
  stringlenght=${#FP_NewC}
  if [ ! "$stringlenght" -gt 50 ]; then
      echo "[ERROR] $FQDN - fingerprint of new certificate is too short = $stringlenght, dealing with an invalid certificate"
      exit 1
  fi
else
  # first import
  FP_CurrentC=""
fi


# echo "[DEBUG] FP Currentcert is $FP_CurrentC"
# echo "[DEBUG] FP Newcert is $FP_NewC"


# test if FP are different, if yes let take actions
if [ "$FP_NewC" = "$FP_CurrentC" ]; then
  echo "[DEBUG] $FQDN - FPs match, no change detected on certificate, nothing to do..."
else

  # cp new certificate, update permissions
  cp $Newcert $Currentcert
  cp $Newkey $Currentkey
  chmod 600 $Currentcert
  chmod 600 $Currentkey

  echo "[INFO] $FQDN - Cert update: new certificate copied into container"

  echo "[INFO] $FQDN - Cert update: restarting daemons Postfix and Dovecot"
  supervisorctl restart postfix
  supervisorctl restart dovecot

  # move to backup for memory
  mv $Newkey $Backupkey
  mv $Newcert $Backupcert
fi
