loong64-it
===

Quickly converts "old-world" `loongarch64` .deb packages to "new-world"
`loong64` ones - this is useful for distributions such as Debian and deepin
who insists that architecture names should be different between worlds.

This aids users with libLoL-enabled `loong64` distributions in installing
and using old-world applications such as Tencent QQ and WPS for Linux.

Usage
---

```
loong64-it [PACKAGE1] [PACKAGE2] ...

	- PACKAGE{1..N}: Path to the old-world .deb package to convert.
```

Implementation
---

The script does the following:

- Examines the specified package file(s) as valid .deb package(s).
- Using `ar`, extracts `control.tar*` for processing.
   - Records the suffix and compression method of the control archive
     such that they could be replaced in-place in  the original .deb.
- Examines and processes `control`, replacing the `Architecture:` field from
  `loongarch64` to `loong64`, where applicable (returns an error if said
  package also comes with a `loong64` (or anything other than the old/new-
  world pair) architecture key.
- Repacks the `control.tar*` archive and replaces it in-place.
- Instructs the user that the `.deb` file has been sucessfully processed
  and is ready to use (and recommends installing libLoL).
