#!/bin/bash

source $(dirname $0)/common-utils.sh

MODE=$3
NODE_NAME=$4
LABEL=$5
OBSERVABILITY_STACK=$6
OBSERVABILITY_STACK_NODE_SELECTOR=$7

if [[ "$MODE" == "master" ]]; then
    # Configure k8s on master
    kubeadm init --pod-network-cidr=10.244.0.0/16
    info_log "master node initialized"

    # Allow root to control the cluster
    mkdir -p $HOME/.kube
    cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
    chown $(id -u):$(id -g) $HOME/.kube/config

    # Configure network
    kubectl apply -f https://raw.githubusercontent.com/coreos/flannel/master/Documentation/kube-flannel.yml
    info_log "network set"

    # Verify setup
    info_log "checking cluster state"
    kubectl get all --all-namespaces

    # Notify workers to join
    info_log "Now worker nodes can be setup. Start parallel installers for every worker node."
    info_log "To attach worker nodes to the cluster JOIN command must be executed (find above, it starts with: kubeadm join ...)."
    info_log "Just copy the command and paste it as-is during the worker installations when requested."
    info_log "Press [enter] after all the worker nodes are installed and joined the master node."
    read

    # Install ingress
    info_log "Installing ingress-nginx"
    kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/master/deploy/static/provider/baremetal/deploy.yaml
    wait_for_pod "ingress-nginx" "app.kubernetes.io/component=controller" "ingress-controller" 50

    if [[ -n "$LABEL" ]]; then
        kubectl label nodes $NODE_NAME $LABEL
        info_log "$LABEL label attached to the node"
    fi

    if [[ "$OBSERVABILITY_STACK" == "true" ]]; then
        kubectl create namespace monitoring

        noglob helm install monitoring \
            --set namespaceOverride=monitoring \
            --set operator.nodeSelector.$OBSERVABILITY_STACK_NODE_SELECTOR \
            --set prometheus.nodeSelector.$OBSERVABILITY_STACK_NODE_SELECTOR \
            --set alertmanager.nodeSelector.$OBSERVABILITY_STACK_NODE_SELECTOR \
            --set blackboxExporter.nodeSelector.$OBSERVABILITY_STACK_NODE_SELECTOR \
            --set kube-state-metrics.nodeSelector.$OBSERVABILITY_STACK_NODE_SELECTOR \
            --set node-exporter.tolerations[0].operator=Exists \
            --set node-exporter.tolerations[0].effect=NoSchedule \
            bitnami/kube-prometheus
    fi

    info_log "Cluster status"
    kubectl get all --all-namespaces
else
    info_log "Skipping master step for worker mode setup"
fi