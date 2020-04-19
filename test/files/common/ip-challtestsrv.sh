#!/usr/bin/env sh

until ping -c 1 traefik
do
   echo "waiting traefik to be up..."
   sleep 1
done

pebble-challtestsrv -defaultIPv6 "" -defaultIPv4 "$(ping -c 1 traefik | grep '64 bytes from ' | awk '{print $4}' | cut -d':' -f1)"
