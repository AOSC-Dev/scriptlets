pushpkg
-------

A simple wrapper script for the standard AOSC OS package upload procedure.

Usage:

`
pushpkg $user $branch
`

- $user: your LDAP username.
- $branch: target repository branch.

One-liner usage:

```shell
curl -sSL https://github.com/AOSC-Dev/scriptlets/raw/master/pushpkg/pushpkg | bash /dev/stdin $user $branch
```
