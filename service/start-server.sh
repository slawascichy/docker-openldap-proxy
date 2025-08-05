#!/bin/bash
set -o pipefail
echo "**************************"
echo "* Starting Docker Contener... "
echo "**************************"

SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
# echo "Script dir: ${SCRIPT_DIR}"
# Change dir to main project dir, where docker configuration files are located
cd "${SCRIPT_DIR}"

./slapd-service.sh start
export LOG_FILE=/var/log/slapd.log
tail -f $LOG_FILE
