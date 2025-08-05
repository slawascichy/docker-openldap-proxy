# OpenLDAP Proxy

This document provides a comprehensive guide to configuring and maintaining an OpenLDAP server running in proxy (`back-meta`) mode, integrating with Active Directory, the local `mdb` database, and other LDAP sources. The idea is not new; it's described, among others, in the article [Use LDAP Proxy to integrate multiple LDAP servers](https://docs.microfocus.com/doc/425/9.80/configureldapproxy). This article and other sources served as the basis for implementing the basic functionality of the image.

## About OpenLDAP

OpenLDAP is an open-source, community-developed directory software package that implements the Lightweight Directory Access Protocol (LDAP). More information about this product can be found at [https://www.openldap.org/](https://www.openldap.org/).

## 1. Solution Overview and Architecture

### 1.1. Project goal

The OpenLDAP proxy server design aims to unify access to various LDAP data sources (such as Active Directory, a local MDB, or other LDAP-S servers) for client applications. This allows for centralized authentication and authorization and presents a consistent view of the directory, regardless of its internal structure.

The Docker container created in this project can act as an intermediary (proxy) between clients and Active Directory, normalizing the LDAP schema and enabling integration with systems that do not understand the native AD schema.

### 1.2. Architecture diagram

![Diagram architektury proponowanego użycia](https://raw.githubusercontent.com/slawascichy/docker-openldap-proxy/refs/heads/main/doc/docker-openldap-proxy-diagram-en.png)

### 1.3. Software versions

* **OpenLDAP:** OpenLDAP: slapd 2.6.7+dfsg-1~exp1ubuntu8.2 (Dec 9 2024 02:50:18) Ubuntu Developers
* **Container operating system:** ubuntu:latest `org.opencontainers.image.version=24.04`
* **AD Domain Controllers:** Windows Server 2016
* **Tools:** [Apache Directory Studio](https://directory.apache.org/studio/), `ldapsearch`, `ldapadd`, `ldapmodify`, `ping`, `telnet`

## 2. Starting the OpenLDAP Proxy Server

[Docker image](https://hub.docker.com/r/scisoftware/openldap-proxy/tags) is available.

We run the `openldap-proxy` container with the OpenLDAP server as a Docker compose, defined in the `docker-compose.yml` file, or directly from the command line. Below are some example commands:

* Example container launch as a compose:

```bash
docker compose -f docker-compose.yml --env-file ldap-conf.env up -d
```

* Example container launch without compositing (Linux):

```bash
docker run --name openldap-proxy -p 389:389 -p 636:636 \
 --env LDAP_ORG_DC="docker" \
 --env LDAP_LOCAL_OLC_SUFFIX=dc=docker,dc=openldap \
 --env LDAP_BASED_OLC_SUFFIX=dc=scisoftware,dc=pl \
 --env LDAP_ROOT_CN=manager \
 --env LDAP_LOCAL_ROOT_DN=cn=manager,dc=docker,dc=openldap \
 --env LDAP_BASED_ROOT_DN=cn=manager,dc=scisoftware,dc=pl \
 --env LDAP_ROOT_PASSWD_PLAINTEXT=secret \
 --env SERVER_DEBUG=-1 \
 --env LDAP_OLC_ACCESS="by anonymous auth by * none" \
 --volume slapd_proxy_database:/var/lib/openldap \
 --volume slapd_proxy_config:/etc/openldap/slapd.d \
 --detach scisoftware/openldap-proxy:latest
```

* Example of running a container without composition (Windows Cmd):

```bash
docker run --name openldap-proxy -p 389:389 -p 636:636 ^
 --env LDAP_ORG_DC="docker" ^
 --env LDAP_LOCAL_OLC_SUFFIX=dc=docker,dc=openldap ^
 --env LDAP_BASED_OLC_SUFFIX=dc=scisoftware,dc=pl ^
 --env LDAP_ROOT_CN=manager ^
 --env LDAP_LOCAL_ROOT_DN=cn=manager,dc=docker,dc=openldap ^
 --env LDAP_BASED_ROOT_DN=cn=manager,dc=scisoftware,dc=pl ^
 --env LDAP_ROOT_PASSWD_PLAINTEXT=secret ^
 --env SERVER_DEBUG=-1 ^
 --env LDAP_OLC_ACCESS="by anonymous auth by * none" ^
 --volume slapd_proxy_database:/var/lib/openldap ^
 --volume slapd_proxy_config:/etc/openldap/slapd.d ^
 --detach scisoftware/openldap-proxy:latest
```

### 2.1. Installation Steps

#### 2.1.1 Prepare the Docker theme configuration file

Create your own Docker theme configuration. Copy the sample `ldap-conf.env` file included in the project to a file with your own name, e.g., `my-ldap-conf.env`. The configuration file contains the following parameters:

| Parameter Name | Description |
| :---- | :---- |
| LDAP_ORG_DC | Name, acronym of the organization. Example value: `scisoftware`. |
| LDAP_LOCAL_OLC_SUFFIX | DN (Distinguished Name) of the local MDB domain where local users and groups will be stored; the first value of the `dc` attribute must be named after the previously defined organization name in the `${LDAP_ORG_DC}` parameter. Example: `dc=scisoftware,dc=local`. |
| LDAP_BASED_OLC_SUFFIX | DN (Distinguished Name) of the OpenLDAP server's base domain. Individual external repositories (proxies) will be attached to this domain. An example value is `dc=scisoftware,dc=pl`. A local MDB will also be attached to this domain automatically (during proxy database initialization) under the tree name `ou=local,${LDAP_BASED_OLC_SUFFIX}`, e.g., `ou=local,dc=scisoftware,dc=pl`. | | LDAP_ROOT_CN | Username of the user with superuser privileges. For example, `manager`. | | LDAP_ROOT_PASSWD_PLAINTEXT | Password of the user with superuser privileges. The password will be decrypted. During initialization, it will be encrypted and placed in the appropriate user entry. For example, `secret`. | | LDAP_OLC_ACCESS | Final configuration of the `olcAccess: to *` access rights role. The default value is `"by * none"`. The predefined database rights will be described later in this document, however, some software requires the `"by * read"` value, e.g., Kerberos configuration, [ldap-ui](https://github.com/dnknth/ldap-ui). |
| LDAP_ROOT_CN | The name of a user with superuser privileges. For example, `manager`. |
| LDAP_ROOT_PASSWD_PLAINTEXT | The password of a user with superuser privileges. The password has been decrypted. During initialization, it will be encrypted and placed in the appropriate user entry. For example, `secret`. |
| LDAP_OLC_ACCESS | The final configuration of the `olcAccess: access rights role is *`. The default value is `"by * none"`. How database rights are predefined will be described later in the document, however some software requires the `"by * read"` value, e.g. Kerberos configuration, [ldap-ui](https://github.com/dnknth/ldap-ui). |
| SERVER_DEBUG | Event logging level. This parameter is useful for analyzing issues you may encounter when building your own solutions using this OpenLDAP proxy image. The default value is `32`. |
| LDAP_TECHNICAL_USER_CN | (optional) The name of the predefined technical user through whom you will communicate to access OpenLDAP server data. The default value is `frontendadmin`. |
| LDAP_TECHNICAL_USER_PASSWD | (optional) Technical user password. Decoded password. Default value is `secret`. |
| PHPLDAPADMIN_HTTPS | (optional) Configuration parameter needed when launching the theme with the [osixia/phpldapadmin](https://github.com/osixia/docker-phpLDAPadmin) UI application. Defines whether the application should be launched using the HTTPS protocol. Default value is `true`. |
| PHPLDAPADMIN_HTTPS_CRT_FILENAME | (optional) Configuration parameter needed when launching the theme with the [osixia/phpldapadmin](https://github.com/osixia/docker-phpLDAPadmin) UI application. Defines the filename of the server's SSL certificate. Default value is `server-cert-chain.crt`. |
| PHPLDAPADMIN_HTTPS_KEY_FILENAME | (optional) A configuration parameter needed when running the theme with the [osixia/phpldapadmin](https://github.com/osixia/docker-phpLDAPadmin) UI application. It defines the filename of the server's private key. The default value is `server-cert.key`. |
| PHPLDAPADMIN_HTTPS_CA_CRT_FILENAME | (optional) A configuration parameter needed when running the theme with the [osixia/phpldapadmin](https://github.com/osixia/docker-phpLDAPadmin) UI application. It defines the filename of the CA of the organization that signed the server's SSL certificate. The default value is `scisoftware_intermediate_ca.crt`. |

#### 2.1.2 Prepare Volumes for Proxy Database Data

Running the container requires `openldap-proxy` to have at least four volumes where it stores configuration and database files. If you review the `docker-compose.yml` file, you'll notice that the compose has predefined volume locations in the local directory of the machine running the container.

Below is a list of the volumes used by the `openldap-proxy` container:

| Volume Name | Description |
| :---- | :---- |
| `openldap` | The root volume, where local MDB database data is stored. The default location is the local `/d/mercury/openldap-proxy` directory. The volume is mounted to the `/var/lib/ldap` path on the container. |
| `slapd-d` | A volume with the OpenLDAP proxy instance configuration `(cn=config)`. The default location is the local `/d/mercury/slapd.d-proxy` directory. The volume is connected to the `/etc/ldap/slapd.d` path on the container. |
| `ca-certificates` | A volume with certificates confirming the identity of connected external servers that communicate using SSL (the `ldaps` protocol). The SSL communication configuration is contained in the `/etc/ldap/ldap.conf` file on the container. Place and store certificates for trusted organizations and LDAP servers in the specified local directory. The default location is the local `/d/mercury/openldap-cacerts` directory. The volume is connected to the `/usr/local/share/ca-certificate` path on the container. |
| `lapd-workspace` | (optional) a volume with various scripts needed for analyzing problems or perhaps adjusting database parameters in the container using this image. The default location is the local directory `/d/workspace/git/docker-openldap-proxy/workspace`. The volume is connected to the `/opt/workspace` path in the container. |

Below is an excerpt from the composition definition:

```yml
    volumes: 
      - openldap:/var/lib/ldap:rw
      - slapd-d:/etc/ldap/slapd.d:rw
      - ca-certificates:/usr/local/share/ca-certificate:rw
      - lapd-workspace:/opt/workspace:rw
```

### 2.2. Automatically Creating an OpenLDAP Instance

After starting the container, the startup script will attempt to create a database and start an OpenLDAP server instance.
The database creation attempt is based on the existence of the `ldap.init` file in the `/var/lib/ldap` directory on the container. This directory maps to the volume named `openldap`.

> [!TIP]
> If you want to rebuild the OpenLDAP database, simply delete the `ldap.init` file.

> [!CAUTION]
> If you delete the `ldap.init` file, you will lose all existing data.

### 2.3. Adding a Proxy to an External Database

Adding another external database is done after the container is started. Manually run the `add-proxy-to-external-ldap.sh` script, which can be found in the `/opt/service` directory on the container. To run the script, log in to the console of the running container by issuing commands in the command line:

```bash
export CONTAINER_ID=`docker container ls | grep "<container_name>" | awk '{print $1}'`
docker exec -it ${CONTAINER_ID} bash
```

* where `<container_name>` is the name of the container under which the OpenLDAP service was launched, e.g., `openldap-proxy`

Example:

```bash
export CONTAINER_ID=`docker container ls | grep "openldap-proxy" | awk '{print $1}'`
docker exec -it ${CONTAINER_ID} bash
```

After logging in to the container console, run the `add-proxy-to-external-ldap.sh` script with the appropriate input parameters. The required parameters are described below:

| Parameter Name | Description |
| :---- | :---- |
| `BIND_LDAP_URI=<value>` | URL pointing to the external LDAP instance, e.g., `<ldap|ldaps>://example.com`. |
| `BIND_DN=<value>` | The distinguished name of the user through which communication will be performed. |
| `BIND_PASSWD_PLAINTEXT=<value>` | The password of the user through which communication will be performed. |
| `BIND_BASE_CTX_SEARCH=<value>` | The main search branch of the LDAP instance being connected (base context). |
| `LDAP_PROXY_OU_NAME=<value>` | The name of the organizational unit where the merged LDAP tree should appear. |

Optional parameters can be used with one of the following options:

| Option Name | Description |
| :---- | :---- |
| `--help` | Presents help data for running the script. |
| `--test` | Tests the command for correctness. |
| `--addADAttributesMapping` | adds a mapping of attribute names from the external Active Directory to the local OpenLDAP. |

All of the above information can be obtained by issuing the command:

```bash
./add-proxy-to-external-ldap.sh --help
```

> [!IMPORTANT]
> Before issuing the command to add a database, first test whether the connection definition is correct. Use the `--test` option when running the script for the first time.

> [!IMPORTANT]
> When defining connections to AD, use the `--addADAttributesMapping` option. If you forget, don't worry. You can always run the `./add-mapping-of-attribute-names-AD-to-OpenLDAP.sh <organizational_unit_name>` script later.

Example 1:

```bash Testowanie połączenia do AD o nazwie "pluton"
./add-proxy-to-external-ldap.sh \
  BIND_LDAP_URI=ldap://pluton.example.com \
  BIND_DN=CN="proxyadmin,OU=ServiceAccounts,DC=example,DC=local"\
  BIND_PASSWD_PLAINTEXT="secret" \
  BIND_BASE_CTX_SEARCH=CN=Users,DC=example,DC=local \
  LDAP_PROXY_OU_NAME=pluton --addADAttributesMapping --test 
```
* The connection will be added after running the above command without the `--test` option.

Example 2:

```bash Testowanie połączenia do OpenLDAP o nazwie "ibpm"
./add-proxy-to-external-ldap.sh \
  BIND_LDAP_URI=ldaps://192.168.1.123:9636 \
  BIND_DN=cn=GIToperator,ou=technical,dc=ibpm,dc=example \
  BIND_PASSWD_PLAINTEXT=secret \
  BIND_BASE_CTX_SEARCH=ou=ibpm.pro,dc=ibpm,dc=example \
  LDAP_PROXY_OU_NAME=ibpm --test
```
* the connection will be added after running the above command without the `--test` option.

### 2.4. LDIF Files Used for Configuration

Below is a list of key LDIF files used for proxy server configuration. These files are located in the project's `init` directory and are placed in the `/opt/init` location on the container.

* `01-slapd.conf` - Basic configuration of the OpenLDAP database instance, containing the `(cn=config)` and `(cn=monitor)` definitions. It also contains a list of loaded schemas (attribute and class definitions stored in object databases).
* `02-mdbdatabase-create.ldif` - Definition of the local `mdb` database for storing local user data. This database has its DN defined in the `${LDAP_LOCAL_OLC_SUFFIX}` variable, e.g., `dc=scisoftware,dc=local`.
* `03-metadatabase-create.ldif` - Definition of a local `mdb` subordinate database (with the `olcSubordinate: TRUE` field). A database whose DN was defined as `dc=subordinate,${LDAP_BASED_OLC_SUFFIX}`, e.g. `dc=subordinate,dc=scisoftware,dc=pl`. In practice, we do not use this database, but it implicitly allows navigating the main tree of the created `meta` database with the DN defined in the `${LDAP_LOCAL_OLC_SUFFIX}` variable, e.g. `dc=scisoftware,dc=pl`. Thanks to this configuration, databases connected in the future will be visible as its subtrees, their data will be processed with the definition of `baseDN=${LDAP_LOCAL_OLC_SUFFIX}`, e.g. `baseDN=dc=scisoftware,dc=pl` (see the article [Combining OpenLDAP and Active Directory via OpenLDAP meta backend](https://serverfault.com/questions/1152227/combining-openldap-and-active-directory-via-openldap-meta-backend/1190129?noredirect=1#comment1542537_1190129)). The configuration file also contains the configuration of the connection (proxy) to the local `mdb` database defined in the `02-mdbdatabase-create.ldif` file. The connected local database will have the following DN value: `ou=local,${LDAP_BASED_OLC_SUFFIX}`, e.g., `ou=local,dc=scisoftware,dc=pl`.
* `04-add-proxy-to-external-ldap.ldif` - Adds a subdatabase (proxy). This file is used by the script for adding/defining communication with an external LDAP database. This file is used by the `add-proxy-to-external-ldap.sh` script and is used as a mechanism for adding another external database.
* `06-add-all-dbmap-for-ad-proxy.ldif` - Adds a mapping of external AD database attribute names to local OpenLDAP attribute names. This file is used by the `add-proxy-to-external-ldap.sh` script, which is used as a mechanism for adding another external database, and `add-mapping-of-attribute-names-AD-to-OpenLDAP.sh`, which adds attributes to an existing connection to an external LDAP database.

### 2.5. SSL/TLS Configuration

* **Certificate Files:**
  * `olcTLSCertificateFile`: `/usr/local/share/ca-certificate/server_cert.pem`
  * `olcTLSCertificateKeyFile`: `/usr/local/share/ca-certificate/server_key.pem`
  * `olcTLSCACertificateFile`: `/usr/local/share/ca-certificate/ca_certs.pem`
* **TLS Required:** `olcTLSVerifyClient: demand` (or `allow`, `never` depending on requirements)
* **Protocol Versions:** `olcTLSProtocolMin: 3.2`

### 2.6. Custom Attribute Schemas

> [!NOTE]
> As part of the `core` schema adaptation, the definition of the `uniqueMember` attribute has been changed. Originally, it defines a unique group member according to RFC2256 and is of type "Name or unique UID" `1.3.6.1.4.1.1466.115.121.1.34 - Name and Optional UID syntax`. However, this type is not translated from the external database value to the local one during proxy execution. Therefore, one definition has been changed to `( 2.5.4.50 NAME 'uniqueMember' DESC 'RFC2256: unique member of a group' EQUALITY distinguishedNameMatch SUP distinguishedName )`.

#### 2.6.1. AD Attribute Schema

This schema allows for the representation of attributes with AD-derived names within an OpenLDAP server. It contains definitions of object classes named `aDPerson`, `groupOfMembers`, `team`, `container`, `group`, and `user`:

<details>
<summary>schemas\002-ADPerson.ldif</summary>

```ldif
#
# Substitute for MS Active Directory schema
#
# created by: Sławomir Cichy (slawas@slawas.pl)
# Only required attributes from Microsoft's schemas
#
dn: cn=adperson,cn=schema,cn=config
objectClass: olcSchemaConfig
cn: adperson
#
olcAttributeTypes: ( 1.2.840.113556.1.4.221 NAME 'sAMAccountName' EQUALITY caseIgnoreMatch SYNTAX '1.3.6.1.4.1.1466.115.121.1.15' SINGLE-VALUE )
olcAttributeTypes: ( 1.2.840.113556.1.4.656 NAME 'userPrincipalName' EQUALITY caseIgnoreMatch SYNTAX '1.3.6.1.4.1.1466.115.121.1.15' SINGLE-VALUE )
olcAttributeTypes: ( 1.2.840.113556.1.4.657 NAME 'msExchUserCulture' EQUALITY caseIgnoreMatch SYNTAX '1.3.6.1.4.1.1466.115.121.1.15' SINGLE-VALUE )
olcAttributeTypes: ( 1.2.840.113556.1.2.146 NAME 'company' EQUALITY caseIgnoreMatch SYNTAX '1.3.6.1.4.1.1466.115.121.1.15'  SINGLE-VALUE )     
olcAttributeTypes: ( 1.2.840.113556.1.4.35  NAME 'employeeID' SYNTAX '1.3.6.1.4.1.1466.115.121.1.15' SINGLE-VALUE )
olcAttributeTypes: ( 1.2.840.113556.1.4.2 NAME 'objectGUID' SYNTAX '1.3.6.1.4.1.1466.115.121.1.40' SINGLE-VALUE )
olcAttributeTypes: ( 1.2.840.113556.1.4.146 NAME 'objectSid' SYNTAX '1.3.6.1.4.1.1466.115.121.1.40' SINGLE-VALUE )
olcAttributeTypes: ( 2.16.840.1.113730.3.1.35 NAME 'thumbnailPhoto' SYNTAX '1.3.6.1.4.1.1466.115.121.1.40' SINGLE-VALUE )
olcAttributeTypes: ( 1.2.840.113556.1.4.90 NAME 'unicodePwd' SYNTAX '1.3.6.1.4.1.1466.115.121.1.40' SINGLE-VALUE )
olcAttributeTypes: ( 1.2.840.113556.1.4.159 NAME 'accountExpires' SYNTAX '1.3.6.1.4.1.1466.115.121.1.27' SINGLE-VALUE )
olcAttributeTypes: ( 1.2.840.113556.1.4.96 NAME'pwdLastSet' SYNTAX '1.3.6.1.4.1.1466.115.121.1.27' SINGLE-VALUE )
olcAttributeTypes: ( 1.1.2.1.1 NAME 'department' DESC 'Department Name' EQUALITY caseIgnoreMatch SUBSTR caseIgnoreSubstringsMatch SYNTAX 1.3.6.1.4.1.1466.115.121.1.15 SINGLE-VALUE )
# Original ( 1.2.840.113556.1.2.102 NAME 'memberOf' SYNTAX '1.3.6.1.4.1.1466.115.121.1.12' NO-USER-MODIFICATION )
olcAttributeTypes: ( 1.2.840.113556.1.2.102 NAME 'memberOf' SUP distinguishedName )
##################################################
# Custom polish MPK fields - START
olcAttributeTypes: ( 1.2.840.113556.1.4.700 NAME 'MPK1Name' DESC 'Name of the first cost center - MPK (Cost Center)' EQUALITY caseIgnoreMatch  SYNTAX '1.3.6.1.4.1.1466.115.121.1.15' SINGLE-VALUE )
olcAttributeTypes: ( 1.2.840.113556.1.4.701 NAME 'MPK1Code' DESC 'Code of the first cost center - MPK (Cost Center)' EQUALITY caseIgnoreMatch  SYNTAX '1.3.6.1.4.1.1466.115.121.1.15' SINGLE-VALUE )
olcAttributeTypes: ( 1.2.840.113556.1.4.702 NAME 'MPK2Name' DESC 'Name of the second cost center - MPK (Cost Center)' EQUALITY caseIgnoreMatch  SYNTAX '1.3.6.1.4.1.1466.115.121.1.15' SINGLE-VALUE )
olcAttributeTypes: ( 1.2.840.113556.1.4.703 NAME 'MPK2Code' DESC 'Code of the second cost center - MPK (Cost Center)' EQUALITY caseIgnoreMatch  SYNTAX '1.3.6.1.4.1.1466.115.121.1.15' SINGLE-VALUE )
# Custom polish MPK fields - START
##################################################
olcObjectClasses: ( 1.2.840.113556.1.4.220 NAME 'aDPerson' DESC 'MS Active Directory Person Entry' SUP inetOrgPerson  STRUCTURAL MUST ( uid $ sAMAccountName ) MAY ( userPrincipalName $ msExchUserCulture $ MPK1Code $ MPK1Name $ MPK2Code $ MPK2Name $ userPassword $ company $ employeeID $ objectGUID $ objectSid $ thumbnailPhoto $ unicodePwd $ accountExpires $ pwdLastSet $ department) )
olcObjectClasses: ( 1.2.840.113556.1.4.803 NAME 'groupOfMembers' DESC 'MS Active Directory group entry' SUP top STRUCTURAL MUST ( cn ) MAY ( cn $ mail $ name $ displayName $ description $ manager $ member $ memberOf $ sAMAccountName $ objectGUID $ objectSid ) X-ORIGIN 'AD Group' )
olcObjectClasses: ( 1.2.840.113556.1.4.804 NAME 'team' DESC 'MS Active Directory group entry with required common name and display name' SUP top STRUCTURAL MUST ( cn $ displayName ) MAY ( mail $ name $ description $ manager $ member $ memberOf $ sAMAccountName $ objectGUID $ objectSid ) X-ORIGIN 'AD Group' )
olcObjectClasses: ( 1.2.840.113556.1.3.23 NAME 'container' SUP top STRUCTURAL MUST (cn ) )
olcObjectClasses: ( 1.2.840.113556.1.5.8 NAME 'group' SUP top STRUCTURAL MUST (cn $ sAMAccountName ) )
olcObjectClasses: ( 1.2.840.113556.1.5.9 NAME 'user' SUP inetOrgPerson STRUCTURAL MUST ( uid $ sAMAccountName ) )
```
</details>

#### 2.6.2. CSZU Attribute Schema

**CSZU** (Polish abbreviation for Central User Management System) is a proprietary user repository system. The loaded schema contains definitions of object classes named `cszuAttrs`, `cszuPrivs`, `cszuUser`, and `cszuGroup`:

<details>
<summary>schemas\005-cszu.ldif</summary>

```ldif
#
# Author's scheme supporting the Central User Management System 
# (Centralny System Zarządzania Użytkownikami - CSZU)
#
# The schema supports data synchronization between OpenLDAP and IBM BPM. 
# Additionally, it contains the attribute 'allowSystem', which is used 
# as an additional filter in integration with sssd (Unix)
#
# Value's format in 'allowSystem' attribute is:
# 	<host_name>;<service_name>;<expiration_date_in_format_YYYYMMDDHH24mm>;<task_ID>
# Where:
#  - host_name: name of host
#  - service_name - name of service
#  - expiration_date_in_format_YYYYMMDDHH24mm - date of expiration of privilege 
#  - task_ID - task identifier in the service system
# Samples:
#   admin.scisoftware.pl;shell;203512300000;POC-01
#   admin.scisoftware.pl;IBMBPM;203512300000;POC-01
# Sample of using the 'allowSystem' attribute as additional user's filter (sssd configuration):
# LDAP_ACCESS_FILTER=(&(objectclass=shadowaccount)(objectclass=posixaccount)(allowSystem=admin.scisoftware.pl;shell;*))
#
#
#	Created by: Sławomir Cichy (slawas@slawas.pl)
#   Copyright 2014-2024 SciSoftwere Sławomir Cichy Inc.
#
dn: cn=cszu,cn=schema,cn=config
objectClass: olcSchemaConfig
cn: cszu
#
olcAttributeTypes: ( 1.3.6.1.4.1.2021.3.1.4 NAME 'primaryGroup' SUP distinguishedName )
olcAttributeTypes: ( 1.3.6.1.4.1.2021.3.1.5 NAME 'primaryGroupName' EQUALITY caseIgnoreMatch SYNTAX '1.3.6.1.4.1.1466.115.121.1.15' SINGLE-VALUE )
olcAttributeTypes: ( 1.3.6.1.4.1.2021.3.1.3 NAME 'department' EQUALITY caseIgnoreMatch SYNTAX '1.3.6.1.4.1.1466.115.121.1.15' SINGLE-VALUE )
olcAttributeTypes: ( 1.3.6.1.4.1.2021.3.1.6 NAME 'departmentCode' EQUALITY caseIgnoreMatch SYNTAX '1.3.6.1.4.1.1466.115.121.1.15' SINGLE-VALUE )
olcAttributeTypes: ( 1.3.6.1.4.1.2021.3.1.7 NAME 'isChief' EQUALITY booleanMatch SYNTAX 1.3.6.1.4.1.1466.115.121.1.7 SINGLE-VALUE )
olcAttributeTypes: ( 1.3.6.1.4.1.2021.3.1.9 NAME 'isActive' EQUALITY booleanMatch SYNTAX 1.3.6.1.4.1.1466.115.121.1.7 SINGLE-VALUE )
olcAttributeTypes: ( 1.3.6.1.4.1.2021.3.1.8 NAME 'hrNumber' DESC 'RFC2307: An integer uniquely identifying ih HR System' EQUALITY integerMatch SYNTAX 1.3.6.1.4.1.1466.115.121.1.27 SINGLE-VALUE )
olcAttributeTypes: ( 1.3.6.1.4.1.2021.3.0.2 NAME 'allowSystem' EQUALITY caseIgnoreMatch SUBSTR caseIgnoreSubstringsMatch SYNTAX '1.3.6.1.4.1.1466.115.121.1.15')
olcAttributeTypes: ( 1.3.6.1.4.1.2021.3.0.3 NAME 'entryDistinguishedName' SUP distinguishedName )
olcAttributeTypes: ( 1.3.6.1.4.1.2021.3.2.4 NAME 'managerGroup' SUP distinguishedName )
olcAttributeTypes: ( 1.3.6.1.4.1.2021.3.2.3 NAME 'managerGroupName' EQUALITY caseIgnoreMatch SYNTAX '1.3.6.1.4.1.1466.115.121.1.15' SINGLE-VALUE )
olcObjectClasses: ( 1.3.6.1.4.1.2021.3.0.1 NAME 'cszuAttrs' DESC 'Attributes used by CSZU' AUXILIARY MUST ( allowSystem $ entryDistinguishedName ))
olcObjectClasses: ( 1.3.6.1.4.1.2021.3.0.2 NAME 'cszuPrivs' DESC 'Granted access to systems' AUXILIARY MUST ( allowSystem $ entryDistinguishedName ))
olcObjectClasses: ( 1.3.6.1.4.1.2021.3.1.1 NAME 'cszuUser' DESC 'Attributes used by CSZU for user entries' SUP cszuAttrs AUXILIARY MUST ( primaryGroup ) MAY ( primaryGroupName $ department $ departmentCode $ isChief $ isActive $ hrNumber $ allowSystem $ entryDistinguishedName) )
olcObjectClasses: ( 1.3.6.1.4.1.2021.3.2.1 NAME 'cszuGroup' DESC 'Attributes used by CSZU for group entries' SUP cszuAttrs AUXILIARY MUST ( cn $ managerGroup ) MAY ( mail $ name $ displayName $ description $ manager $ member $ memberOf))
```

</details>

### 2.7 Predefined Entries in the Local Database

When the service is first started, the local database is initialized using predefined entries.

- The database contains four predefined organizational units (OUs):
  - `ou=Groups,ou=local,${LDAP_BASED_OLC_SUFFIX}` - for local group data, example: `ou=Groups,ou=local,dc=scisoftware,dc=pl`
  - `ou=People,ou=local,${LDAP_BASED_OLC_SUFFIX}` - for local user data
  - `ou=Technical,ou=local,${LDAP_BASED_OLC_SUFFIX}` - for local technical user data; user entries from this OU have read permissions for all entries; they can be used in connection definitions for external systems. - `ou=Admins,${LDAP_BASED_OLC_SUFFIX}` - for local administrative user data; user entries from this organizational unit have full data management permissions.

- Predefined entries defining user groups:
  - `cn=mrc-admin,ou=local,ou=Groups,${LDAP_BASED_OLC_SUFFIX}` - a user group with administrator privileges, used by the [Mercury 3.0 (HgDB)](https:///hgdb.org) system.
  - `cn=mrc-user,ou=local,ou=Groups,${LDAP_BASED_OLC_SUFFIX}` - a user group with data access permissions, used by the [Mercury 3.0 (HgDB)](https:///hgdb.org) system.

- Predefined user definition entries:
  - `${LDAP_ROOT_CN}`,ou=local,${LDAP_BASED_OLC_SUFFIX} - LDAP manager, the user has all permissions for all entries; the user's password should be defined in the `LDAP_ROOT_PASSWD_PLAINTEXT` environment variable (default value: "secret") and should be changed in production environments. Example name: `cn=manager,ou=local,dc=scisoftware,dc=pl`
  - `cn=ldapadmin,ou=Admins,ou=local,${LDAP_BASED_OLC_SUFFIX}` - administrator, the user has write permissions for all entries; the user's password should be defined in the `LDAP_TECHNICAL_USER_PASSWD` environment variable (default value: "secret") and should be changed in production environments. - `uid=ldapui,ou=Admins,ou=local,${LDAP_BASED_OLC_SUFFIX}` - administrator, this user has write permissions to all entries; the user's password should be defined in the `LDAP_TECHNICAL_USER_PASSWD` environment variable (default value: "secret") and should be changed in production environments. This entry can be used for integration with the LDAP user interface.
  - `cn=${LDAP_TECHNICAL_USER_CN},ou=Technical,ou=local,${LDAP_BASED_OLC_SUFFIX}` - technical user for defining communication with the OpenLDAP server; the default value of `LDAP_TECHNICAL_USER_CN` is "frontendadmin", this user entry has read permissions to all entries; The user's password should be defined in the `LDAP_TECHNICAL_USER_PASSWD` environment variable (default value: "secret") and should be changed in production environments.
  - `uid=mrcmanager,ou=People,ou=local,${LDAP_BASED_OLC_SUFFIX}` - an example user with system administrator privileges for [Mercury 3.0 (HgDB)](https:///hgdb.org); the user's password should be defined in the `LDAP_TECHNICAL_USER_PASSWD` environment variable (default value: "secret") and should be changed in production environments.
  - `uid=mrcuser,ou=People,ou=local,${LDAP_BASED_OLC_SUFFIX}` - an example user with system user privileges for [Mercury 3.0 (HgDB)](https:///hgdb.org); the user password should be defined in the `LDAP_TECHNICAL_USER_PASSWD` environment variable (default value: "secret") and changed in production environments.
  
![Przykład predefiniowanego drzewa lokalnej bazy danych](https://raw.githubusercontent.com/slawascichy/docker-openldap-proxy/refs/heads/main/doc/sample-predefined-tree-by-apache-dir-studio.png)

## 3. Mapping Attributes and Object Classes (`olcDbMap`)

Attribute mapping is performed using the `olcDbMap` attribute in the configuration of each `olcMetaSub` subdatabase.

### 3.1. Predefined Mappings Table

Below is a table of predefined mappings for connections to AD databases. The table below lists the mapped attributes and was developed based on the most commonly used mappings in various IT systems.

| Attribute<br/>in OpenLDAP | Attribute<br/>in Active Directory | Description |
| :--- | :--- | :--- |
| `uid` | `sAMAccountName` | The primary unique user identifier, often used as the login name. |
| `entryDistinguishedName` | `distinguishedName` | The full DN path of the object in the AD directory. |
| `jpegPhoto` | `thumbnailPhoto` | Thumbnail of the user's photo (binary). |
| `unicodePwd` | `userPassword` | User password (system attribute, rarely used directly). |
| `shadowExpire` | `accountExpires` | User account expiration date and time. |
| `shadowLastChange` | `pwdLastSet` | Date and time of the last password change. |
| `entryUUID` | `objectGUID` | Unique object identifier (GUID), binary in AD, UUID string in OpenLDAP. |
| `objectSid` | `objectSid` | Security identifier (SID) of the object in AD (binary). |
| `uniqueMember` | `member` | Group member (used in OpenLDAP groups, equivalent to "member" in AD). |
| `cn` | `cn` | Common Name (Common Name). |
| `givenName` | `givenName` | User's First Name. |
| `sn` | `sn` | User's Surname (Surname). |
| `displayName` | `displayName` | User's Display Name. |
| `mail` | `mail` | User's Email Address. |
| `telephoneNumber` | `telephoneNumber` | Landline Phone Number. |
| `mobile` | `mobile` | Mobile Phone Number. |
| `description` | `description` | Object Description. |
| `physicalDeliveryOfficeName` | `physicalDeliveryOfficeName` | Office/Physical Location Name. |
| `title` | `title` | Job Title. |
| `company` | `company` | Company Name. |
| `memberOf` | `memberOf` | The groups to which the object belongs (not transferable, requires synchronization). |
| `name` | `name` | The object name (identical to the CN for most objects). |
| `preferredLanguage` | `preferredLanguage` | The user's preferred language. |
| `generationQualifier` | `generationQualifier` | Generation qualifier (e.g., Jr., Sr., III). |
| `personalTitle` | `personalTitle` | Personal title/form of address (e.g., Dr., Mr.). |
| `employeeID` | `employeeID` | The employee ID. |
| `l` | `l` | City (Locality). |
| `c` | `c` | Country (Country). |
| `department` | `department` | The department to which the user belongs. |
| `streetAddress` | `streetAddress` | Street address. |

The table below shows the class mapping:

| Object Class<br/>in OpenLDAP | Object Class<br/>in Active Directory | Description |
| :--- | :--- | :--- |
| `inetOrgPerson` | `organizationalPerson` | Object class for people in organizations. |
| `aDPerson` | `user` | Object class for AD users. |
| `groupOfUniqueNames` | `group` | Object class for groups (often with unique members). |
| `domain` | `CONTAINER` | Object class representing a domain or container. |

---

According to **Gemini** (Google), 2025, mapping attributes with the same names is primarily for schema normalization and control:

**The purpose of mapping attributes with the same names**

Mapping attributes with identical names in the OpenLDAP configuration, for example, `olcDbMap: attribute cn cn`, may seem unnecessary, but it is crucial for the correct operation and control of the proxy server. The idea is to formally and explicitly declare how OpenLDAP should treat attributes originating from a remote source, such as Active Directory.

**Main reasons for mapping attributes**

* **Schema normalization:** Even if attribute names are the same as `cn`, their definitions in the OpenLDAP and Active Directory schemas may differ. Explicit mapping forces OpenLDAP to use its own schema definitions** and retrieve the attribute value from the appropriate field in AD. This ensures consistency and prevents errors.
* **Enforcing visibility:** This configuration is a form of access control. Only attributes that are explicitly mapped will be visible to the LDAP client. This is a way to filter attributes and restrict access to unnecessary data.
* **A foundation for advanced operations:** Explicit mapping is a necessary first step if you plan to use more advanced modules, such as `slapo-rwm`, to transform attribute values in the future. This way, the server knows that the `entryUUID` attribute should retrieve the value from `objectGUID`, and only then can further operations be performed.

In summary, mapping attributes with the same names is a conscious declaration that ensures that data is processed and presented as expected, regardless of differences in schema definitions.

---

### 3.2. Attribute Mapping Rationale

Attribute mapping between OpenLDAP and Active Directory is intended to normalize names, align schemas, and facilitate integration. The rationale for key mappings is provided below.

* **`uid` <-> `sAMAccountName`**: This mapping enables the use of the **`uid`** (Username Identifier) attribute, common in Linux/UNIX systems, for identification and authentication. It maps to **`sAMAccountName`**, the unique login name in Active Directory.
* **`entryDistinguishedName` <-> `distinguishedName`**: Ensures that OpenLDAP clients see the full, canonical DN path of an object, as defined in Active Directory. * **`jpegPhoto` <-> `thumbnailPhoto`**: Converts the AD-specific thumbnail photo attribute (**`thumbnailPhoto`**) to the more generic **`jpegPhoto`** attribute used in the LDAP standard.
* **`unicodePwd` <-> `userPassword`**: Maps the AD password attribute to the standard **`userPassword`** attribute. Note that this mapping is for authentication purposes only and does not reveal the raw password.
* **`shadowExpire` <-> `accountExpires`**: Allows retrieving the account expiration date in the standard OpenLDAP **`shadowExpire`** format, mapping it to the AD equivalent. * **`shadowLastChange` <-> `pwdLastSet`**: Allows monitoring the last password change date using the standard **`shadowLastChange`** attribute, which maps to **`pwdLastSet`** from AD.
* **`entryUUID` <-> `objectGUID`**: This mapping is crucial for uniquely identifying objects. It maps the binary, unique object identifier from AD (**`objectGUID`**) to the **`entryUUID`** attribute, which in the OpenLDAP world is the standard, string-based entry identifier.
* **`objectSid` <-> `objectSid`**: This mapping ensures that the **`objectSid`** attribute, the unique security identifier in AD, is visible and accessible to OpenLDAP clients under its original name.
* **`uniqueMember` <-> `member`**: Allows for correct mapping of group members. The **`member`** attribute in AD maps to **`uniqueMember`**, which is consistent with the 'groupOfUniqueNames` schema in OpenLDAP.

### 3.3. GUID/SID Support

The `objectGUID` and `objectSid` attributes are binary attributes specific to Active Directory. We haven't yet been able to resolve the issue of correctly mapping the `objectGUID` field (AD) to the `entryUIID` field (OpenLDAP). I've started a thread on [objectGUID to entryUUID mapping in OpenLDAP proxy with AD](https://serverfault.com/questions/1190133/objectguid-to-entryUUID-mapping-in-openldap-proxy-with-AD) - we'll see if someone can solve the problem.

## 4. Authentication and Authorization

### 4.1. ACL (Access Control Lists) - `olcAccess`

Precise ACL configuration is crucial for security. The container starts and initializes with the following `olcAccess` field definitions. Similar permissions have been predefined for the local `mdb` and `meta` databases.

The following sets of permissions are specified:

* Access to the password attribute for login/change purposes

```ldif
olcAccess: to attrs=userPassword,sambaNTPassword by dn.exact="gidNumber=0+uidNumber=0,cn=peercred,cn=external,cn=auth" manage by dn="${LDAP_LOCAL_ROOT_DN}" manage by dn.children="ou=Admins,${LDAP_LOCAL_OLC_SUFFIX}" write by dn.children="ou=Technical,${LDAP_LOCAL_OLC_SUFFIX}" read by dn="${LDAP_BASED_ROOT_DN}" manage by dn.children="ou=Admins,ou=local,${LDAP_BASED_OLC_SUFFIX}" write by dn.children="ou=Technical,ou=local,${LDAP_BASED_OLC_SUFFIX}" read by self write by anonymous auth by * none
```

* Access to the password history attribute

```ldif
olcAccess: to attrs=sambaPasswordHistory,sambaPwdLastSet,shadowLastChange by dn.exact="gidNumber=0+uidNumber=0,cn=peercred,cn=external,cn=auth" manage by dn="${LDAP_LOCAL_ROOT_DN}" manage by dn.children="ou=Admins,${LDAP_LOCAL_OLC_SUFFIX}" write by dn.children="ou=Technical,${LDAP_LOCAL_OLC_SUFFIX}" read by dn="${LDAP_BASED_ROOT_DN}" manage by dn.children="ou=Admins,ou=local,${LDAP_BASED_OLC_SUFFIX}" write by dn.children="ou=Technical,ou=local,${LDAP_BASED_OLC_SUFFIX}" read by self auth by self write by * none
```

* Accessing an attribute using a Kerberos key

```ldif
olcAccess: to attrs=krbPrincipalKey by dn.exact="gidNumber=0+uidNumber=0,cn=peercred,cn=external,cn=auth" manage by dn.exact="uid=kdc-service,${LDAP_LOCAL_OLC_SUFFIX}" read by dn.exact="uid=kadmin-service,${LDAP_LOCAL_OLC_SUFFIX}" write by dn.exact="uid=kdc-service,ou=local,${LDAP_BASED_OLC_SUFFIX}" read by dn.exact="uid=kadmin-service,ou=local,${LDAP_BASED_OLC_SUFFIX}" write by self auth by self write by * none
```

* Access to the local Kerberos branch

```ldif
olcAccess: to dn.subtree="cn=Kerberos,${LDAP_LOCAL_OLC_SUFFIX}" by dn.exact="gidNumber=0+uidNumber=0,cn=peercred,cn=external,cn=auth" manage by dn.exact="uid=kdc-service,${LDAP_LOCAL_OLC_SUFFIX}" read by dn.exact="uid=kadmin-service,${LDAP_LOCAL_OLC_SUFFIX}" write by * none
```

* Accessing a local `""` database. The `* read` rule for `dn.base=""` is safe and often standard practice. This information does not reveal any user data or its structure. It is used only to allow client applications to "learn" the server and learn how to communicate with it and where to find data. This allows anonymous reading of LDAP server metadata, such as:
* `namingContexts`: Provides information about available databases (e.g., `dc=docker,dc=openldap`).
* `supportedLDAPVersion`: LDAP protocol versions.
* `supportedSASLMechanisms`: Supported authentication mechanisms.
* `subschemasubentry`: The distinguished name of the schema subtree, which is crucial for schema management applications.

```ldif
olcAccess: to dn.base="" by dn.exact="gidNumber=0+uidNumber=0,cn=peercred,cn=external,cn=auth" manage by dn="${LDAP_LOCAL_ROOT_DN}" manage by dn="${LDAP_BASED_ROOT_DN}" manage by * read
```

* Access to the main database branch

```ldif
olcAccess: to dn.subtree="${LDAP_LOCAL_OLC_SUFFIX}" by dn.base="gidNumber=0+uidNumber=0,cn=peercred,cn=external,cn=auth" manage by dn="${LDAP_LOCAL_ROOT_DN}" manage by dn.children="ou=Admins,${LDAP_LOCAL_OLC_SUFFIX}" manage by dn="${LDAP_BASED_ROOT_DN}" manage by dn.children="ou=Admins,ou=local,${LDAP_BASED_OLC_SUFFIX}" manage by * read
```

* Access to the remaining elements `to *``   

```ldif
olcAccess: to * by dn.base="gidNumber=0+uidNumber=0,cn=peercred,cn=external,cn=auth" manage by dn="${LDAP_LOCAL_ROOT_DN}" manage by dn.children="ou=Admins,${LDAP_LOCAL_OLC_SUFFIX}" manage by dn="${LDAP_BASED_ROOT_DN}" manage by dn.children="ou=Admins,ou=local,${LDAP_BASED_OLC_SUFFIX}" manage by self read by self write by self auth ${LDAP_OLC_ACCESS}
``` 

Of course, these accesses can be modified using the `ldapmodify` tool and the appropriate LDIF script:

```ldif
#########
# Create a file named 'modify_meta_acl_6.ldif' in the /opt/workspace directory in the container.
# Check the index {4}, it may have a different value in your case.
# Example - adapt to your needs!
#########
dn: olcDatabase={4}meta,cn=config
changetype: modify
add: olcAccess
olcAccess: {0}to attrs=userPassword,shadowLastChange by self write by anonymous auth by * none
olcAccess: {1}to attrs=memberOf,member,uniqueMember by self read by * read
olcAccess: {2}to dn.subtree="ou=Admins,ou=local,dc=scisoftware,dc=pl" by users read by anonymous auth by * none
olcAccess: {3}to * by self write by users read by anonymous auth by * none
```

Log in to the container console and issue the following command line command in the container:

```bash
ldapmodify -Y EXTERNAL -H ldapi:/// -f /opt/workspace/modify_meta_acl_6.ldif
```

### 4.2. Authentication Types

The OpenLDAP proxy supports various authentication methods:

- **Simple Bind**: Authentication via username (DN) and password. Used for testing and many applications.
- *(Optional: GSSAPI/Kerberos, DIGEST-MD5, if configured.)*

## 5. Search and Test Examples

Once your container is configured, you can use the following sample `ldapsearch` queries to verify that all features are working correctly. Be sure to replace the login credentials and DN values with those from your configuration.

#### Test 1: Search with AD Account Authentication

This test verifies that an Active Directory administrator account can authenticate through the proxy and search for a user.

```bash
# Authenticate as an AD administrator
ldapsearch -x -D "cn=Administrator,ou=pluton,dc=scisoftware,dc=pl" -W \
           -b "ou=pluton,dc=scisoftware,dc=pl" "cn=Administrator" uid userPrincipalName cn
```

**Expected result:** The server should return the Administrator account details.

-----

#### Test 2: Searching by `uid` and Retrieving Binary Attributes

Verifies that the proxy correctly maps `uid` and returns binary attributes (`objectGUID`). Note that `objectGUID` will be returned in encrypted/unreadable form, as it is a binary attribute.

```bash
# Searching for a user in AD by `uid`
ldapsearch -x -D "uid=ldapui,ou=Admins,ou=local,dc=scisoftware,dc=pl" -W \
           -b "dc=scisoftware,dc=pl" "(uid=slawas)" cn objectGUID
```

**Expected result:** Returned `cn` and `objectGUID` attributes for user `slawas`. The `objectGUID` value will be unreadable by client tools.

-----

#### Test 3: Searching from a local account and retrieving the `entryuuid`

This test checks whether the account in the local OpenLDAP database (`manager`) can search for a user in Active Directory and retrieve the `entryuuid` attribute (which maps to the `objectGUID` from AD).

```bash
# Searching from a local account
ldapsearch -x -D "cn=manager,ou=local,dc=scisoftware,dc=pl" -W \
           -b "dc=scisoftware,dc=pl" "(uid=slawas)" cn uid entryuuid
```

**Expected result:** The `cn`, `uid`, and `entryuuid` attributes for the `slawas` user are returned. The `entryuuid` value will be identical to the unreadable `objectGUID` value from the previous test.

-----

#### Test 4: Searching the subtree and checking `objectClass`

This test verifies that the entire subtree can be searched (`-s sub`) and that `objectClass` is mapped correctly.

```bash
# Searching all objects
ldapsearch -x -D "cn=manager,ou=local,dc=scisoftware,dc=pl" -W \
           -b "dc=scisoftware,dc=pl" -s sub "(objectClass=*)" cn uid
```

**Expected result:** All entries matching the condition, with the `cn` and `uid` attributes, will be returned.

## 6. Monitoring and Troubleshooting

### 6.1. OpenLDAP Logs

* **Location:** `slapd` logs are typically available via `journalctl -u slapd -f` (on systems with systemd) or in system files (e.g., `/var/log/syslog`, `/var/log/daemon.log`).
  * **Log Levels (`olcLogLevel`):**
  * `none`: No logs (not recommended).
  * `stats`: Basic statistics (recommended in production).
  * `acl`: ACL decision logging (useful for debugging permissions).
  * `args`: LDAP function arguments.
  * `conn`: Open/close connections.
  * `any` (`65535`): Everything (only for deep diagnostics, very "verbose").

### 6.2. Common Problems and Solutions

* **"Invalid GUID" in Apache Directory Studio:** A visual issue specific to Studio when connecting through a proxy. The value is correct in `ldapsearch`. Solution: Loading the AD schemas (`microsoftad.ldif`) and trying `rwm-rewriteRule` rules (although the latter didn't always help with Studio).

* **Authorization Errors:** Check `olcAccess` in `cn=config` and `slapd` logs (`olcLogLevel: acl`).

* **Backend Connection Problems:** Check `olcDbURI`, `olcDbBindDN`, `olcDbBindPW` in the `olcMetaSub` configuration, and the availability of the target server (firewall, network).

### 6.3. Diagnostic Tools

* `ldapsearch`: For querying and verifying data.
* `ldapmodify`, `ldapadd`, `ldapdelete`: For modifying configuration and data.

### 6.4. Troubleshooting

If you encounter errors or unexpected behavior, the following tips will help diagnose the problem.

#### 6.4.1. Authentication doesn't work or users are invisible

* **Check AD server connection**: Make sure the OpenLDAP proxy can connect to the Active Directory domain controller. Verify that port 389 (or 636 for LDAPS) is open.
* **Verify administrator DN**: Verify that the `olcDbBindDN` and `olcDbBindPW` in the `01-setup-meta-backend.ldif` file are correct. Note that the AD administrator account must have read permissions for the entire directory. 
* **`olcDbMap` Validity**: Ensure that the `uid` <-> `sAMAccountName` mapping in the `06-add-all-dbmap-for-ad-proxy.ldif` file is valid. This mapping is crucial for authentication on most Linux/UNIX systems.

#### 6.4.2. Problems with binary attributes (e.g., `objectGUID`, `objectSid`)

* **Binary vs. string**: Attribute values such as **`objectGUID`** and **`objectSid`** are binary data in Active Directory. The `slapo-rwm` module in OpenLDAP cannot convert them to readable strings (e.g. UUID or Base64).
* **Base64 Expectation**: If you use tools like `ldapsearch` without the appropriate flags, binary attributes may be returned as garbled characters or with an error. These tools often expect binary data to be Base64 encoded.
* **Error `handler exited with 1`**: This error occurs when `slapo-rwm` attempts to perform an operation (e.g. `md5()` or `suffix=`) on binary data that it cannot process. This means that it is not possible to map `objectGUID` to a readable string directly in the proxy configuration. **Solution**: Accept the binary nature of these attributes. Your client application must fetch this data and convert it to a UUID string itself. In `ldapsearch`, you can use the `base64` option in the command to explicitly request value encoding.

#### 6.4.3. Repository Configuration Issues in IBM WebSphere

* **Federated Repository Configuration**: When adding a federated repository, specifying the root tree DN as the "Unique distinguished name of the base (or parent) entry in federated repositories" e.g. the value `dc=scisoftware,dc=pl` (container parameter `LDAP_BASED_OLC_SUFFIX`) may result in the error message: **Error CWWIM5018E The distinguished name [dc=scisoftware,dc=pl] of the base entry in the repository is invalid. Root cause: [LDAP: error code 32 - Unable to select valid candidates].**
* **Solution**: We'll solve the problem by first adding a repository pointing to the tree of one of the proxy connections, e.g. `ou=pluton,dc=scisoftware,dc=pl`, and then editing the `wimconfig.xml` configuration file located in the deployment environment's configuration directory (e.g., the `DmgrProfile` profile). Example file path and location: `/opt/IBM/BAW/20.0.0.1/profiles/DmgrProfile/config/cells/PCCell1/wim/config/wimconfig.xml`. When changing this, search for the just-configured value `ou=pluton,dc=scisoftware,dc=pl` and replace it with `dc=scisoftware,dc=pl`. Steps to follow:
  * After adding the federated repository via the web console, **stop** the WebSphere servers. 
  * Edit the `wimconfig.xml` file located in the deployment environment's configuration directory, for example, using the `vim` application with the command `vim /opt/IBM/BAW/20.0.0.1/profiles/DmgrProfile/config/cells/PCCell1/wim/config/wimconfig.xml`:
    * Find and **replace** `<config:baseEntries name="ou=pluton,dc=scisoftware,dc=pl" nameInRepository="ou=pluton,dc=scisoftware,dc=pl"/>` with `<config:baseEntries name="dc=scisoftware,dc=pl" nameInRepository="dc=scisoftware,dc=pl"/>`
    * Find and **replace** `<config:participatingBaseEntries name="ou=pluton,dc=scisoftware,dc=pl"/>` to `<config:participatingBaseEntries name="ou=pluton,dc=scisoftware,dc=pl"/>`
  * **Start** the WebSphere server environment. 
  
After starting, we can verify in the WebSphere console whether users from each connected repository are visible. Go to **Users and Groups > Manage Users** and using the serach form we can test searching user data:

*User `scichy` found in the remote **OpenLDAP*** database:
![Successful search for user from local database](https://raw.githubusercontent.com/slawascichy/docker-openldap-proxy/refs/heads/main/doc/websphere_ibpm_proxy_to_repository_openldap.png)

*User `slawas` found in the remote **AD*** database:
![Successful search for user from local database data](https://raw.githubusercontent.com/slawascichy/docker-openldap-proxy/refs/heads/main/doc/websphere_pluton_proxy_to_repository_ad.png)

*User `mrcmanager` found in local database `mdb`*:
![Local database user search success](https://raw.githubusercontent.com/slawascichy/docker-openldap-proxy/refs/heads/main/doc/websphere_local_proxy_to_repository_mdb.png)

#### 6.4.4. Errors while starting the container

* **Checking the logs**: The most important troubleshooting tool is the container logs. Use `docker-compose logs openldap-proxy` (or `docker logs <container_id>`) to see messages from the `slapd` server.
* **LDIF syntax errors**: Any errors in the LDIF files (e.g., invalid spaces, missing `add:`) will cause the container to fail to start correctly. Check the logs for parsing error messages.
* **Permission issues**: Ensure that the configuration files are accessible to the user running the Docker container.

### 6.5. Restart/Reload Procedures

* **Restart the slapd service:** `systemctl restart slapd` (recommended after major configuration changes).

## 7. Backup and Restore

### 7.1. Backup Procedures

* **Configuration of `cn=config`:**

```bash
mkdir -p /var/backups/openldap_config_$(date +%Y%m%d%H%M%S)
ldapsearch -x -H ldapi:/// -b "cn=config" -LLL > /var/backups/openldap_config_$(date +%Y%m%d%H%M%S)/cn_config_backup.ldif
```

* **Local `mdb` database (if using):**

```bash
/usr/sbin/slapcat -l /var/backups/openldap_mdb_$(date +%Y%m%d%H%M%S)/mdb_backup.ldif -b "dc=scisoftware,dc=pl"
```
*(Adjust the DN database to your `mdb` configuration.)*

### 7.2. Restoration Procedures

*(If necessary, description of the steps for restoring from LDIF files, e.g., `slapadd` for the MDB database, `ldapadd` for `cn=config` after a fresh install.)*

## 8. Sources

* [Use LDAP Proxy to integrate multiple LDAP servers](https://docs.microfocus.com/doc/425/9.80/configureldapproxy)
* [OpenLDAP meta backend OLC configuration](https://serverfault.com/questions/866542/openldap-meta-backend-olc-configuration)
* [OpenLDAP Online Configuration Reference Mapping](https://tylersguides.com/guides/openldap-online-configuration-reference/)
* [Combining OpenLDAP and Active Directory via OpenLDAP meta backend](https://serverfault.com/questions/1152227/combining-openldap-and-active-directory-via-openldap-meta-backend/1190129?noredirect=1#comment1542537_1190129)
* Answers provided by Gemini (Google), 2025


