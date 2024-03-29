# Print banner
banner() {
    message "                                                             "
    message "  _   ___        _                            _       _      "
    message " | |_| . |___   | |_ ___ ___ ___    _____ ___| |_ ___| |     "
    message " | '_| . |_ -|  | . | .'|  _| -_|  |     | -_|  _| .'| |     "
    message " |_,_|___|___|  |___|__,|_| |___|  |_|_|_|___|_| |__,|_|     "
    message "      _         _              _         _       _ _         "
    message "  ___| |_ _ ___| |_ ___ ___   |_|___ ___| |_ ___| | |___ ___ "
    message " |  _| | | |_ -|  _| -_|  _|  | |   |_ -|  _| .'| | | -_|  _|"
    message " |___|_|___|___|_| |___|_|    |_|_|_|___|_| |__,|_|_|___|_|  "
    message "                                                             "
}

# Print usage
usage() {
    echo "usage:"
    echo "./k8s-cluster-setup \\"
    echo "    -n <node-name> \\"
    echo "    -h <node-host> \\"
    echo "    -m <node-mode:master/worker> \\"
    echo "    -l <node-label> \\"
    echo "    -u <remote-user> \\"
    echo "    -p <remote-user-password> \\"
    echo "    -i <install-updates:true/false> \\"
    echo "    -o <observability-stack:true/false> \\"
    echo "    -s <observability-stack-node-selector> \\"
    echo "    -c <cleanup:true/false>"
}

check_requirements() {
    info_log "Checking installer requirements..."

    check_os
    check_required_software sshpass
    check_required_software ssh

    if [[ "$NODE_MODE" == "worker" ]]; then
        warn_log "Master node must be installed first!"
        info_log "Please confirm that master node has been already installed: [y/n]"
        read MASTER_INSTALLED

        if [[ "$MASTER_INSTALLED" != "y" ]]; then
            error_log "Install master node first!"
            exit 1
        fi
    fi

    info_log "Requirements are met"
}

parse_args() {
    # Parse and validate arguments
    while getopts ":n:h:u:p:m:i:c:l:o:s:" options; do
        case "${options}" in
            n)
                NODE_NAME=${OPTARG}
            ;;
            h)
                REMOTE_HOST=${OPTARG}
            ;;
            u)
                REMOTE_USER=${OPTARG}
            ;;
            p)
                REMOTE_PASSWORD=${OPTARG}
            ;;
            m)
                NODE_MODE=${OPTARG}
            ;;
            i)
                INSTALL_UPDATES=${OPTARG}
            ;;
            c)
                CLEANUP=${OPTARG}
            ;;
            l)
                NODE_LABEL=${OPTARG}
            ;;
            o)
                OBSERVABILITY_STACK=${OPTARG}
            ;;
            s)
                OBSERVABILITY_STACK_NODE_SELECTOR=${OPTARG}
            ;;
        esac
    done

    if [[ -z "$NODE_NAME" || -z "$REMOTE_HOST" || -z "$REMOTE_USER" || -z "$REMOTE_PASSWORD" ]]; then
        error_log "Desired node-name and target node environment along with credentials must be specified"
        usage
        exit 1
    fi

    if [[ $NODE_MODE != "master" ]] && [[ $NODE_MODE != "worker" ]]; then
        error_log "Node mode must be specified correctly"
        usage
        exit 1
    fi

    if [[ $OBSERVABILITY_STACK == "true" ]] && [[ -z $OBSERVABILITY_STACK_NODE_SELECTOR ]]; then
        error_log "When observability stack is required then target node selector must be specified, format is '\"label\"=value'"
        usage
        exit 1
    fi

    CURRENT_USER=$(whoami)
    USER_HOME=$(getent passwd $CURRENT_USER | cut -d: -f6)
}

upload_installer() {
    info_log "Uploading installer..."

    sshpass -p $REMOTE_PASSWORD \
        ssh -o "StrictHostKeyChecking no" $REMOTE_USER@$REMOTE_HOST "mkdir -p /k8s-cluster-setup"

    sshpass -p $REMOTE_PASSWORD \
        scp -v -o "StrictHostKeyChecking no" \
        common-utils.sh stage1-prepare-os.sh stage2-install-k8s.sh stage3-create-maintenance-user.sh \
        stage4-configure-k8s-master.sh stage5-configure-k8s-worker.sh stage6-deploy-demo-app.sh stage7-disable-root-access.sh \
        demo-app-ingress-rule.yaml demo-app-nginx-deployment.yaml \
        $REMOTE_USER@$REMOTE_HOST:/k8s-cluster-setup

    info_log "Installer uploaded"
}

exec_stage_as_root() {
    echo ""
    message "========================================"
    info_log "Executing stage '$1'..."

    sshpass -p $REMOTE_PASSWORD \
        ssh -o "StrictHostKeyChecking no" $REMOTE_USER@$REMOTE_HOST \
        "chmod +x /k8s-cluster-setup/$2 && /k8s-cluster-setup/$2 $@"

    RESULT=$?
    if [[ $RESULT -eq 0 ]]; then
        info_log "'$1' executed"
    else
        error_log "'$1' failed"
        exit 1
    fi
}

exec_stage1_prepare_os() {
    if [[ -f $WORKDIR/stage1-completed ]]; then
        info_log "Skipping stage 1 as it was completed"
        return
    fi

    exec_stage_as_root "os-setup" "stage1-prepare-os.sh" $INSTALL_UPDATES $NODE_NAME

    touch $WORKDIR/stage1-completed
}

exec_stage2_install_k8s() {
    if [[ -f $WORKDIR/stage2-completed ]]; then
        info_log "Skipping stage 2 as it was completed"
        return
    fi

    exec_stage_as_root "k8s-installation" "stage2-install-k8s.sh"

    touch $WORKDIR/stage2-completed
}

