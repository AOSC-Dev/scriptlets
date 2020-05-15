# AOSCBootstrap

## Dependencies

Requires the following Perl modules:

- LWP
- Try-Tiny

On AOSC OS, you can install using the following command:

```bash
apt install perl-try-tiny libwww-perl
```

## Usage

```
aoscbootstrap.pl --arch=<architecture> <branch> <path/to/target> [mirror URL]
```

For example, bootstrapping `amd64` architecture base system on `stable` branch with the installation location `/root/aosc` using localhost as the mirror:

```
aoscbootstrap.pl --arch=amd64 stable /root/aosc http://localhost/debs/
```
