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

The mirror URL argument is optional, when omitted, defaults to `https://repo.aosc.io/debs`.

For example, bootstrapping `amd64` architecture base system on `stable` branch with the installation location `/root/aosc` using localhost as the mirror:

```
aoscbootstrap.pl --arch=amd64 stable /root/aosc http://localhost/debs/
```

## Use with `CIEL!`

To use with `CIEL!` and its plugins, you can follow the simple steps below:

1. Create your working directory and `cd` into it
1. Run `ciel init`
1. Run `aoscbootstrap.pl --arch=<architecture> <branch> $(pwd)/.ciel/container/dist/ [mirror URL]`
1. When finished, you can proceed to other tasks you may want to perform such as `ciel generate`
