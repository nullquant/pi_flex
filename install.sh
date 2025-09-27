#!/bin/bash

# Exit immediately if a command exits with a non-zero status.
set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${GREEN}Setting timezone...${NC}"
sudo timedatectl set-timezone Europe/Moscow

# Changing apt sources
echo -e "${GREEN}Changing apt sources...${NC}"
sudo rm -f /etc/apt/sources.list
sudo cat > /etc/apt/sources.list <<- "EOF"
deb http://mirrors.huaweicloud.com/debian bookworm main contrib non-free non-free-firmware
#deb http://repo.huaweicloud.com/debian bookworm main contrib non-free non-free-firmware
#deb-src http://repo.huaweicloud.com/debian bookworm main contrib non-free non-free-firmware

deb http://mirrors.huaweicloud.com/debian bookworm-updates main contrib non-free non-free-firmware
#deb http://repo.huaweicloud.com/debian bookworm-updates main contrib non-free non-free-firmware
#deb-src http://repo.huaweicloud.com/debian bookworm-updates main contrib non-free non-free-firmware

deb http://mirrors.huaweicloud.com/debian bookworm-backports main contrib non-free non-free-firmware
#deb http://repo.huaweicloud.com/debian bookworm-backports main contrib non-free non-free-firmware
#deb-src http://repo.huaweicloud.com/debian bookworm-backports main contrib non-free non-free-firmware
EOF

# Update the package lists
echo -e "${GREEN}Running apt update...${NC}"
sudo apt update

# Upgrade installed packages without prompting for confirmation
echo -e "${GREEN}Running apt upgrade...${NC}"
sudo apt upgrade -y

# Install Erlang 25
echo -e "${GREEN}Installing Erlang...${NC}"
sudo apt install git wget erlang iptables -y

# Perform a distribution upgrade, handling dependencies and removing obsolete packages
echo -e "${GREEN}Running apt dist-upgrade...${NC}"
sudo apt dist-upgrade -y

# Clean up unnecessary packages
echo -e "${GREEN}Cleaning up unnecessary packages...${NC}"
sudo apt autoremove -y
sudo apt clean

# Install Elixir 1.18.3
if [ -d /opt/elixir ]; then
  echo -e "${GREEN}Installing Elixir 1.18.3 / OTP 25...already installed${NC}"
else
  echo -e "${GREEN}Installing Elixir 1.18.3 / OTP 25...${NC}"
  cd /opt
  sudo mkdir elixir
  cd elixir
  sudo wget https://github.com/elixir-lang/elixir/releases/download/v1.18.3/elixir-otp-25.zip
  sudo unzip elixir-otp-25.zip
  sudo rm elixir-otp-25.zip
  sudo ln -s /opt/elixir/bin/elixirc /usr/local/bin/elixirc
  sudo ln -s /opt/elixir/bin/elixir /usr/local/bin/elixir
  sudo ln -s /opt/elixir/bin/mix /usr/local/bin/mix
  sudo ln -s /opt/elixir/bin/iex /usr/local/bin/iex
fi

# Install linux-router
if [ -d /home/orangepi/linux-router ]; then
  echo -e "${GREEN}Installing linux-router...already installed${NC}"
else
  echo -e "${GREEN}Installing linux-router...${NC}"
  cd /home/orangepi
  git clone https://github.com/garywill/linux-router.git
fi

# Install pi_flex
if [ -d /home/orangepi/pi_flex ]; then
  echo -e "${GREEN}Installing pi_flex...already installed${NC}"
else
  echo -e "${GREEN}Installing pi_flex...${NC}"
  cd /home/orangepi
  git clone https://github.com/nullquant/pi_flex.git
fi

# Add SSH host key
if [ -d /home/orangepi/sftp_daemon ]; then
  echo -e "${GREEN}Creating SSH host key...already exists${NC}"
else
  echo -e "${GREEN}Creating SSH host key...${NC}"
  cd /home/orangepi
  mkdir data
  mkdir sftp_daemon
  ssh-keygen -q -N "" -t rsa -f sftp_daemon/ssh_host_rsa_key
fi

# Setup linux-router startup
if [ -f /etc/systemd/system/linux_router.service ]; then
  echo -e "${GREEN}Creating linux_router service...already exists${NC}"
else
  echo -e "${GREEN}Creating linux_router service...${NC}"
  sudo cat > /etc/systemd/system/linux_router.service <<- "EOF"
  [Unit]
  Description=Garywill Linux Router Service
  After=network.target

  [Service]
  ExecStart=/home/orangepi/pi_flex/lnxrouter.sh
  Restart=on-failure
  RestartSec=5s

  [Install]
  WantedBy=multi-user.target
