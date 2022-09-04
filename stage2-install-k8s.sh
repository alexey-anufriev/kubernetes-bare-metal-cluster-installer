#!/bin/bash

source $(dirname $0)/common-utils.sh

# Install k8s
curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | sudo apt-key add
sudo apt-add-repository "deb http://apt.kubernetes.io/ kubernetes-xenial main"

apt-get -y install kubeadm kubelet kubectl
apt-mark hold kubeadm kubelet kubectl
kubeadm version

snap install helm --classic
helm version

# Disable swap
swapoff -a
sed -i '/ swap / s/^/#/' /etc/fstab
