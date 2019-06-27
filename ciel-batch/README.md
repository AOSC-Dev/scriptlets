ciel-batch
-------

A simple wrapper script to build a list of packages using Ciel, with build
environments reset for each package.

Usage:

```
[linux32] ciel-batch opencollada python-2 python-3
```

Or, using a list, for instance:

```
opencollada
python-2
python-3
```

And invoke:

```
[linux32] ciel-batch `cat list`
```
