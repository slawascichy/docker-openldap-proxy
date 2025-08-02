#!/bin/bash
set -o pipefail
echo "**************************"
echo "* Deleting entry $1"
echo "**************************"

export DN_OF_ENTRY_FOR_DELETE=$1
LDIF_FILE=/tmp/delete-entry.ldif
cat  /opt/init/05-delete-entry.ldif | envsubst > $LDIF_FILE
ldapmodify -Y EXTERNAL -H ldapi:/// -f $LDIF_FILE
exit 0