#!/usr/bin/env sh

until ping -c 1 pebble
do
   echo "waiting pebble to be up..."
   sleep 1
done

pebble_ip=$(ping -c 1 pebble | grep '64 bytes from ' | awk '{print $4}' | cut -d':' -f1)
echo "$pebble_ip      acme.localhost.com" >> /etc/hosts
