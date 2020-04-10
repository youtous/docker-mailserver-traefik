#!/bin/bash

# from https://github.com/hanscees/dockerscripts/blob/master/scripts/tomav-renew-certs
#script for tomav mailserver https://github.com/tomav/docker-mailserver/
#script checks if new letsencrypt certificates are present in config dir.
#if so they are copied and daemons restarted

Currentcert=/etc/postfix/ssl/cert
CurrentcertD=/etc/postfix/ssl/cert #dovecot
Newcert=/tmp/ssl/fullchain.pem
Currentkey=/etc/postfix/ssl/key
CurrentkeyD=/etc/postfix/ssl/key #dovecot
Newkey=/tmp/ssl/privkey.pem
Backupkey="$Newkey.backup"
Backupcert="$Newcert.backup"

if [ ! -f "$Newcert" ]; then
    echo "[ERROR] renew certificates script called without submitting a new certificate in $Newcert"
    exit 1
fi
if [ ! -f "Newkey" ]; then
    echo "[ERROR] renew certificates script called without submitting a new key in $Newkey"
    exit 1
fi


echo "[INFO] new certificate '$Newcert' received on mailserver container"

# take fingerprints
FP_CurrentC=`openssl x509 -fingerprint -nocert -in $Currentcert`
FP_NewC=`openssl x509 -fingerprint -nocert -in $Newcert`

#fingerprint should be a long string
stringlenght=${#FP_NewC}
if [ ! $stringlenght -gt 50 ]; then
    echo "[ERROR] fingerprint of new certificate is too short = $stringlenght, dealing with an invalid certificate"
    exit 1
fi


# echo "[DEBUG] FP Currentcert is $FP_CurrentC"
# echo "[DEBUG] FP Newcert is $FP_NewC"


#test if FP are different, if yes let take actions
if [ "$FP_NewC" = "$FP_CurrentC" ]; then
  echo "[DEBUG] FPs match, do nothing"
else

  # cp new certificate, update permissions
  cp $Newcert $Currentcert
  cp $Newkey $Currentkey
  chmod 600 $Currentcert
  chmod 600 $Currentkey

  logger "[INFO] Cert update: new certificates have been copied into container"

  logger "[INFO] Cert update: restarting daemons Postfix and Dovecot"
  supervisorctl restart postfix
  supervisorctl restart dovecot

  # move to backup for memory
  mv $Newkey $Backupkey
  mv $Newcert $Backupcert
fi
