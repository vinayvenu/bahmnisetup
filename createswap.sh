#!/bin/sh

sudo dd if=/dev/zero of=/swapfile bs=1024 count=4096k
sudo mkswap /swapfile
sudo swapon /swapfile
echo "/swapfile          swap            swap    defaults        0 0" >> /etc/fstab

exit 0
