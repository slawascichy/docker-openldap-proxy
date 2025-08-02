#!/bin/bash
set -o pipefail
echo "**************************"
echo "* Starting OpenLDAP Server "
echo "**************************"

export SLAPD_URLS="ldap:/// ldapi:/// ldaps:///"
export SLAPD_OPTIONS="/etc/ldap/slapd.d"
export LDAP_INIT_FILE=/etc/ldap/slapd.conf
export LDAP_CREATE_MDB_FILE=/etc/ldap/mdbdatabase-create.ldif
export LDAP_CREATE_META_FILE=/etc/ldap/metadatabase-create.ldif
export WORKSPACE=/opt/modify
export LDAP_INIT_FLAG_FILE=/var/lib/ldap/ldap.init
ulimit -n 8192


initDatabase() {
    export LDAP_ROOT_PASSWD_ENCRYPTED=`slappasswd -h {SSHA} -s $LDAP_ROOT_PASSWD_PLAINTEXT`
    echo "Init slapd.conf..."
    rm -rf /var/lib/ldap/*
	rm -rf $SLAPD_OPTIONS/*
    cat /opt/init/01-slapd.conf | envsubst > $LDAP_INIT_FILE

    echo "Starting LDAP..."
    slaptest -f $LDAP_INIT_FILE -F $SLAPD_OPTIONS    
    chown -R openldap:openldap /var/lib/ldap
    chown -R openldap:openldap /etc/ldap/slapd.d
    /usr/sbin/slapd -u openldap -g openldap -h "$SLAPD_URLS" -F $SLAPD_OPTIONS
      
    echo "Applay init scripts START"
    cat /opt/init/02-mdbdatabase-create.ldif | envsubst > $LDAP_CREATE_MDB_FILE
    ldapadd -Y EXTERNAL -H ldapi:/// -f  $LDAP_CREATE_MDB_FILE
    cat /opt/init/03-metadatabase-create.ldif | envsubst > $LDAP_CREATE_META_FILE
    ldapadd -Y EXTERNAL -H ldapi:/// -f  $LDAP_CREATE_META_FILE
    
    cd $WORKSPACE
    export LDAP_TECHNICAL_USER_ENCRYPTED=`slappasswd -h {SSHA} -s $LDAP_TECHNICAL_USER_PASSWD`
    
    echo "Run base.ldif..."
    LDIF_FILE=$WORKSPACE/base.ldif
    cat $WORKSPACE/base.ldif.docker-init | envsubst > $LDIF_FILE
    ldapadd -Y EXTERNAL -H ldapi:/// -f $LDIF_FILE
    
    echo "Run sample-entries.ldif..."
    LDIF_FILE=$WORKSPACE/sample-entries.ldif
    cat $WORKSPACE/sample-entries.ldif.docker-init | envsubst > $LDIF_FILE
    ldapadd -Y EXTERNAL -H ldapi:/// -f $LDIF_FILE
    
    touch $LDAP_INIT_FLAG_FILE
    SLAPD_PID=`cat /var/run/slapd/slapd.pid`
    kill $SLAPD_PID
    echo "Applay init scripts END"

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

# Debugging Levels
# +=======+=================+===========================================================+
# | Level |    Keyword      | Description                                               |
# +=======+=================+===========================================================+
# | -1    | any             | enable all debugging                                      |
# | 0     |                 | no debugging                                              |
# | 1     | (0x1 trace)     | trace function calls                                      |
# | 2     | (0x2 packets)   | debug packet handling                                     |
# | 4     | (0x4 args)      | heavy trace debugging                                     |
# | 8     | (0x8 conns)     | connection management                                     |
# | 16    | (0x10 BER)      | print out packets sent and received                       |
# | 32    | (0x20 filter)   | search filter processing                                  |
# | 64    | (0x40 config)   | configuration processing                                  |
# | 128   | (0x80 ACL)      | access control list processing                            |
# | 256   | (0x100 stats)   | stats log connections/operations/result                   |
# | 512   | (0x200 stats2)  | stats log entries sent                                    |
# | 1024  | (0x400 shell)   | print communication with shell backends                   |
# | 2048  | (0x800 parse)   | print entry parsing debugging                             |
# | 16384 | (0x4000 sync)   | syncrepl consumer processing                              |
# | 32768 | (0x8000 none)   | only messages that get logged whatever log level is set   |
# +=======+=================+===========================================================+

export LOG_FILE=/var/log/slapd.log
touch $LOG_FILE
echo "Starting LDAP deamon..."
/usr/sbin/slapd -u openldap -g openldap -d $SERVER_DEBUG -h "$SLAPD_URLS" -F $SLAPD_OPTIONS >> $LOG_FILE 2>&1 &
tail -f $LOG_FILE
