#!/bin/bash

source $(dirname $0)/common-utils.sh

MODE=$3

if [[ "$MODE" == "master" ]]; then
    info_log "Granting access to k8s cluster for k8s user..."
    USER_HOME=$(getent passwd k8s | cut -d: -f6)
    
    mkdir -p $USER_HOME/.kube
    chown k8s:k8s $USER_HOME/.kube

    # Give k8s user permissions to maintain master node
    cp -i /etc/kubernetes/admin.conf $USER_HOME/.kube/config
    chown k8s:k8s $USER_HOME/.kube/config

    info_log "kubernetes config copied to $USER_HOME/.kube/config"
fi

CLEANUP=$4

# Remove installer files
if [[ "$CLEANUP" == "true" ]]; then
    info_log "Remove installer files"
    rm -rf /k8s-cluster-setup
fi

# Disable root login
if [[ ! -z "$(grep '^PermitRootLogin' /etc/ssh/sshd_config)" ]]; then 
    sed -i "s/^PermitRootLogin.*/PermitRootLogin no/g" /etc/ssh/sshd_config
else
    echo "PermitRootLogin no" >> /etc/ssh/sshd_config
fi

info_log "root login via ssh disabled"

service sshd restart
