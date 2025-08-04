# OpenLDAP Proxy

Niniejszy dokument stanowi kompleksowy przewodnik po konfiguracji i utrzymaniu serwera OpenLDAP działającego w trybie proxy (back-meta), integrującego się z usługami katalogowymi Active Directory, lokalną bazą MDB oraz innymi źródłami LDAP.

---

## O OpenLDAP

Oprogramowanie OpenLDAP to pakiet oprogramowania katalogowego o otwartym kodzie źródłowym, opracowany przez społeczność internetową, stanowiący implementację protokołu LDAP (Lightweight Directory Access Protocol). Więcej informacji na temat tego produktu można znaleźć na stronie [https://www.openldap.org/](https://www.openldap.org/).

---

## 1. Przegląd rozwiązania i architektura

### 1.1. Cel projektu

Projekt serwera OpenLDAP w trybie proxy ma na celu unifikację dostępu do różnych źródeł danych LDAP (takich jak Active Directory, lokalna baza MDB, inne serwery LDAP-S) dla aplikacji klienckich. Pozwala to na centralizację uwierzytelniania i autoryzacji oraz prezentację spójnego widoku katalogu, niezależnie od jego wewnętrznej struktury.

### 1.2. Diagram architektury

![Diagram architektury proponowanego użycia](https://raw.githubusercontent.com/slawascichy/docker-openldap-proxy/refs/heads/main/doc/docker-openldap-proxy-diagram-pl.png)

### 1.3. Wersje oprogramowania

* **OpenLDAP:** OpenLDAP: slapd 2.6.7+dfsg-1~exp1ubuntu8.2 (Dec 9 2024 02:50:18) Ubuntu Developers
* **System operacyjny kontenera:** ubuntu:latest `org.opencontainers.image.version=24.04`
* **Kontrolery domeny AD:** Windows Server 2016
* **Narzędzia:** [Apache Directory Studio](https://directory.apache.org/studio/), `ldapsearch`, `ldapadd`, `ldapmodify`, `ping`, `telnet`

---

## 2. Uruchomienie serwera OpenLDAP Proxy

Kontener `openldap-proxy` z serwerem OpenLDAP uruchamiamy za jako kompozycja Docker, której definicja znajduje się w pliku `docker-compose.yml` albo bezpośrednio z linii komend. Poniżej przykłady poleceń z linii komend:

* Przykładowe uruchomienie kontenera jako kompozycja:

```bash
docker compose -f docker-compose.yml --env-file ldap-conf.env up -d
```

* Przykładowe uruchomienie kontenera bez kompozycji (Linux):

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

* Przykładowe uruchomienie kontenera bez kompozycji (Windows Cmd):

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

### 2.1. Kroki instalacji

#### 2.1.1 Przygotuj plik z konfiguracją kompozycji Docker

Utwórz swoją własną konfigurację kompozycji Docker. Skopiuj zawarty w projekcie przykładowy plik `ldap-conf.env` do pliku o twojej nazwie np. `my-ldap-conf.env`. Plik konfiguracyjny zawiera następujące parametry:

| Nazwa parametru | Opis |
| :---- | :---- |
| LDAP_ORG_DC | Nazwa, akronim organizacji. Przykładowa wartość: `scisoftware`. |
| LDAP_LOCAL_OLC_SUFFIX | DN (Distinguished Name) domeny lokalnej bazy MDB, w której przechowywani będą loklani użytkownicy, grupy; pierwsza wartość atrybutu `dc` musi się nazywać tak jak wcześniej zdefiniowana nazwa organizacji w parametrze `${LDAP_ORG_DC}`. Przykładowo: `dc=scisoftware,dc=local`. |
| LDAP_BASED_OLC_SUFFIX | DN (Distinguished Name) domeny bazowej serwera OpenLDAP. Do tej domeny będą przypinane poszczególne repozytoria zewnętrzne (proxy). Wartość przykładowa to `dc=scisoftware,dc=pl`. Do tej domeny automatycznie (podczas inicjalizacji bazy proxy) zostanie również podpieta lokalna baza MDB pod nazwą drzewa `ou=local,${LDAP_BASED_OLC_SUFFIX}` np. `ou=local,dc=scisoftware,dc=pl`. |
| LDAP_ROOT_CN | Nazw użytkownika z uprawnieniami superuser'a. Przykładowo `manager`.|
| LDAP_ROOT_PASSWD_PLAINTEXT |  Hasło użytkownika z uprawnieniami superuser'a. Hasło rozkodowane. Podczas inicjalizacji zostanie zakodowane i umieszczone w odpowiednim entry użytkownika. Przykładowo `secret`. |
| LDAP_OLC_ACCESS | Końcowa konfiguracja roli praw dostępu `olcAccess: to *`. Wartość domyślna to `"by * none"`. O tym jak są predefiniowane prawa do baz danych zostanie opisane w dalszej części dokumentu, jednakże niektóre z oprogramowań wymaga wartości `"by * read"` np. konfiguracja Kerberos, [ldap-ui](https://github.com/dnknth/ldap-ui). |
| SERVER_DEBUG | Poziom logowania zdarzeń. Parametr przydatny podczas analizy problemów, na które możemy się natknąć podczas budowania własnych rozwiązań wykorzystujących niniejszy obraz OpenLDAP proxy. Wartość domyślna to `32`. |
| LDAP_TECHNICAL_USER_CN | (opcjonalne) Nazwa predefiniowanego użytkownika technicznego, za pośrednictwem, którego będziemy się komunikować w celu uzyskania dostępu do danych serwera OpenLDAP. Wartość domyślna to `frontendadmin`.|
| LDAP_TECHNICAL_USER_PASSWD | (opcjonalne) Hasło użytkownika technicznego. Hasło rozkodowane. Wartość domyślna to `secret`. |
| PHPLDAPADMIN_HTTPS | (opcjonalne) Parametr konfiguracji potrzebny gdy uruchamiasz kompozycję wraz z aplikacją UI [osixia/phpldapadmin](https://github.com/osixia/docker-phpLDAPadmin). Definiuje czy aplikacja ma być uruchomiona z protokołem HTTPS. Wartość domyślna to `true`. |
| PHPLDAPADMIN_HTTPS_CRT_FILENAME | (opcjonalne) Parametr konfiguracji potrzebny gdy uruchamiasz kompozycję wraz z aplikacją UI [osixia/phpldapadmin](https://github.com/osixia/docker-phpLDAPadmin). Definiuje nazwę pliku z certyfikatem SSL serwera. Wartość domyślna to `server-cert-chain.crt`. |
| PHPLDAPADMIN_HTTPS_KEY_FILENAME | (opcjonalne) Parametr konfiguracji potrzebny gdy uruchamiasz kompozycję wraz z aplikacją UI [osixia/phpldapadmin](https://github.com/osixia/docker-phpLDAPadmin). Definiuje nazwę pliku z kluczem prywatnym serwera. Wartość domyślna to `server-cert.key`. |
| PHPLDAPADMIN_HTTPS_CA_CRT_FILENAME | (opcjonalne) Parametr konfiguracji potrzebny gdy uruchamiasz kompozycję wraz z aplikacją UI [osixia/phpldapadmin](https://github.com/osixia/docker-phpLDAPadmin). Definiuje nazwę pliku z CA organizacji, która podpisała certyfikat SSL serwera. Wartość domyślna to `scisoftware_intermediate_ca.crt`. |

#### 2.1.2 Przygotuj wolumeny dla danych bazy proxy

Uruchomienie kontenera wymaga `openldap-proxy` minimum 4 wolumenów, w których przechowuje konfiguracje oraz pliki bazy danych. Gdy przejrzysz sobie plik `docker-compose.yml` zauważysz, że kompozycja ma predefiniowane lokalizacje wolumenów w katalogu lokalnym maszyny, na której kontener jest uruchamiany.

Poniżej lista wykorzystywanych przez kontener `openldap-proxy` wolumenów:

| Nazwa wolumenu  | Opis       |
| :---- | :---- |
| `openldap` | Wolumen główny, w którym przechowywane są dane lokalnych baz danych MDB. Lokalizacja domyślna to lokalny katalog `/d/mercury/openldap-proxy`. Wolumen podłączony jest do ścieżki `/var/lib/ldap` na kontenerze. |
| `slapd-d` | Wolumen z konfiguracją instancji OpenLDAP proxy `(cn=config)`. Lokalizacja domyślna to lokalny katalog `/d/mercury/slapd.d-proxy`. Wolumen podłączony jest do ścieżki `/etc/ldap/slapd.d` na kontenerze. |
| `ca-certificates` | Wolumen z certyfikatami potwierdzającymi tożsamość podłączanych serwerów zewnętrznych, których komunikacja wykorzystuje SSL (protokół `ldaps`). Konfiguracja komunikacji SSL zawarta jest w pliku `/etc/ldap/ldap.conf` na kontenerze. We wskazanym, lokalnym katalogu umieść i umieszczaj w przyszłości certyfikaty zaufanych organizacji i serwerów LDAP. Lokalizacja domyślna to lokalny katalog `/d/mercury/openldap-cacerts`. Wolumen podłączony jest do ścieżki `/usr/local/share/ca-certificate` na kontenerze. |
| `lapd-workspace` | (opcjonalnie) wolumen z różnym skryptami potrzebnymi do analizy problemów, czy tez może dostosowania parametrów baz danych w kontenerze wykorzystującym niniejszy obraz. Lokalizacja domyślna to lokalny katalog `/d/workspace/git/docker-openldap-proxy/workspace`. Wolumen podłączony jest do ścieżki `/opt/workspace` na kontenerze. |

Poniżej fragment definicji kompozycji:

```yml
    volumes: 
      - openldap:/var/lib/ldap:rw
      - slapd-d:/etc/ldap/slapd.d:rw
      - ca-certificates:/usr/local/share/ca-certificate:rw
      - lapd-workspace:/opt/workspace:rw
```

### 2.2. Automatyczne tworzenie instancji OpenLDAP

Po uruchomieniu kontenera, skrypt startujący podejmie próbę utworzenia bazy danych i uruchomienia instancji serwera OpenLDAP.
Próba utworzenia bazy danych jest podejmowana na podstawie warunku istnienia pliku `ldap.init` w katalogu `/var/lib/ldap` na kontenerze. Ten katalog jest mapowany na wolumen o nazwie `openldap`.

> [!TIP] 
> Jeżeli chcesz by baza danych OpenLDAP została zbudowana od nowa to wystarczy usunąć plik `ldap.init`.

> [!CAUTION] 
> Jeżeli usuniesz plik `ldap.init` utracisz wszystkie dotychczasowe dane.

### 2.3. Dodawanie proxy do zewnętrznej bazy

Dodawanie kolejnej bazy zewnętrznej odbywa się już po uruchomieniu kontenera. Uruchamiamy ręcznie skrypt `add-proxy-to-external-ldap.sh`, który znajdziesz w katalogu `/opt/service` na kontenerze.
Aby uruchomić skrypt zaloguj się do konsoli uruchomionego kontenera wydając polecenia w linii komend:

```bash
export CONTAINER_ID=`docker container ls | grep "<nazwa_kontenera>" | awk '{print $1}'`
docker exec -it ${CONTAINER_ID} bash
```

* gdzie `<nazwa_kontenera>` to nazwa kontenera pod jaką został uruchomiona usługa OpenLDAP np. `openldap-proxy`

Przykład:

```bash
export CONTAINER_ID=`docker container ls | grep "openldap-proxy" | awk '{print $1}'`
docker exec -it ${CONTAINER_ID} bash
```

Po zalogowaniu się do konsoli kontenera uruchamiamy skrypt `add-proxy-to-external-ldap.sh` z odpowiednimi parametrami wejściowymi. Poniżej opis wymaganych parametrów:

| Nazwa parametru | Opis |
| :---- | :---- |
| `BIND_LDAP_URI=<value>` | Adres URL wskazujący na zewnętrzną instancję LDAP, np. `<ldap|ldaps>://example.com`. |
| `BIND_DN=<value>` | Nazwa wyróżniająca użytkownika, przez którą będzie realizowana komunikacja. |
| `BIND_PASSWD_PLAINTEXT=<value>` | Hasło użytkownika, przez które będzie realizowana komunikacja. |
| `BIND_BASE_CTX_SEARCH=<value>` | Główna gałąź wyszukiwania podłączanej instancji LDAP (base context, kontekst bazowy). | 
| `LDAP_PROXY_OU_NAME=<value>` | Nazwa jednostki organizacyjnej, w której powinno pojawić się połączone drzewo LDAP. | 

Opcjonalnie można użyć parametrów jednej z opcji:

| Nazwa opcji | Opis |
| :---- | :---- |
| `--help` | Prezentacja danych pomocy dla uruchomienia skryptu. |
| `--test` | Testowanie poprawności polecenia. |
| `--addADAttributesMapping` | dodaje mapowanie nazw atrybutów z zewnętrznej usługi Active Directory do lokalnego OpenLDAP. |

Wszystkie powyższe informacje można uzyskać wydając polecenie:

```bash
./add-proxy-to-external-ldap.sh --help
```

> [!IMPORTANT]
> Zanim wydasz komendę dodania bazy wpierw przetestuj czy definicja połączenia do niej jest poprawna. Użyj opcji `--test` podczas pierwszego uruchomienia skryptu.

> [!IMPORTANT]
> Definiując połączenia do AD używaj opcji `--addADAttributesMapping`. Jeżeli zapomnisz, to się nie martw. Zawsze możesz później uruchomić skrypt `./add-mapping-of-attribute-names-AD-to-OpenLDAP.sh <nazwa_jednostki_organizacyjnej>`.

Przykład 1:

```bash Testowanie połączenia do AD o nazwie "pluton"
./add-proxy-to-external-ldap.sh \
  BIND_LDAP_URI=ldap://pluton.example.com \
  BIND_DN=CN="proxyadmin,OU=ServiceAccounts,DC=example,DC=local"\
  BIND_PASSWD_PLAINTEXT="secret" \
  BIND_BASE_CTX_SEARCH=CN=Users,DC=example,DC=local \
  LDAP_PROXY_OU_NAME=pluton --addADAttributesMapping --test 
```
* dodanie połączenia nastąpi po uruchomieniu powyższego polecenia bez opcji `--test`.

Przykład 2:

```bash Testowanie połączenia do OpenLDAP o nazwie "ibpm"
./add-proxy-to-external-ldap.sh \
  BIND_LDAP_URI=ldaps://192.168.1.123:9636 \
  BIND_DN=cn=GIToperator,ou=technical,dc=ibpm,dc=example \
  BIND_PASSWD_PLAINTEXT=secret \
  BIND_BASE_CTX_SEARCH=ou=ibpm.pro,dc=ibpm,dc=example \
  LDAP_PROXY_OU_NAME=ibpm --test
```
* dodanie połączenia nastąpi po uruchomieniu powyższego polecenia bez opcji `--test`.

### 2.4. Pliki LDIF użyte do konfiguracji

Poniżej znajduje się lista kluczowych plików LDIF użytych do konfiguracji serwera proxy. Pliki te znajdują się w katalogu `init` projektu i są umieszczane w lokalizacji `/opt/init` na kontenerze.

* `01-slapd.conf` - Podstawowa konfiguracja instancji baz danych OpenLDAP zawierająca definicje `(cn=config)` oraz `(cn=monitor)`. Zawiera również listę załadowanych schematów (definicji atrybutów i klas przechowywanych w bazach obiektów).
* `02-mdbdatabase-create.ldif` - Definicja lokalnej bazy `mdb` do przechowywania danych lokalnych użytkowników. Baza, której DN został zdefiniowany w zmiennej `${LDAP_LOCAL_OLC_SUFFIX}` np. `dc=scisoftware,dc=local`.
* `03-metadatabase-create.ldif` - Definicja lokalnej bazy `mdb` podrzędnej (z polem `olcSubordinate: TRUE`). Baza, której DN został zdefiniowany jako `dc=subordinate,${LDAP_BASED_OLC_SUFFIX}` np. `dc=subordinate,dc=scisoftware,dc=pl`. W praktyce nie korzystamy z tej bazy, jednak niejawnie pozwala ona na poruszanie się po drzewie głównym utworzonej bazy `meta` z DN zdefiniowanym w zmiennej `${LDAP_LOCAL_OLC_SUFFIX}` np. `dc=scisoftware,dc=pl`. Dzięki takiej konfiguracji podłączane w przyszłości bazy będą widoczne jako jej poddrzewa, ich dane będą przetwarzane przy definicji `baseDN=${LDAP_LOCAL_OLC_SUFFIX}` np. `baseDN=dc=scisoftware,dc=pl` (zobacz artykuł [Combining OpenLDAP and Active Directory via OpenLDAP meta backend](https://serverfault.com/questions/1152227/combining-openldap-and-active-directory-via-openldap-meta-backend/1190129?noredirect=1#comment1542537_1190129)). Plik konfiguracji zawiera również konfigurację połączenia (proxy) z lokalną bazą `mdb` zdefiniowaną w pliku `02-mdbdatabase-create.ldif`. Podłączona lokalna baza danych będzie miała następującą wartość DN: `ou=local,${LDAP_BASED_OLC_SUFFIX}` np. `ou=local,dc=scisoftware,dc=pl`.
* `04-add-proxy-to-external-ldap.ldif` - Dodanie podbazy (proxy). Plik wykorzystywany przez skrypt dodawania/definiowania komunikacji z zewnętrzną bazą LDAP. Plik używany przez skrypt `add-proxy-to-external-ldap.sh` i wykorzystywany jako mechanizm dodawania kolejnej bazy zewnętrznej.
* `06-add-all-dbmap-for-ad-proxy.ldif` - Dodanie mapowania nazw atrybutów zewnętrznej bazy AD na lokalne nazwy atrybutów OpenLDAP. Plik używany przez skrypt `add-proxy-to-external-ldap.sh`, który wykorzystywany jest jako mechanizm dodawania kolejnej bazy zewnętrznej oraz `add-mapping-of-attribute-names-AD-to-OpenLDAP.sh`, który realizuje zadanie dodawania atrybutów do już istniejącego połączenia z zewnętrzną bazą LDAP.

### 2.5. Konfiguracja SSL/TLS

* **Pliki certyfikatów:**
  * `olcTLSCertificateFile`: `/usr/local/share/ca-certificate/server_cert.pem`
  * `olcTLSCertificateKeyFile`: `/usr/local/share/ca-certificate/server_key.pem`
  * `olcTLSCACertificateFile`: `/usr/local/share/ca-certificate/ca_certs.pem`
* **Wymagane TLS:** `olcTLSVerifyClient: demand` (lub `allow`, `never` w zależności od wymagań)
* **Wersje protokołów:** `olcTLSProtocolMin: 3.2`

### 2.6. Niestandardowe schematy atrybutów

> [!NOTE]
> W ramach dostosowania schematu `core` zmieniono definicję atrybutu `uniqueMember`. Oryginalnie jest on w.g RFC2256 definicją unikalnego członka grupy i jest typu "Nazwa lub unikalny UID" `1.3.6.1.4.1.1466.115.121.1.34 - Name and Optional UID syntax`. Jednakże typ ten nie jest tłumaczony z wartości zewnętrznej bazy danych na lokalny podczas działania proxy. Dlatego zmieniono jedgo definicje na `( 2.5.4.50 NAME 'uniqueMember' DESC 'RFC2256: unique member of a group' EQUALITY distinguishedNameMatch SUP distinguishedName )`.


#### 2.6.1. Schemat atrybutów CSZU

**CSZU** (polski skrót od Centralny System Zarządzania Użytkownikami) - to autorski system repozytorium użytkowników. Załadowana schema zawiera definicje klas obiektów o nazwach `cszuAttrs`, `cszuPrivs`, `cszuUser` and `cszuGroup`:

```text
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

#### 2.6.2. Schemat atrybutów AD

Schemat pozwalający na reprezentacje w ramach serwera OpenLDAP atrybutów o nazwach pochodzących AD. Zawiera definicje klas obiektów o nazwach `aDPerson`, `groupOfMembers`, `team`, `container`, `group` oraz `user`:

```text
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

### 2.7 Predefiniowane wpisy w lokalnej bazie

Podczas pierwszego uruchomienia usługi zawartość lokalnej bazy danych jest inicjowana przy użyciu predefiniowanych wpisów.

- Baza danych zawiera predefiniowane 4 jednostki organizacyjne (OU):
  - `ou=Groups,ou=local,${LDAP_BASED_OLC_SUFFIX}` - dla danych lokalnych grup, przykład: `ou=Groups,ou=local,dc=scisoftware,dc=pl`
  - `ou=People,ou=local,${LDAP_BASED_OLC_SUFFIX}` - dla danych lokalnych użytkowników
  - `ou=Technical,ou=local,${LDAP_BASED_OLC_SUFFIX}`` - dla danych lokalnych użytkowników technicznych; wpisy użytkownika z tej jednostki organizacyjnej mają uprawnienia do odczytu wszystkich wpisów; można ich używać w definicji połączenia dla systemów zewnętrznych.
  - `ou=Admins,${LDAP_BASED_OLC_SUFFIX}` -dla danych lokalnych użytkowników administracyjnych; wpisy użytkownika z tej jednostki organizacyjnej mają pełne uprawnienia do zarządzania danymi.

- Predefiniowane wpisy definiujące grupy użytkowników:
  - `cn=mrc-admin,ou=local,ou=Groups,${LDAP_BASED_OLC_SUFFIX}` - grupa użytkowników z uprawnieniami administratora, która wykorzystywana jest przez system [Mercury 3.0 (HgDB)](https:///hgdb.org).
  - `cn=mrc-user,ou=local,ou=Groups,${LDAP_BASED_OLC_SUFFIX}` - grupa użytkowników z uprawnieniami dostępu do danych , która wykorzystywana jest przez system [Mercury 3.0 (HgDB)](https:///hgdb.org).

- Predefiniowane wpisy definiujące użytkowników:
  - `${LDAP_ROOT_CN}`,ou=local,${LDAP_BASED_OLC_SUFFIX} - menedżer LDAP, użytkownik ma wszystkie uprawnienia do wszystkich wpisów; hasło użytkownika powinno być zdefiniowane w zmiennej środowiskowej `LDAP_ROOT_PASSWD_PLAINTEXT` (wartość domyślna: „secret”) i powinno być zmienione w środowiskach produkcyjnych. Przykład nazwy: `cn=manager,ou=local,dc=scisoftware,dc=pl`
  - `cn=ldapadmin,ou=Admins,ou=local,${LDAP_BASED_OLC_SUFFIX}` - administrator, użytkownik ma uprawnienia do zapisu do wszystkich wpisów; hasło użytkownika powinno być zdefiniowane w zmiennej środowiskowej `LDAP_TECHNICAL_USER_PASSWD` (wartość domyślna: „secret”) i powinno być zmienione w środowiskach produkcyjnych.
  - `uid=ldapui,ou=Admins,ou=local,${LDAP_BASED_OLC_SUFFIX}` - administrator, użytkownik ma uprawnienia do zapisu do wszystkich wpisów; hasło użytkownika powinno być zdefiniowane w zmiennej środowiskowej `LDAP_TECHNICAL_USER_PASSWD` (wartość domyślna: „secret”) i powinno zostać zmienione w środowiskach produkcyjnych. Wpis można wykorzystać do integracji z interfejsem użytkownika LDAP.
  - `cn=${LDAP_TECHNICAL_USER_CN},ou=Technical,ou=local,${LDAP_BASED_OLC_SUFFIX}` - użytkownik techniczny do definiiowania komunikacji z serwerem OpenLDAP, domyślna wartość `LDAP_TECHNICAL_USER_CN` to „frontendadmin”, wpis użytkownika ma uprawnienia do odczytu wszystkich wpisów; hasło użytkownika powinno być zdefiniowane w zmiennej środowiskowej `LDAP_TECHNICAL_USER_PASSWD` (wartość domyślna: „secret”) i powinno zostać zmienione w środowiskach produkcyjnych.
  - `uid=mrcmanager,ou=People,ou=local,${LDAP_BASED_OLC_SUFFIX}` - przykładowy użytkownik z uprawnieniami administratora systemu [Mercury 3.0 (HgDB)](https:///hgdb.org); hasło użytkownika powinno być zdefiniowane w zmiennej środowiskowej `LDAP_TECHNICAL_USER_PASSWD` (wartość domyślna: „secret”) i powinno zostać zmienione w środowiskach produkcyjnych.
  - `uid=mrcuser,ou=People,ou=local,${LDAP_BASED_OLC_SUFFIX}` - przykładowy użytkownik z uprawnieniami użytkownika systemu [Mercury 3.0 (HgDB)](https:///hgdb.org); hasło użytkownika należy zdefiniować w zmiennej środowiskowej `LDAP_TECHNICAL_USER_PASSWD` (wartość domyślna: „secret”) i zmienić w środowiskach produkcyjnych.

![Przykład predefiniowanego drzewa lokalnej bazy danych](https://raw.githubusercontent.com/slawascichy/docker-openldap-proxy/refs/heads/main/doc/sample-predefined-tree-by-apache-dir-studio.png)

---

## 3. Mapowanie atrybutów i klas obiektów (`olcDbMap`)

Mapowanie atrybutów odbywa się za pomocą atrybutu `olcDbMap` w konfiguracji każdej podbazy `olcMetaSub`.

### 3.1. Tabela predefiniowanych mapowań

Poniżej tabela predefiniowanych mapowań dla połączeń do baz danych AD. Tabela została opracowana na podstawie najczęściej stosowanych w różnych systemach IT. 

| Nazwa w OpenLDAP (klient) | Nazwa w źródle (AD) | Uwagi |
| :----------------------- | :--------------------------- | :---- |
| `uid`| `sAMAccountName` | Mapowanie UID z `sAMAccountName` nazwy użytkownika w AD. |
| `jpegPhoto` | `thumbnailPhoto | Mapowanie miniatury AD na standardowe zdjęcie LDAP |
| `cn` | `cn | Standardowe mapowanie |
| `givenName`| `givenName` | |
| `sn` | `sn` | |
| `displayName` | `displayName` | |
| `mail` | `mail` | |
| `objectGUID` | `objectGUID` | Wymaga schematu AD |
| `objectSid` | `objectSid` | Wymaga schematu AD |
| `preferredLanguage` | `preferredLanguage` | |
| `objectclass: inetOrgPerson` | `objectclass: user`      | Mapowanie klas obiektów |
| `objectclass: groupOfUniqueNames` | `objectclass: group` | Mapowanie klas obiektów |

### 3.2. Uzasadnienie mapowań
* `uid` <-> `userPrincipalName`: Umożliwia używanie atrybutu `uid` (popularnego w systemach UNIX/Linux) do autentykacji i identyfikacji, mapując go na unikalny `userPrincipalName` z AD.
* `jpegPhoto` <-> `thumbnailPhoto`: Konwertuje specyficzny dla AD atrybut miniatury na bardziej ogólny atrybut `jpegPhoto` używany w standardzie LDAP.

### 3.3. Obsługa GUID/SID
Atrybuty `objectGUID` i `objectSid` są atrybutami binarnymi specyficznymi dla Active Directory. Ich prawidłowa obsługa wymaga załadowania odpowiednich definicji schematu do OpenLDAP (`cn=microsoftad,cn=schema,cn=config`), pozyskanych z plików takich jak `microsoftad.ldif` lub `microsoftad.schema`.

---

## 4. Uwierzytelnianie i autoryzacja

### 4.1. Użytkownicy do bindowania (proxy do backendów)
* `olcDbBindDN`: Określa DN konta używanego przez OpenLDAP proxy do łączenia się z backendami.
    * Dla AD: `CN=Administrator,CN=Users,DC=BOJANO,DC=LOCAL` (lub dedykowane konto serwisowe z minimalnymi uprawnieniami).
    * Dla LDAP-S: `uid=admin,ou=system,dc=scisoftware,dc=pl` (przykładowo).

### 4.2. ACL (Access Control Lists) - `olcAccess`
Dokładna konfiguracja ACL jest kluczowa dla bezpieczeństwa. Przykładowe reguły:

```ldif
# Przykład - dostosować do własnych potrzeb!
dn: olcDatabase={4}meta,cn=config
changetype: modify
add: olcAccess
olcAccess: {0}to attrs=userPassword,shadowLastChange by self write by anonymous auth by * none
olcAccess: {1}to attrs=memberOf,member,uniqueMember by self read by * read
olcAccess: {2}to dn.subtree="ou=Admins,ou=local,dc=scisoftware,dc=pl" by users read by anonymous auth by * none
olcAccess: {3}to * by self write by users read by anonymous auth by * none
```
*(Szczegółowe wyjaśnienie każdej reguły ACL, kto może co robić i w jakim zakresie.)*

### 4.3. Rodzaje uwierzytelniania
OpenLDAP proxy obsługuje różne metody uwierzytelniania:

- **Simple Bind**: Uwierzytelnianie za pomocą nazwy użytkownika (DN) i hasła. Używane w testach i wielu aplikacjach.
- *(Opcjonalnie: GSSAPI/Kerberos, DIGEST-MD5, jeśli skonfigurowane.)*

---

## 5. Monitorowanie i rozwiązywanie problemów

### 5.1. Logi OpenLDAP
* **Lokalizacja:** Logi `slapd` są zazwyczaj dostępne poprzez `journalctl -u slapd -f` (na systemach z systemd) lub w plikach systemowych (np. `/var/log/syslog`, `/var/log/daemon.log`).
* **Poziomy logowania (`olcLogLevel`):**
    * `none`: Brak logów (niezalecane).
    * `stats`: Podstawowe statystyki (zalecane na produkcji).
    * `acl`: Logowanie decyzji ACL (przydatne do debugowania uprawnień).
    * `args`: Argumenty funkcji LDAP.
    * `conn`: Otwieranie/zamykanie połączeń.
    * `any` (`65535`): Wszystko (tylko do głębokiej diagnostyki, bardzo "gadatliwe").

### 5.2. Typowe problemy i rozwiązania
* **"Invalid GUID" w Apache Directory Studio:** Problem wizualny specyficzny dla Studio, gdy łączy się przez proxy. Wartość jest poprawna w `ldapsearch`. Rozwiązanie: Załadowanie schematów AD (`microsoftad.ldif`) oraz próba reguł `rwm-rewriteRule` (choć to drugie nie zawsze pomagało dla Studio).
* **Błędy autoryzacji:** Sprawdź `olcAccess` w `cn=config` i logi `slapd` (`olcLogLevel: acl`).
* **Problemy z połączeniem do backendu:** Sprawdź `olcDbURI`, `olcDbBindDN`, `olcDbBindPW` w konfiguracji `olcMetaSub` oraz dostępność serwera docelowego (firewall, sieć).

### 5.3. Narzędzia diagnostyczne
* `ldapsearch`: Do wykonywania zapytań i weryfikacji danych.
* `ldapmodify`, `ldapadd`, `ldapdelete`: Do modyfikacji konfiguracji i danych.
* `journalctl -u slapd -f`: Do monitorowania logów `slapd` w czasie rzeczywistym.

### 5.4. Procedury restartu/przeładowania
* **Restart usługi slapd:** `systemctl restart slapd` (zalecane po dużych zmianach konfiguracyjnych).

---

## 6. Kopia zapasowa i odtwarzanie

### 6.1. Procedury backupu
* **Konfiguracja `cn=config`:**
    ```bash
    mkdir -p /var/backups/openldap_config_$(date +%Y%m%d%H%M%S)
    ldapsearch -x -H ldapi:/// -b "cn=config" -LLL > /var/backups/openldap_config_$(date +%Y%m%d%H%M%S)/cn_config_backup.ldif
    ```
* **Lokalna baza MDB (jeśli używasz):**
    ```bash
    /usr/sbin/slapcat -l /var/backups/openldap_mdb_$(date +%Y%m%d%H%M%S)/mdb_backup.ldif -b "dc=scisoftware,dc=pl"
    ```
    *(Dostosuj bazę DN do swojej konfiguracji MDB.)*

### 6.2. Procedury odtwarzania
*(W razie potrzeby, opis kroków odtwarzania z plików LDIF, np. `slapadd` dla bazy MDB, `ldapadd` dla `cn=config` po świeżej instalacji.)*