EOF

  sudo systemctl enable linux_router.service
fi

# Setup WiFi and change time by any user
if [ -f /etc/polkit-1/rules.d/10-timedate.rules ]; then
  echo -e "${GREEN}Creating time policy...already exists${NC}"
else
  echo -e "${GREEN}Creating time policy...${NC}"
  sudo cat > /etc/polkit-1/rules.d/10-timedate.rules <<- "EOF"
  polkit.addRule(function(action, subject) {
      if (action.id == "org.freedesktop.timedate1.set-time") {
          return polkit.Result.YES;
      }
  });
EOF
fi

if [ -f /etc/polkit-1/rules.d/90-nmcli.rules ]; then
  echo -e "${GREEN}Creating wi-fi policy...already exists${NC}"
else
  echo -e "${GREEN}Creating wi-fi policy...${NC}"
  sudo cat > /etc/polkit-1/rules.d/90-nmcli.rules <<- "EOF"
  polkit.addRule(function(action, subject) {
      if (action.id.indexOf("org.freedesktop.NetworkManager.") == 0) {
          return polkit.Result.YES;
      }
  });
EOF
fi

# Add private config (CLOUD_HOST, CLOUD_PORT, CLOUD_ID, CLOUD_TOKEN, FTP_USER, FTP_PASSWORD):
if [ -f /home/orangepi/env ]; then
  echo -e "${GREEN}Add private config${NC}"
  cp /home/orangepi/env envs/.overrides.env
else
  echo -e "${GREEN}Can't find private config env file${NC}"
fi

# Compile
echo -e "${GREEN}Compile pi_flex${NC}"
cd /home/orangepi/pi_flex
mix deps.get
mix compile
mix release

git config --local core.hooksPath .githooks/

# Setup app startup
if [ -f /etc/systemd/system/pi_flex.service ]; then
  echo -e "${GREEN}Creating pi_flex service...already exists${NC}"
else
  echo -e "${GREEN}Creating pi_flex service...${NC}"
  sudo cat > /etc/systemd/system/pi_flex.service <<- "EOF"
  [Unit]
  Description=PI server for Flexem Panel

  [Service]
  Type=simple
  User=orangepi
  Group=orangepi
  Restart=on-failure
  Environment=MIX_ENV=dev
  Environment=LANG=en_US.UTF-8

  WorkingDirectory=/home/orangepi/pi_flex

  ExecStart=/home/orangepi/pi_flex/_build/dev/rel/pi_flex/bin/pi_flex start
  ExecStop=/home/orangepi/pi_flex/_build/dev/rel/pi_flex/bin/pi_flex stop

  [Install]
  WantedBy=multi-user.target
EOF

  sudo systemctl enable pi_flex.service
fi

# Remove old project
if [ -f /etc/systemd/system/modbus_server.service ]; then
  sudo systemctl stop modbus_server.service
  sudo systemctl disable modbus_server.service
  sudo rm /etc/systemd/system/modbus_server.service

  if [ -f /etc/systemd/system/git_pull.service ]; then
    sudo systemctl stop git_pull.service
    sudo systemctl disable git_pull.service
    sudo rm /etc/systemd/system/git_pull.service
  fi
fi

# Setup periodic git pull
if [ -f /etc/systemd/system/git_pull.service ]; then
  echo -e "${GREEN}Creating git pull service...already exists${NC}"
else
  echo -e "${GREEN}Creating git pull service...${NC}"
  sudo cat > /etc/systemd/system/git_pull.service <<- "EOF"
  [Unit]
  Description=Periodic git pull

  [Service]
  User=orangepi
  Group=orangepi
  Type=oneshot

  WorkingDirectory=/home/orangepi/pi_flex

  ExecStart=/usr/bin/git -C /home/orangepi/pi_flex pull
EOF
fi

if [ -f /etc/systemd/system/git_pull.timer ]; then
  echo -e "${GREEN}Creating git pull timer...already exists${NC}"
else
  sudo cat > /etc/systemd/system/git_pull.timer <<- "EOF"
  [Unit]
  Description=Runs Periodic git pull

  [Timer]
  OnCalendar=*:0/10
  Persistent=true
  AccuracySec=1min

  [Install]
  WantedBy=timers.target
EOF

  if grep -qv "pi_flex.service" "/etc/sudoers"; then
    sudo echo "orangepi ALL=(ALL) NOPASSWD: /usr/bin/systemctl restart pi_flex.service" >> /etc/sudoers
  fi

  sudo systemctl daemon-reload
  sudo systemctl enable git_pull.timer
  sudo systemctl start git_pull.timer
fi

echo -e "${GREEN}All done${NC}"
