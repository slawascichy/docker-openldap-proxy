#!/bin/bash
set -o pipefail
echo "**************************"
echo "* Starting OpenLDAP Server for tests"
echo "**************************"

export LOG_FILE=/var/log/slapd-test.log
touch $LOG_FILE
tail -f $LOG_FILE
