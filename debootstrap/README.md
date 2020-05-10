# Debootstrap recipe for AOSC OS

## Usage

Copy `aosc` file to `/usr/share/debootstrap/scripts/` and then run `debootstrap` like this:

```
sudo debootstrap --arch=<arch> <branch> <path/to/target/directory> <mirror url> aosc
```

For example, to install `stable` branch of AOSC OS on the system with `amd64` architecture to `/mnt/system` using `repo.aosc.io` as the repository, you would use:

```
sudo debootstrap --arch=amd64 stable /mnt/system https://repo.aosc.io/debs/ aosc
```
