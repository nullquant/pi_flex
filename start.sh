#!/bin/sh -e

DEVICE=$(nmcli device | grep -E "eth0|end0" | cut -d ' ' -f 1)
/home/orangepi/linux-router/lnxrouter -n -i $DEVICE -g 192.168.128.1 --no-dns --dhcp-dns 1.1.1.1
sudo -u orangepi /usr/bin/git -C /home/orangepi/pi_flex pull
