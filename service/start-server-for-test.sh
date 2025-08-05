#!/bin/bash
set -o pipefail
echo "**************************"
echo "* Starting Docker Contener for tests... "
echo "**************************"

export LOG_FILE=/var/log/slapd.log
touch $LOG_FILE
tail -f $LOG_FILE
