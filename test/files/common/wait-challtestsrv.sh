#!/usr/bin/env sh

until ping -c 1 challtestsrv
do
   echo "waiting challtestsrv to be up..."
   sleep 1
done

sleep 10
