#!/bin/bash

source $(dirname $0)/common-utils.sh

MODE=$3

if [[ "$MODE" == "worker" ]]; then
    # Configure k8s on worker
    info_log "Paste and execute JOIN command to attach this worker to mater"

    read JOIN_CMD

    info_log "Joining master node..."
    eval "$JOIN_CMD"
else
    info_log "Skipping worker step for master mode setup"
fi
