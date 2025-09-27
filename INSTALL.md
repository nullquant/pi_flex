# MODBUS SERVER on OrangePI zero 3

### OrangePI Install

Manual: http://www.orangepi.org/orangepiwiki/index.php/Orange_Pi_Zero_3

Download image from http://www.orangepi.org/html/hardWare/computerAndMicrocontrollers/service-and-support/Orange-Pi-Zero-3.html

### Install by script

wget https://github.com/nullquant/pi_flex/raw/refs/heads/main/install.sh
chmod +x install.sh
sudo ./install.sh


sudo -u orangepi /usr/bin/git -C /home/orangepi/pi_flex pull





### Raspberry PI

    sudo nano /usr/local/rtr-startup-script

#!/bin/sh -e
#

/home/pi/linux-router/lnxrouter -n -i end0 -g 192.168.128.1 --no-dns  --dhcp-dns 1.1.1.1

exit 0

    sudo chmod +x /usr/local/rtr-startup-script


    sudo nano /etc/systemd/system/rtr-startup.service

[Service]
Type=oneshot
RemainAfterExit=yes
ExecStart=/usr/local/rtr-startup-script

[Install]
WantedBy=multi-user.target

    sudo systemctl enable rtr-startup.service





Proxy port 5900 for VNC


# SNIFFER

### WiFi AP with Ethernet at eth0
    sudo create_ap -m nat wlan0 eth0 pipoint pi34wifi --no-virt --daemon

### find IP adresses of WiFi clients
    sudo more /tmp/create_ap.wlan0.conf.VpOpcZ7B/dnsmasq.leases

### Capture packets
    sudo tcpdump -i wlan0 host 192.168.12.170
    sudo tcpdump -A -i wlan0 host 192.168.12.170 -x

### Stop
    sudo create_ap --stop wlan0
