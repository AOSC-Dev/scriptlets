pushpkg
-------

A simple wrapper script for the standard AOSC OS package upload procedure.

You should run this script inside a directory which contains a `debs` directory.

```
usage: pushpkg [-h] [-v] [-d] [-f] [-r] [-6] [-4] [--host [HOST]] [-i IDENTITY_FILE] [USERNAME] [BRANCH] [COMPONENT]

pushpkg, push aosc package to repo.aosc.io or mirrors

positional arguments:
  USERNAME              Your LDAP username.
  BRANCH                AOSC OS update branch (stable, stable-proposed, testing, etc.)
  COMPONENT             (Optional) Repository component (main, bsp-sunxi, etc.) Falls back to "main" if not specified.

options:
  -h, --help            show this help message and exit
  -v, --verbose         Enable verbose logging for ssh and rsync
  -d, --delete          Clean OUTPUT directory after finishing uploading.
  -f, --force-push-noarch-package
                        Force Push noarch package.
  -r, --retro           Push to AOSC OS/Retro repo
  -6, --ipv6            Use IPv6 addresses only
  -4, --ipv4            Use IPv4 addresses only
  --host [HOST]         Specify the rsync host to push packages, defaults to repo.aosc.io
  -i IDENTITY_FILE, --identity-file IDENTITY_FILE
                        SSH identity file
```
