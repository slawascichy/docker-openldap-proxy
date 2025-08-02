# OpenLDAP with proxy

OpenLDAP Software is an Open Source suite of directory software developed by the Internet community, is a implementation of the Lightweight Directory Access Protocol (LDAP).
You can read about that product on page [https://www.openldap.org/](https://www.openldap.org/).

# Dokumentacja OpenLDAP Proxy

Niniejszy dokument stanowi kompleksowy przewodnik po konfiguracji i utrzymaniu serwera OpenLDAP działającego w trybie proxy (back-meta), integrującego się z usługami katalogowymi Active Directory, lokalną bazą MDB oraz innymi źródłami LDAP.

---

## 1. Przegląd rozwiązania i architektura

### 1.1. Cel projektu
Projekt serwera OpenLDAP w trybie proxy ma na celu unifikację dostępu do różnych źródeł danych LDAP (takich jak Active Directory, lokalna baza MDB, inne serwery LDAP-S) dla aplikacji klienckich. Pozwala to na centralizację uwierzytelniania i autoryzacji oraz prezentację spójnego widoku katalogu, niezależnie od jego wewnętrznej struktury.

### 1.2. Diagram architektury
*(Tutaj można wstawić prosty diagram, np. ASCII Art lub opis tekstowy, pokazujący OpenLDAP Proxy w centrum, łączące się z: AD, Lokalną bazą MDB, Innymi LDAP-ami, a do OpenLDAP Proxy łączą się Aplikacje klienckie.)*

### 1.3. Wersje oprogramowania
* **OpenLDAP:** [Twoja wersja, np. 2.4.59]
* **System operacyjny kontenera:** [Np. Debian 11 Bullseye]
* **Kontrolery domeny AD:** [Np. Windows Server 2016]
* **Narzędzia:** [Np. Apache Directory Studio, ldapsearch, ldapmodify]

---

## 2. Konfiguracja OpenLDAP Proxy (`cn=config`)

### 2.1. Kroki instalacji
*(Krótki opis kroków instalacji OpenLDAP, np. użycie `apt-get install slapd ldap-utils` w przypadku Debiana, inicjalizacja konfiguracji `cn=config`.)*

### 2.2. Pliki LDIF użyte do konfiguracji
Poniżej znajduje się lista kluczowych plików LDIF użytych do konfiguracji serwera proxy. Każdy plik powinien zawierać wewnętrzne komentarze opisujące jego przeznaczenie.

* `01-setup-base-meta.ldif` - Definicja bazy `meta`.
* `02-add-local-mdb-sub.ldif` - Dodanie podbazy dla lokalnego MDB (`olcMetaSub: {0}local`).
* `03-add-ad-proxy-sub.ldif` - Dodanie podbazy dla Active Directory (`olcMetaSub: {1}pluton`).
* `04-add-ldaps-proxy-sub.ldif` - Dodanie podbazy dla innego serwera LDAP-S (`olcMetaSub: {2}ibpm`).
* `05-enable-rwm-overlay.ldif` - Włączenie nakładki `rwm` (rewrite/referral/map).
* `06-add-schemas.ldif` - Ładowanie dodatkowych schematów (np. `microsoftad.ldif` dla atrybutów AD).
* `07-configure-ssl-tls.ldif` - Konfiguracja SSL/TLS dla OpenLDAP.
* `08-add-dbmap-attributes.ldif` - Mapowanie nazw atrybutów z backendów na nazwy widziane przez klienta OpenLDAP.
* `09-add-dbmap-reverse.ldif` - Konfiguracja mapowań rewersyjnych do zapisu zmian z powrotem do backendów.
* `10-configure-acl.ldif` - Definicje list kontroli dostępu (ACL).

### 2.3. Ważne atrybuty konfiguracyjne
* `olcSuffix`: `dc=scisoftware,dc=pl`
* `olcRootDN`: `cn=Admin,dc=scisoftware,dc=pl`
* `olcRootPW`: [Hasło ROOT DN - tutaj nie umieszczać jawnego hasła]
* **Dla `olcMetaSub` (np. `{1}pluton` dla AD):**
    * `olcDbURI`: `ldap://pluton.hgdb.org` (lub lista kontrolerów domeny)
    * `olcDbChaseReferrals`: `TRUE` (ważne dla podążania za referencjami w AD)
    * `olcDbConnectionTimeLimit`: [Wartość, np. `-1`]
    * `olcDbIdleTimeLimit`: [Wartość, np. `60`]
    * `olcDbBindTimeLimit`: [Wartość, np. `10`]

### 2.4. Konfiguracja SSL/TLS
* **Pliki certyfikatów:**
    * `olcTLSCertificateFile`: `/etc/ldap/ssl/server_cert.pem`
    * `olcTLSCertificateKeyFile`: `/etc/ldap/ssl/server_key.pem`
    * `olcTLSCACertificateFile`: `/etc/ldap/ssl/ca_certs.pem`
* **Wymagane TLS:** `olcTLSVerifyClient: demand` (lub `allow`, `never` w zależności od wymagań)
* **Wersje protokołów:** `olcTLSProtocolMin: 3.2`

---

## 3. Mapowanie atrybutów i klas obiektów (`olcDbMap`)

Mapowanie atrybutów odbywa się za pomocą atrybutu `olcDbMap` w konfiguracji każdej podbazy `olcMetaSub`.

### 3.1. Tabela mapowań (przykład)
| Nazwa w OpenLDAP (klient) | Nazwa w źródle (AD/Lokalny) | Kierunek (Forward/Reverse) | Uwagi |
| :----------------------- | :--------------------------- | :-------------------------- | :---- |
| `uid`                    | `userPrincipalName`          | Forward / Reverse           | Mapowanie UID z UPN           |
| `cn`                     | `cn`                         | Forward / Reverse           | Standardowe mapowanie         |
| `givenName`              | `givenName`                  | Forward / Reverse           |                               |
| `sn`                     | `sn`                         | Forward / Reverse           |                               |
| `displayName`            | `displayName`                | Forward / Reverse           |                               |
| `mail`                   | `mail`                       | Forward / Reverse           |                               |
| `jpegPhoto`              | `thumbnailPhoto`             | Forward                     | Mapowanie miniatury AD na standardowe zdjęcie LDAP |
| `objectGUID`             | `objectGUID`                 | Forward                     | Wymaga schematu AD            |
| `objectSid`              | `objectSid`                  | Forward                     | Wymaga schematu AD            |
| `preferredLanguage`      | `preferredLanguage`          | Forward / Reverse           |                               |
| `objectclass: inetOrgPerson` | `objectclass: user`          | Forward / Reverse           | Mapowanie klas obiektów       |
| `objectclass: groupOfUniqueNames` | `objectclass: group`         | Forward / Reverse           | Mapowanie klas obiektów       |

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
dn: olcDatabase={3}meta,cn=config
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