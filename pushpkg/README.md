pushpkg
-------

A simple wrapper script for the standard AOSC OS package upload procedure.

You should run this script inside a directory which contains a `debs` directory.

```
Usage:

        pushpkg -u LDAP_USERNAME -b BRANCH -c [COMPONENT]

        -u LDAP_USERNAME: Your LDAP username.
        -b BRANCH: AOSC OS update branch (stable, stable-proposed, testing, etc.)

Options:

    -c [COMPONENT]: (Optional) Repository component (main, bsp-sunxi, etc.)
                       Falls back to "main" if not specified.
    -d: pushpkg after clean OUTPUT directory
    -v: ssh and rsync verbose
```

One-liner usage:

```shell
curl -sSL https://github.com/AOSC-Dev/scriptlets/raw/master/pushpkg/pushpkg | bash /dev/stdin -u LDAP_USERNAME -b BRANCH -c [COMPONENT]
```
