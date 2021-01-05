#!/bin/bash

source $(dirname $0)/common-utils.sh

MODE=$3

if [[ "$MODE" == "master" ]]; then
    info_log "At this moment Demo app (simple nginx server with welcome page) can be deployed."
    warn_log "The only requirement is that all workers must be already attached to the cluster."
    echo ""
    info_log "Note: at this moment workers can be installed in parallel with the current installer."
    info_log "If you do not want to deploy Demo app or do not want to workers in parallel then just skip the step."
    echo ""
    info_log "Install Demo app? [y/n]"

    read DEMO_APP

    if [[ "$DEMO_APP" == "y" ]]; then
        info_log "Installing ingress-nginx"
        kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/master/deploy/static/provider/baremetal/deploy.yaml
        wait_for_pod "ingress-nginx" "app.kubernetes.io/component=controller" "ingress-controller" 50

        info_log "Installing Demo app"
        kubectl apply -f /k8s-cluster-setup/demo-app-nginx-deployment.yaml
        wait_for_pod "default" "app=demo-nginx" "demo-app" 20

        kubectl expose deployment/demo-app-nginx

        kubectl apply -f /k8s-cluster-setup/demo-app-ingress-rule.yaml

        info_log "Cluster status"
        kubectl get all --all-namespaces

        CLUSTER_IP_ADDR=$(hostname  -I | cut -f1 -d ' ')
        CLUSTER_HTTP_PORT=$(kubectl get service ingress-nginx-controller -n ingress-nginx -o=jsonpath='{.spec.ports[?(@.name=="http")].nodePort}')
        DEMO_APP_URL="http://$CLUSTER_IP_ADDR:$CLUSTER_HTTP_PORT/demo-app"
        info_log "Demo app must be available using this URL: $DEMO_APP_URL"
    else
        info_log "Demo app is not required"
    fi
else
    info_log "Demo app skipped"
fi
