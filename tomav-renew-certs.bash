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

#check if a new cert is present
echo "newcert is $Newcert"
if [ -f "$Newcert" ]
then
  echo "new certificate detected"
  #take fingerprints
  FP_CurrentC=`openssl x509 -fingerprint -nocert -in $Currentcert`
  FP_NewC=`openssl x509 -fingerprint -nocert -in $Newcert`
  echo "FP Curry is $FP_CurrentC"
  echo "FP New is $FP_NewC"
  #check sanity pemfile
  stringlenght=${#FP_NewC}  #fingerprint should be a long string
  echo " length is $stringlenght"
  if [ $stringlenght -gt 50 ]
  then
          echo sane
          #test if FP are different, if yes let take actions
          if [ "$FP_NewC" = "$FP_CurrentC" ]
          then
                  echo " FPs match, do nothing"
                  logger "Cert update: certificate update started, but something went wrong, check newcerts perhaps"
          else
                  cp $Newcert $Currentcert
                  cp $Newkey $Currentkey
                  chmod 600 $Currentcert
                  chmod 600 $Currentkey
                  logger "Cert update: new certificates have been copied into container"
                  logger "Cert update: restarting daemons Postfix and Dovecot"
                  supervisorctl restart postfix
                  supervisorctl restart dovecot
                mv $Newkey $Backupkey
                  mv $Newcert $Backupcert
          fi
  fi
logger "Cert update: Newcert script exited fine"
fi
