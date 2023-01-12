buildbot-benchmark.bash
=======================

Standardised benchmark for AOSC Buildbots. This benchmark tests the relative
performance by building LLVM's core runtime using Ninja.

Usage
-----

Run the benchmark by executing the script:

```
./buildbot-benchmark.bash
```

Collect "Real" time output from `time` output:

```
real    7m30.250s       7023.34%
user    484m4.777s
sys     42m40.285s
```

Calculate seconds, rounding up decimals:

```
echo $((7*60 + 31))s
```

Input benchmark results under the "Speed" column in the [Buildbots](https://wiki.aosc.io/developer/infrastructure/buildbots/) page.
