RED='\033[0;31m'
YELLOW='\033[0;33m'
GREEN='\033[0;32m'
CYAN="\033[0;36m"
NC='\033[0m'

error_log() {
    printf "${RED}[error - $(date '+%d/%m/%Y %H:%M:%S')] $1${NC}\n"
}

warn_log() {
    printf "${YELLOW}[warn - $(date '+%d/%m/%Y %H:%M:%S')] $1${NC}\n"
}

info_log() {
    printf "${GREEN}[info - $(date '+%d/%m/%Y %H:%M:%S')] $1${NC}\n"
}

message() {
    printf "${CYAN}$1${NC}\n"
}

check_os() {
   info_log "Checking OS..."

   OS=$(grep -E -i -s 'buntu' /etc/lsb-release)

   if [[ -z "$OS" ]]; then
      error_log "Only Ubuntu-based systems are supported"
      exit 1
   fi

   info_log "Supported OS found:"
   echo "$OS"
}

# Check if user is root
check_root_user() {
    info_log "Checking user..."

    USER_ID=$(id -u)

    if [[ $USER_ID -ne 0 ]]; then 
        error_log "Installer must be executed as root"
        exit 1
    fi

    info_log "User is root"
}

wait_for_pod() {
    I=1;
    sleep 3

    while [ $I -le $4 ]
    do
        INGRESS_STATUS=$(kubectl get pods -n $1 -l $2 -o jsonpath='{.items[0].status.phase}')
        if [[ "$INGRESS_STATUS" == "Running" ]]; then
            info_log "$3 is now running"
            break
        fi

        warn_log "[attempt $I of $4] $3 is not running, waiting 3 more seconds..."
        sleep 3

        I=$((I+1)) 
    done
}
