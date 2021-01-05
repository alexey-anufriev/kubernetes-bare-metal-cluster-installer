#!/bin/bash

source $(dirname $0)/common-utils.sh

# Add k8s sudo user
adduser --disabled-password --gecos "" k8s
usermod -aG sudo k8s

echo $'\n' >> /etc/sudoers
echo "# k8s user" >> /etc/sudoers
echo "k8s ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers
echo $'\n' >> /etc/sudoers

# Setup SSH key
USER_HOME=$(getent passwd k8s | cut -d: -f6)
umask 077 && mkdir $USER_HOME/.ssh
chown k8s:k8s $USER_HOME/.ssh/

umask 077 && touch $USER_HOME/.ssh/authorized_keys
chown k8s:k8s $USER_HOME/.ssh/authorized_keys

cat /k8s-cluster-setup/id_rsa.pub > $USER_HOME/.ssh/authorized_keys
