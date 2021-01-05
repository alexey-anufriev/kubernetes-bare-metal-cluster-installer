#!/bin/bash

START_TIME=$(date +%s)

source $(dirname $0)/common-utils.sh
source $(dirname $0)/main-utils.sh

banner

parse_args "$@"
prepare_installer_workdir
installation |& tee $LOG_FILE
