#!/bin/bash
set -o pipefail
echo "**************************"
echo "* Adding mapping of attribute names from external AD to local OpenLDAP..."
echo "**************************"
# $1 - the name of the organizational unit under which the connected LDAP tree should appear

export META_SUB=`ldapsearch -Y EXTERNAL -H ldapi:/// -b "olcDatabase={3}meta,cn=config" -s sub "(olcMetaSub=${1})" olcMetaSub | grep "olcMetaSub:" | awk '{print $2}'`
LDIF_FILE=/tmp/add-all-dbmap-for-ad-proxy.ldif
cat  /opt/init/06-add-all-dbmap-for-ad-proxy.ldif | envsubst > $LDIF_FILE
ldapmodify -Y EXTERNAL -H ldapi:/// -f $LDIF_FILE
exit 0