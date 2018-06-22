## Update outdated packages
1. go to aosc-os-abbs

```$ cd /var/lib/acbs/repo```

2. Dump repology's outdated pkgs info. to local json file

```$ python3 update-pkgs.py -d ../repology.json```

3. Search repo's outdated pkgs and replace newest version. (e.g. In the extra-graphics only)
```
$ python3 update-pkgs.py -j ../repology.json  -c extra-graphics -r
```


## Rebuild packages
1. Dump the packages list to rebuild
```
$ apt list $(apt-cache rdepends mlt | sort -u) > /path/to/mlt.txt
```

2. go to aosc-os-abbs
```
$ cd /var/lib/acbs/repo
```

3. Auto bump REL in repo
```
$ python3 rebuild.py /path/to/mlt.txt
```
