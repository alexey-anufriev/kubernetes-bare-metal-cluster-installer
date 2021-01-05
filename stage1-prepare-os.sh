#!/bin/bash

source $(dirname $0)/common-utils.sh

# Check if current OS is supported
check_os

# Checking if user is root
check_root_user

# Install updates
INSTALL_UPDATES=$3

if [[ "$INSTALL_UPDATES" == "true" ]]; then
    apt-get -y update
    apt-get -y upgrade
    apt-get -y autoremove
fi

# Install required software
apt-get -y install docker.io
sudo systemctl enable docker
sudo systemctl start docker
sudo systemctl status docker
docker ––version

apt-get -y install curl

# Set hostname
hostnamectl set-hostname $4
