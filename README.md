# strings-hiera-ldap

Bitlancer Strings LDAP backend for hiera

## In a Nutshell

Provides a new hiera backend, "ldapjson", which can be configured to
pull json from ldap and then query it in the same manner as the normal
json backend.

## Configuration

Example configuration:

```
---
:backends:
  - ldapjson

:logger: console

:hierarchy:
  - common

:ldapjson:
   :ldap_host: 'localhost'
   :ldap_port: 389
   :ldap_base: 'dc=testing,dc=com'
   :ldap_bind_dn: 'cn=Manager,dc=testing,dc=com'
   :ldap_bind_password: 'password'
   :ldap_filter: '(objectclass=domain)'
   :ldap_attr: 'description'
```

The ldap_filter value can (and should) have interpolated scope values
in it (e.g. ```%{env}``` or ```%{location}```), as these values will
be filled in from the scope of the query.  For convenience, the
```%{key}``` value is also interpolated in the ldap_filter.

All ldapjson fields are required.

## Query Handling

Query handling is pretty much the same as the normal json backend,
with one added wrinkle: whereas the json backend will merge multiple
json files and json arrays on an array or hash query, the ldap json
backend will merge multiple entries returned from an ldap search, json
arrays, **and** multiple values for the target attr in each of those
entries.  In other words, if you had, using the above (kind of
nonsense) configuration, two entries in ldap:

```
dn: cn=ewj,dc=testing,dc=com
objectClass: domain
objectClass: extensibleObject
dc: hi
description: {"testkey": "test value one"}

dn: cn=ewj2,dc=testing,dc=com
objectClass: domain
objectClass: extensibleObject
dc: hi2
description: {"testkey": "test value two"}
description: {"testkey": ["test value three", "test value four"]}
```

and you ran

```hiera -a testkey```

You'd get back all four of "test value one", "test value two", "test
value three", and "test value four".
