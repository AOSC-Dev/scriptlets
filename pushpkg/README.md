pushpkg
-------

A simple wrapper script for the standard AOSC OS package upload procedure.

You should run this script inside a directory which contains a `debs` directory.

```
Usage:

	pushpkg LDAP_USERNAME BRANCH [COMPONENT]

	- LDAP_USERNAME: Your LDAP username.
	- BRANCH: AOSC OS update branch (stable, stable-proposed, testing, etc.)
	- [COMPONENT]: (Optional) Repository component (main, bsp-sunxi, etc.)
                       Falls back to "main" if not specified.
```

One-liner usage:

```shell
curl -sSL https://github.com/AOSC-Dev/scriptlets/raw/master/pushpkg/pushpkg | bash /dev/stdin LDAP_USERNAME BRANCH [COMPONENT]
```
