#!/bin/bash
set -o pipefail

export WORKSPACE=/opt/modify
export LOG_FILE=/var/log/slapd.log
export SLAPD_URLS="ldap:/// ldapi:/// ldaps:///"
export SLAPD_OPTIONS="/etc/ldap/slapd.d"
export LDAP_INIT_FILE=/etc/ldap/slapd.conf
export LDAP_DB_DIR=/var/lib/ldap
export CREATION_LOG_FILE=${LDAP_DB_DIR}/create_db.log
export LDAP_CREATE_MDB_FILE=${LDAP_DB_DIR}/mdbdatabase-create.ldif
export LDAP_CREATE_META_FILE=${LDAP_DB_DIR}/metadatabase-create.ldif
export LDAP_INIT_FLAG_FILE=${LDAP_DB_DIR}/ldap.init
ulimit -n 8192
touch $LOG_FILE

initDatabase() {
    export LDAP_ROOT_PASSWD_ENCRYPTED=`slappasswd -h {SSHA} -s $LDAP_ROOT_PASSWD_PLAINTEXT`
    echo "Init slapd.conf..."
    rm -rf ${LDAP_DB_DIR}/*
	rm -rf $SLAPD_OPTIONS/*
    cat /opt/init/01-slapd.conf | envsubst > $LDAP_INIT_FILE

    echo "Starting LDAP..."
    slaptest -f $LDAP_INIT_FILE -F $SLAPD_OPTIONS
    mkdir -p ${LDAP_DB_DIR}/local
    mkdir -p ${LDAP_DB_DIR}/subordinate
    chown -R openldap:openldap ${LDAP_DB_DIR}
    chown -R openldap:openldap ${SLAPD_OPTIONS}
    /usr/sbin/slapd -u openldap -g openldap -h "$SLAPD_URLS" -F $SLAPD_OPTIONS 
      
    START_MSG="## Applay init scripts START ###################################################"
    echo ${START_MSG}
    echo ${START_MSG} > ${CREATION_LOG_FILE}
    cat /opt/init/02-mdbdatabase-create.ldif | envsubst > $LDAP_CREATE_MDB_FILE
    ldapadd -Y EXTERNAL -H ldapi:/// -f  $LDAP_CREATE_MDB_FILE >> ${CREATION_LOG_FILE}
    cat /opt/init/03-metadatabase-create.ldif | envsubst > $LDAP_CREATE_META_FILE
    ldapadd -Y EXTERNAL -H ldapi:/// -f  $LDAP_CREATE_META_FILE >> ${CREATION_LOG_FILE}
    
    cd $WORKSPACE
    export LDAP_TECHNICAL_USER_ENCRYPTED=`slappasswd -h {SSHA} -s $LDAP_TECHNICAL_USER_PASSWD`
    
    START_MSG="-->Run base.ldif..."
    echo ${START_MSG}
    echo ${START_MSG} >> ${CREATION_LOG_FILE}
    LDIF_FILE=$LDAP_DB_DIR/base.ldif
    cat $WORKSPACE/base.ldif.docker-init | envsubst > $LDIF_FILE
    ldapadd -Y EXTERNAL -H ldapi:/// -f $LDIF_FILE >> ${CREATION_LOG_FILE}
    
    echo 
    START_MSG="-->Run sample-entries.ldif..."
    echo ${START_MSG}
    echo ${START_MSG} >> ${CREATION_LOG_FILE}
    LDIF_FILE=$LDAP_DB_DIR/sample-entries.ldif
    cat $WORKSPACE/sample-entries.ldif.docker-init | envsubst > $LDIF_FILE
    ldapadd -Y EXTERNAL -H ldapi:/// -f $LDIF_FILE >> ${CREATION_LOG_FILE}
    
    touch $LDAP_INIT_FLAG_FILE
    SLAPD_PID=`cat /var/run/slapd/slapd.pid`
    kill $SLAPD_PID
    START_MSG="## Applay init scripts END #####################################################"
    echo ${START_MSG}
    echo ${START_MSG} >> ${CREATION_LOG_FILE}

}

setTLS(){
	cat <<EOF > /etc/ldap/ldap.conf
#
# LDAP Defaults
#
#BASE   ${LDAP_LOCAL_OLC_SUFFIX}
#URI    ldap://localhost
#SIZELIMIT      12
#TIMELIMIT      15
#DEREF          never

# TLS certificates (needed for GnuTLS)
TLS_CACERT     /usr/local/share/ca-certificate/${LDAP_TLS_CACERT}
TLS_CACERTDIR  /usr/local/share/ca-certificate
TLS_REQCERT    never
EOF
}

start() 
{
	echo "**************************"
	echo "* Starting OpenLDAP Server "
	echo "**************************"

	# Before starting - START
	DIR=/var/lib/ldap
	if [ "$(ls -A $LDAP_INIT_FLAG_FILE)" ]; then
	    echo "Database is ready."
	else
	    echo "Init database..."
	    initDatabase
	fi
	# Setting TLS for communication for LDAP clients
	setTLS
	# Before starting - END

	echo "Starting LDAP deamon..."
	/usr/sbin/slapd -u openldap -g openldap -d $SERVER_DEBUG -h "$SLAPD_URLS" -F $SLAPD_OPTIONS >> $LOG_FILE 2>&1 &
	echo "Done"
}

stop()
{
	echo "**************************"
	echo "* Stopping OpenLDAP Server "
	echo "**************************"
	SLAPD_PID=`cat /var/run/slapd/slapd.pid`
	kill -INT ${SLAPD_PID}
	echo "Done"
}

case "$1" in
    start)
        start
        ;;
    stop)
        stop
        ;;
    restart)
        stop
        start
        ;;
    *)
        echo "Usage: $0 {start|stop|restart}"
esac

exit 0