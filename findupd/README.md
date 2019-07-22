## Update Outdated Packages (Quick-n-Easy)

1. Go to an ABBS tree

```$ cd /path/to/abbs-tree```

2. Move all scripts to $PATH (e.g. /usr/local/bin)

```
$ mv findupd* /usr/local/bin
$ mv *.py /usr/local/bin
```

3. Check for updates

```
# For all updates
$ findupd

# For patch-level (a.k.a. stable-proposed) updates
$ findupd-stable
```

## Update Outdated Packages (Stick Shift Mastery)

1. Go to an ABBS tree

```$ cd /path/to/abbs-tree```

2. Move all scripts to $PATH (e.g. /usr/local/bin)

```
$ mv findupd* /usr/local/bin
$ mv *.py /usr/local/bin
```

3. Dump repology's outdated pkgs info. to local json file

```$ python3 update-pkgs.py -d ../repology.json```

4. Search for updates (e.g. In the extra-graphics only)

```
$ python3 update-pkgs.py -j ../repology.json  -c extra-graphics -r
```

### Save Update Data Source to File

```
$ python3 update-pkgs.py -j ../repology.json -s cache.txt
```

### Load Saved Data Source (as cache)

```
$ python3 update-pkgs.py -l cache.txt -c extra-graphics -r -q
```

### Use AOSC OS Packages Site's Data Source

1. $ wget "https://packages.aosc.io/srcupd/aosc-os-abbs?type=json&page=all" -O packages.json

2. $ python3 update-pkgs.py -j ../packages.json  -c extra-graphics -r

## Rebuild Packages

1. Dump the packages list to rebuild

```
$ apt list $(apt-cache rdepends mlt | sort -u) > /path/to/mlt.txt
```

2. Go to an ABBS tree

```
$ cd /path/to/abbs-tree
```

3. Automatically bump REL in repo

```
$ python3 rebuild.py /path/to/mlt.txt
```
