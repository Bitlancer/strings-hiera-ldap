# strings-hiera-ldap

Bitlancer Strings LDAP backend for hiera

## In a Nutshell

Provides a new hiera backend, "ldapjson", which can be configured to
query ldap for a json hash and then lookup a key in the json.

## Installation

The only dep for running should be net-ldap, installable with:

```gem install net-ldap```

You can build a local gem of the backend with

```gem build hiera-ldap-json-backend.gemspec```

And then install the resulting gem.

Running the rspec tests requires a JVM (for the in-memory ldap server)
and gems for rspec, mocha, and ladle.

## Configuration

Example configuration:

```
---
:backends:
  - ldapjson

:logger: console

:hierarchy:
  - common
  - "datacenter/%{::home}"
  - silly/example/here

:ldapjson:
   :ldap_host: 'localhost'
   :ldap_port: 389
   :ldap_base: 'dc=testing,dc=com'
   :ldap_bind_dn: 'cn=Manager,dc=testing,dc=com'
   :ldap_bind_password: 'password'
   :ldap_attr: 'description'
   :hiera_base_ou: 'ou=myhiera'
```

All ldapjson fields are required.

## Source Hierarchy to LDAP Translation

A source in the hierarchy is translated to an ldap search with the
following rules:

1. the source is split on "/" (e.g., "test/this/now" becomes ["test",
"this", "now"]

2. the last entry in the split source is treated as a cn, all others
as ous in reverse order (e.g. "test/this/now" becomes
"cn=now,ou=this,ou=test")

3. the hiera_base_ou config value is appended with a comma (e.g.,
"cn=now,ou=this,ou=test" becomes "cn=now,ou=this,ou=test,ou=myhiera")

4. the ldap_base config value is appended with a comma (e.g.,
"cn=now,ou=this,ou=test,ou=myhiera" becomes
"cn=now,ou=this,ou=test,ou=myhiera,dc=testing,dc=com")

5. The ldap entry with the resulting dn is then looked up.

Interpolations of variables work as usual.

## Hash Queries

Are not supported

## Query Example (using the above config)

```
dn: cn=common,ou=myhiera,dc=testing,dc=com
objectClass: domain
objectClass: extensibleObject
dc: common
description: {"testkey": "test value one"}

dn: cn=here,ou=example,ou=silly,ou=myhiera,dc=testing,dc=com
objectClass: domain
objectClass: extensibleObject
dc: common
description: {"testkey": "test value two", "other": "one"}
```

Then

```hiera testkey```

Would get you:

"test value one"

And

```hiera -a testkey```

Would get you:

["test value two"]

While

```hiera other```

would get you:

"one"
