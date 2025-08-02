# Workspace

## Transformacja nazw atrybutów

Jasne, pomogę z `olcDbMap` do mapowania atrybutów. To kluczowa funkcja w `back-meta` (proxy) OpenLDAP, która pozwala na tłumaczenie nazw atrybutów między Twoim proxy a zewnętrznym serwerem LDAP.

### Czym jest `olcDbMap`?

`olcDbMap` to atrybut konfiguracyjny używany w kontekście meta backendu (olcMetaSub lub bezpośrednio `olcDatabase={X}meta`). Służy do mapowania nazw atrybutów, DN-ów i DN-ów grup między Twoim serwerem proxy a zdalnym serwerem. Jest to szczególnie przydatne, gdy zdalny serwer używa innych nazw atrybutów niż te, których oczekujesz od klientów łączących się z Twoim proxy.

#### Jak działa mapowanie olcDbMap

Jak działa mapowanie olcDbMap dla `attribute <local_name> <remote_name>`? Postawmy sprawę jasno, raz na zawsze. W kontekście `back-meta` (czyli Twojego OpenLDAP proxy łączącego się z AD), mapowanie atrybutów działa zawsze w kierunku:

`olcDbMap: attribute <nazwa_atrybutu_jaką_widzi_klient_OpenLDAP> <nazwa_atrybutu_w_źródle_zdalnym_(AD)>`

- `<nazwa_atrybutu_jaką_widzi_klient_OpenLDAP>` (Lokalna nazwa): To jest nazwa, pod którą atrybut będzie dostępny w Twoim OpenLDAP. To jest to, czego oczekuje aplikacja kliencka.
- `<nazwa_atrybutu_w_źródle_zdalnym_(AD)>` (Zdalna nazwa): To jest oryginalna nazwa atrybutu w Active Directory (Pluton).

#### Poprawne mapowanie dla Twojego celu

Jeśli Twoim celem jest, aby atrybut `userPrincipalName` z AD był widoczny jako `uid` w OpenLDAP, to prawidłowe mapowanie to:

`olcDbMap: attribute uid userPrincipalName`

Wyjaśnienie:

- `uid` to nazwa, którą Ty i Twoje aplikacje będziecie widzieć w OpenLDAP.
- `userPrincipalName` to nazwa, którą OpenLDAP proxy będzie szukać w Active Directory.

### Przykład użycia `olcDbMap`

Tak, Twój przykład `olcDbMap: attribute uid sAMAccountName` jest prawidłowy i jest to typowe użycie.

`olcDbMap` przyjmuje różne typy dyrektyw do mapowania:

- `attribute <local_name> <remote_name>`: Mapuje atrybut. To jest najczęstsze zastosowanie.
- `objectclass <local_name> <remote_name>`: Mapuje klasy obiektów.
- `dn <internal_name> <remote_name>`: Mapuje nazwy wyróżniające (DN).
- `group <local_name> <remote_name>`: Mapuje DN-y grup.

### Twój przykład:

Jeśli chcesz mapować atrybut uid (używany przez Twoich lokalnych klientów) na sAMAccountName (używany przez zdalny serwer, np. Active Directory), użyjesz dokładnie takiej składni:

```ldif
# Przykład pliku LDIF do modyfikacji
# Plik: map_attributes.ldif
dn: olcMetaSub={1}ibpm,olcDatabase={3}meta,cn=config
changetype: modify
add: olcDbMap
olcDbMap: attribute uid sAMAccountName
```

### Jak to zastosować?

Przygotuj plik LDIF (np. `map_attributes.ldif`) z powyższą zawartością.

- Pamiętaj o poprawnym DN: `olcMetaSub={1}ibpm,olcDatabase={3}meta,cn=config`. Indeks `{3}` dla meta jest tu przykładowy, upewnij się, że używasz swojego indeksu bazy meta.
- Cała linia `olcDbMap: attribute uid sAMAccountName` musi być w jednej linii w pliku LDIF.

Zastosuj plik LDIF za pomocą `ldapmodify`:

```bash
ldapmodify -Y EXTERNAL -H ldapi:/// -f map_attributes.ldif
```

### Przykład z wieloma mapowaniami
Możesz mieć wiele mapowań w jednym wpisie `olcMetaSub`. Każde mapowanie będzie osobną wartością atrybutu `olcDbMap`.

```ldif
# Przykład pliku LDIF z wieloma mapowaniami
# Plik: map_multiple_attributes.ldif
dn: olcMetaSub={1}ibpm,olcDatabase={3}meta,cn=config
changetype: modify
add: olcDbMap
olcDbMap: attribute uid sAMAccountName
-
add: olcDbMap
olcDbMap: attribute mail emailAddress
-
add: olcDbMap
olcDbMap: objectclass groupOfNames group
```

Powyższy przykład najpierw doda mapowanie `uid` na `sAMAccountName`, a potem doda kolejne mapowanie `mail` na `emailAddress` i `groupOfNames` na `group`.