generate_and_upload_ssh_key() {
    info_log "Generating ssh keys for maintenance user..."

    mkdir -p $USER_HOME/.ssh/$NODE_NAME
    ssh-keygen -t rsa -b 4096 -C "$NODE_NAME" -N "" -f $USER_HOME/.ssh/$NODE_NAME/id_rsa -q

    info_log "Keys generated"
    info_log "Uploading keys..."

    sshpass -p $REMOTE_PASSWORD \
        scp -o "StrictHostKeyChecking no" $USER_HOME/.ssh/$NODE_NAME/id_rsa.pub $REMOTE_USER@$REMOTE_HOST:/k8s-cluster-setup

    info_log "Keys uploaded"
}

verify_access() {
    info_log "Verifying maintenance user access..."

    ssh -o "StrictHostKeyChecking no" -i $USER_HOME/.ssh/$NODE_NAME/id_rsa k8s@$REMOTE_HOST "who"

    RESULT=$?
    if [[ $RESULT -eq 0 ]]; then 
        info_log "Login for k8s is allowed"
    else
        error_log "Login for k8s is still not allowed"
        exit 1
    fi
}

exec_stage3_prepare_user() {
    if [[ -f $WORKDIR/stage3-completed ]]; then
        info_log "Skipping stage 3 as it was completed"
        return
    fi

    generate_and_upload_ssh_key
    exec_stage_as_root "maintenance-user-setup" "stage3-create-maintenance-user.sh"
    verify_access

    touch $WORKDIR/stage3-completed
}

exec_stage4_configure_master() {
    if [[ -f $WORKDIR/stage4-completed ]]; then
        info_log "Skipping stage 4 as it was completed"
        return
    fi

    exec_stage_as_root "master-configuration" "stage4-configure-k8s-master.sh" $NODE_MODE $NODE_NAME $NODE_LABEL $OBSERVABILITY_STACK $OBSERVABILITY_STACK_NODE_SELECTOR

    if [[ "$NODE_MODE" == "master" ]]; then
        sshpass -p $REMOTE_PASSWORD \
            scp -o "StrictHostKeyChecking no" $REMOTE_USER@$REMOTE_HOST:/etc/kubernetes/admin.conf $WORKDIR/kube.config
    fi

    touch $WORKDIR/stage4-completed
}

exec_stage5_configure_worker() {
    if [[ -f $WORKDIR/stage5-completed ]]; then
        info_log "Skipping stage 5 as it was completed"
        return
    fi

    exec_stage_as_root "worker-configuration" "stage5-configure-k8s-worker.sh" $NODE_MODE $NODE_NAME $NODE_LABEL

    touch $WORKDIR/stage5-completed
}

exec_stage6_deploy_demo_app() {
    if [[ -f $WORKDIR/stage6-completed ]]; then
        info_log "Skipping stage 6 as it was completed"
        return
    fi

    exec_stage_as_root "deploy-demo-app" "stage6-deploy-demo-app.sh" $NODE_MODE

    touch $WORKDIR/stage6-completed
}

exec_stage7_disable_root() {
    if [[ -f $WORKDIR/stage7-completed ]]; then
        info_log "Skipping stage 7 as it was completed"
        return
    fi

    exec_stage_as_root "disable-root-access" "stage7-disable-root-access.sh" $NODE_MODE $CLEANUP

    touch $WORKDIR/stage7-completed
}

add_local_ssh_config() {
    info_log "Creating local ssh config for $NODE_NAME..."

    if [[ ! -f $USER_HOME/.ssh/config ]]; then
        touch $USER_HOME/.ssh/config
        chmod 600 $USER_HOME/.ssh/config
    fi

    if [[ -z "$(grep '^Host '$NODE_NAME $USER_HOME/.ssh/config)" ]]; then
        echo "" >> $USER_HOME/.ssh/config
        echo "Host $NODE_NAME" >> $USER_HOME/.ssh/config
        echo "    HostName $REMOTE_HOST" >> $USER_HOME/.ssh/config
        echo "    User k8s" >> $USER_HOME/.ssh/config
        echo "    IdentityFile $USER_HOME/.ssh/$NODE_NAME/id_rsa" >> $USER_HOME/.ssh/config

        info_log "Use 'ssh $NODE_NAME' to connect to $NODE_NAME node"
    else
        warn_log "Unable to create ssh config for $NODE_NAME"
        warn_log "$USER_HOME/.ssh/config has already record for host $NODE_NAME"
    fi
}

prepare_installer_workdir() {
    WORKDIR=".installations/"$NODE_NAME'-'$REMOTE_HOST
    LOG_FILE=$WORKDIR/$(date +'%d-%m-%Y_%H-%M-%S').log

    if [[ -f $LOG_FILE ]]; then
        error_log "Log file already exist $LOG_FILE"
        exit 1
    fi

    if [[ ! -d $WORKDIR ]]; then
        mkdir -p $WORKDIR
    fi

    touch $LOG_FILE
}

installation() {
    info_log "Installing node '$NODE_NAME' ($NODE_MODE) on '$REMOTE_HOST'"

    check_requirements
    upload_installer

    exec_stage1_prepare_os
    exec_stage2_install_k8s
    exec_stage3_prepare_user
    exec_stage4_configure_master
    exec_stage5_configure_worker
    exec_stage6_deploy_demo_app
    exec_stage7_disable_root

    add_local_ssh_config

    END_TIME=$(date +%s)

    info_log "'$NODE_NAME' node installation complete"
    info_log "Installation took $((END_TIME-START_TIME)) seconds"
}
