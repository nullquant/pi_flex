#!/bin/bash

exec 2> /home/orangepi/lnxrouter.log
exec 1>&2
set -x

DEVICE=$(nmcli device | grep -E "eth0|end0" | cut -d ' ' -f 1)
/home/orangepi/linux-router/lnxrouter -n -i $DEVICE -g 192.168.128.1 --no-dns --dhcp-dns 1.1.1.1
