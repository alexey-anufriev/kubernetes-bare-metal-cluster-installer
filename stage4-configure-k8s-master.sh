#!/bin/bash

source $(dirname $0)/common-utils.sh

MODE=$3
NODE_NAME=$4
LABEL=$5

if [[ "$MODE" == "master" ]]; then
    # Configure k8s on master
    kubeadm init --pod-network-cidr=10.244.0.0/16

    mkdir -p $HOME/.kube
    cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
    chown $(id -u):$(id -g) $HOME/.kube/config

    # Configure network
    kubectl apply -f https://raw.githubusercontent.com/coreos/flannel/master/Documentation/kube-flannel.yml

    # Verify setup
    kubectl get all --all-namespaces

    # Notify workers to join
    info_log "Now worker nodes can be setup. Start parallel installers for every worker node."
    info_log "To attach worker nodes to the cluster JOIN command (find it above) must be executed."
    info_log "Press any [enter] after all the worker nodes are installed."
    read

    if [[ -n "$LABEL" ]]; then
        kubectl label nodes $NODE_NAME $LABEL
        info_log "$LABEL label attached to the node"
    fi
else
    info_log "Skipping master step for worker mode setup"
fi