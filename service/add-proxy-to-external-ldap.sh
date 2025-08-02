#!/bin/bash
#set -o pipefail
echo "**************************"
echo "* Adding proxy to external LDAP... "
echo "**************************"

export LDAP_CONF_DIR=/etc/ldap/


printMissingArgumentError() {
      cat <<EOF

Script execution error: Missing $1 argument
Use the '--help' option to display help, e.g., ./add-proxy-to-external-ldap.sh --help
--
EOF
}

validate() {
	if [ -z ${BIND_LDAP_URI} ]; then
	    printMissingArgumentError "BIND_LDAP_URI"
	    exit 1
	fi
	if [ -z ${BIND_DN} ]; then
	    printMissingArgumentError "BIND_DN"
	    exit 1
	fi
	if [ -z ${BIND_PASSWD_PLAINTEXT} ]; then
	    printMissingArgumentError "BIND_PASSWD_PLAINTEXT"
	    exit 1
	fi
	if [ -z ${BIND_BASE_CTX_SEARCH} ]; then
	    printMissingArgumentError "BIND_BASE_CTX_SEARCH"
	    exit 1
	fi
	if [ -z ${LDAP_PROXY_OU_NAME} ]; then
	    printMissingArgumentError "LDAP_PROXY_OU_NAME"
	    exit 1
	fi
	if [ -z ${LDAP_BASED_OLC_SUFFIX} ]; then
	    printMissingArgumentError "LDAP_BASED_OLC_SUFFIX"
	    exit 1
	fi
}

printHelp() 
{
  cat <<EOF
The script requires arguments:
 BIND_LDAP_URI=<value>         - URL pointing to an external LDAP instance, e.g. <ldap|ldaps>://example.com
 BIND_DN=<value>               - user DN through which communication will be carried out
 BIND_PASSWD_PLAINTEXT=<value> - user password through which communication will be carried out
 BIND_BASE_CTX_SEARCH=<value>  - the primary search branch of the LDAP instance being connected
 LDAP_PROXY_OU_NAME=<value>    - the name of the organizational unit under which the connected LDAP tree should appear
EOF
  if [ -z ${LDAP_BASED_OLC_SUFFIX} ]; then
    cat <<EOF
 LDAP_BASED_OLC_SUFFIX=<value> - target meta database suffix, proxy e.g. dc=example,dc=local
EOF
  fi
  cat <<EOF
Optionally, you can use the parameters of one of the options:
 --help                        - presentation of script run help data
 --test                        - testing the correctness of the command
 --addADAttributesMapping      - adds Mapping of attribute names from external AD to local OpenLDAP

--
Example of running a script creating a proxy database:
./add-proxy-to-external-ldap.sh \\
  BIND_LDAP_URI=ldap://example.com \\
  BIND_DN=CN=Administrator,CN=Users,DC=example,DC=com \\
  BIND_PASSWD_PLAINTEXT=secret \\
  BIND_BASE_CTX_SEARCH=CN=Users,DC=example,DC=com \\
EOF
  if [ -z ${LDAP_BASED_OLC_SUFFIX} ]; then
    cat <<EOF
  LDAP_PROXY_OU_NAME=Users \\
  LDAP_BASED_OLC_SUFFIX=dc=example,dc=local
EOF
  else 
    cat <<EOF
  LDAP_PROXY_OU_NAME=Users 
EOF
  fi

  cat <<EOF
--
Example of testing whether a script runs correctly:
./add-proxy-to-external-ldap.sh \\
  BIND_LDAP_URI=ldap://example.com \\
  BIND_DN=CN=Administrator,CN=Users,DC=example,DC=com \\
  BIND_PASSWD_PLAINTEXT=secret \\
  BIND_BASE_CTX_SEARCH=CN=Users,DC=example,DC=com \\
EOF
  if [ -z ${LDAP_BASED_OLC_SUFFIX} ]; then
    cat <<EOF
  LDAP_PROXY_OU_NAME=Users \\
  LDAP_BASED_OLC_SUFFIX=dc=example,dc=local \\
EOF
  else 
    cat <<EOF
  LDAP_PROXY_OU_NAME=Users \\
EOF
  fi
  echo "  --test"
}

setParameter() 
{
   case "${1}" in
      --help)
        printHelp
        exit 0
        ;;
      --test)
        export TEST=1
        ;;
      --addADAttributesMapping)
        export ADD_ATTR_MAPPING=1
        ;;
      *)
       export $1
       ;;
  esac
}

if ! [ -z ${1} ]; then
  setParameter $1
else
  printHelp
  exit 1
fi
if ! [ -z ${2} ]; then
  setParameter $2
else
  printHelp
  exit 1
fi
if ! [ -z ${3} ]; then
  setParameter $3
else
  printHelp
  exit 1
fi
if ! [ -z ${4} ]; then
  setParameter $4
else
  printHelp
  exit 1
fi
if ! [ -z ${5} ]; then
  setParameter $5
else
  printHelp
  exit 1
fi

if ! [ -z ${6} ]; then
  setParameter $6
fi

if ! [ -z ${7} ]; then
  setParameter $7
fi

if ! [ -z ${8} ]; then
  setParameter $8
fi

validate

if ! [ -z ${TEST} ]; then
  export CONNECTION_TEST=`ldapsearch -x -LLL \
   -H ${BIND_LDAP_URI} \
   -D "${BIND_DN}" \
   -w "${BIND_PASSWD_PLAINTEXT}" \
   -b "${BIND_BASE_CTX_SEARCH}" \
   -s sub "(objectClass=*)" dn | grep -c "dn:"`
  if ! [ ${CONNECTION_TEST} -ne 0 ]; then 
    # Błąd połaczenia do zewnętrznego LDA
    echo "[ERROR] External LDAP connection definition error. Connection error."
    exit 1
  fi
  cat ../init/04-add-proxy-to-external-ldap.ldif | envsubst
  echo ""
  echo ""
  echo "--"
  if ! [ -z ${ADD_ATTR_MAPPING} ]; then
  	echo "Mapping of attribute names from external AD named ${LDAP_PROXY_OU_NAME} to local OpenLDAP will be added"
  fi
  echo "[SUCESS] Connection established. Visually check that everything is set correctly in the LDIF command."
else
  LDIF_FILE=${LDAP_CONF_DIR}/create-meta-database-${LDAP_PROXY_OU_NAME}.ldif
  cat ../init/04-add-proxy-to-external-ldap.ldif | envsubst > $LDIF_FILE
  ldapadd -Y EXTERNAL -H ldapi:/// -f $LDIF_FILE
  
  if ! [ -z ${ADD_ATTR_MAPPING} ]; then
    ./add-mapping-of-attribute-names-AD-to-OpenLDAP.sh ${LDAP_PROXY_OU_NAME}
  fi
fi

exit 0