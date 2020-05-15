# AOSCBootstrap

## Dependencies

AOSCBootstrap requires the following Perl modules:

- [LWP](https://metacpan.org/pod/LWP)
- [Try::Tiny](https://metacpan.org/pod/Try::Tiny)

On AOSC OS, you may install these dependencies using the following command:

```bash
# apt install perl-try-tiny libwww-perl
```

## Usage

```
aoscbootstrap.pl --arch=<architecture> <branch> <path/to/target> [mirror URL]
```

The `[mirror URL]` argument is optional, when omitted, the script defaults to `https://repo.aosc.io/debs`.

For example, to bootstrap a `amd64` architecture base system on the `stable` branch at `/root/aosc`, using `localhost` as the mirror:

```
aoscbootstrap.pl --arch=amd64 stable /root/aosc http://localhost/debs/
```

## Usage with `CIEL!`

To use AOSCBootstrap with [CIEL!](https://github.com/AOSC-Dev/ciel) and its plugins, you can follow these procedures below:

1. Create your work directory and `cd` into it.
1. Run `ciel init`.
1. Run `aoscbootstrap.pl --arch=<architecture> <branch> $(pwd)/.ciel/container/dist/ [mirror URL]`.
1. When finished, you may proceed to other tasks you may want to perform such as `ciel generate` and `ciel release`.
