#!/usr/bin/env sh

until dig +short dummy.localhost.com @challtestsrv -p 8053
do
   echo "waiting challtestsrv DNS to be up..."
   sleep 1
done
echo "challtestsrv DNS is up"