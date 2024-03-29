# k8s bare metal cluster installer

## DISCLAIMER

NOT INTENDED FOR PRODUCTION USE. For pet projects or testing only.

## Description

`k8s bare metal cluster installer` is intended to help with the installation of the sandbox kubernetes cluster on bare metal infrastructure.

## Requirements

- Ubuntu 16.04+ (local and remote)
- `sudo` access on remote machines

## Usage

Installer must be executed locally along with the extra details of the remote host being provided.

_Note: installer must be executed as root._

```
sudo ./k8s-cluster-setup.sh \
    -n <node-name> \
    -h <node-host> \
    -m <node-mode:master/worker> \
    -l <node-label> \
    -u <remote-user> \
    -p <remote-user-password> \
    -i <install-updates:true/false> \
    -o <observability-stack:true/false> \
    -s <observability-stack-node-selector> \
    -c <cleanup:true/false>
```

- `node-name` (mandatory) desired name of the node. Will be used to set a hostname of the remote machine, as well as hostname of the local SSH configuration (for maintenance access).
- `node-host` (mandatory) remote server host where the node must be installed.
- `node-mode:master/worker` (mandatory) k8s node role (either master or worker).
- `node-label` (optional) additional node label.
- `remote-user` (mandatory) user name for remote access with sudo permissions.
- `remote-user-password` (mandatory) user password for remote access with sudo permissions.
- `install-updates:true/false` (optional, default: false) whether to install updates or not.
- `observability-stack:true/false` (optional, default: false) whether to install prometeus, node-exporter and kube-state-metrics.
- `observability-stack-node-selector` (mandatory if `observability-stack=true`) target node selector for observability stack.
- `cleanup:true/false` (optional, default: false) whether to perform post-install cleanup or not (remove installer files).

Every installer execution creates a working directory named after `.installations/<node-name>-<node-host>` where logs and stages progress is saved. Every log file is named after the timestamp of the installation start.

## Stages

Installation process is divided into stages. It is done to separate unrelated steps as well as to make them retryable. Every stage creates completion marker in the working directory.

### Stage 1 - prepare OS

This stage validates OS requirements, installs missing software and updates, and sets the hostname of the machine.

### Stage 2 - install k8s

This stage installs kubernetes and related software.

### Stage 3 - setup k8s maintenance user

This stage creates a separate maintenance user on the remote machine. User name is `k8s`. Additionally a pair of public/private keys is generated and configured for remote access (keys are located in `~/.ssh/<node-name>`).

### Stage 4 - configure k8s master

This stage initializes kubernetes master node. Important step here is to save `join` command that needs to be executed during workers installation. Additionally observability stack may be installed if required. At the end, `kube.config` will be copied to the installation folder.

### Stage 5 - configure k8s worker

This stage joins kubernetes worker node to the kubernetes master node. It is more manual step and requires `join` command that was generated on the previous stage for mater node.

### Stage 6 - demo app

This stage installs a demo app to the newly created cluster.

### Stage 7 - disable root access

This stage grants kubernetes cluster maintenance access to `k8s` user. Also, for security reasons, this stage disables ssh login for root.

## Notes

After installation is complete the node can be accessed via ssh using `k8s` user: `ssh <node-name>`

## License

[MIT](https://opensource.org/licenses/MIT)
