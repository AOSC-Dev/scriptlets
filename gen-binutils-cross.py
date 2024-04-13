for arch in ["amd64", "arm64", "loongarch64", "loongson3", "mips64r6el", "powerpc", "ppc64", "ppc64el", "riscv64"]:
    folder = f"binutils+cross-{arch}"
    with open(f"{folder}/spec", "w") as f:
        print("""VER=2.42
SRCS="tbl::https://ftp.gnu.org/gnu/binutils/binutils-$VER.tar.xz"
CHKSUMS="sha256::f6e4d41fd5fc778b06b7891457b3620da5ecea1006c6a4a41ae998109f85a800"
CHKUPDATE="anitya::id=7981"
""".strip(), file=f)
    with open(f"{folder}/autobuild/defines", "w") as f:
        print(f"""PKGNAME=binutils+cross-{arch}
PKGDEP="glibc"
BUILDDEP="flex xz elfutils"
PKGSEC=devel
PKGDES="Binutils for {arch} cross build"
""".strip(), file=f)
    with open(f"{folder}/autobuild/beyond", "w") as f:
        print(f"""abinfo "Dropping texinfo dir ..."
rm -v "$PKGDIR"/opt/abcross/{arch}/share/info/dir
""".strip(), file=f)
    with open(f"{folder}/autobuild/build", "w") as f:
        target = {
                "amd64": "x86_64-aosc-linux-gnu",
                "arm64": "aarch64-aosc-linux-gnu",
                "loongarch64": "loongarch64-aosc-linux-gnu",
                "loongson3": "mips64el-aosc-linux-gnuabi64",
                "mips64r6el": "mipsisa64r6el-aosc-linux-gnuabi64",
                "powerpc": "powerpc-aosc-linux-gnu",
                "ppc64": "powerpc64-aosc-linux-gnu",
                "ppc64el": "powerpc64le-aosc-linux-gnu",
                "riscv64": "riscv64-aosc-linux-gnu",
        }[arch]
        if arch == "amd64":
            flags = ["--enable-shared", "--disable-multilib", "--disable-werror"]
        elif arch == "arm64":
            flags = ["--enable-shared", "--disable-multilib", "--with-arch=armv8-a", "--disable-werror", "--enable-gold"]
        elif arch == "loongarch64":
            flags = ["--enable-shared", "--disable-multilib", "--with-arch=la464", "--disable-werror", "--disable-gold"]
        elif arch == "loongson3":
            flags = ["--enable-threads", "--enable-shared", "--with-pic", "--enable-ld", "--enable-plugins", "--disable-werror", "--enable-lto", "--disable-gdb", "--enable-deterministic-archives", "--enable-64-bit-bfd", "--enable-mips-fix-loongson3-llsc"]
        elif arch == "mips64r6el":
            flags = ["--enable-shared", "--disable-multilib", "--with-arch=mips64r6", "--with-tune=mips64r6", "--disable-werror", "--enable-gold"]
        elif arch == "powerpc":
            flags = ["--enable-threads", "--enable-shared", "--with-pic", "--enable-ld", "--enable-plugins", "--disable-werror", "--enable-lto", "--disable-gdb", "--enable-deterministic-archives", "--enable-64-bit-bfd"]
        elif arch == "ppc64":
            flags = ["--enable-threads", "--enable-shared", "--with-pic", "--enable-ld", "--enable-plugins", "--disable-werror", "--enable-lto", "--disable-gdb", "--enable-deterministic-archives", "--enable-64-bit-bfd"]
        elif arch == "ppc64el":
            flags = ["--enable-threads", "--enable-shared", "--with-pic", "--enable-ld", "--enable-plugins", "--disable-werror", "--enable-lto", "--disable-gdb", "--enable-deterministic-archives", "--enable-targets=powerpc-linux", "--enable-64-bit-bfd"]
        elif arch == "riscv64":
            flags = ["--enable-shared", "--disable-multilib", "--disable-werror", "--with-isa-spec=2.2"]
        extra_flags = " \\\n        ".join(flags)
        print(f"""# Auto-generated by scriptlets/gen-binutils-cross.py
abinfo "Clearing compiler flags in environment..."
unset CFLAGS CXXFLAGS CPPFLAGS LDFLAGS

abinfo "Configuring binutils..."
mkdir -pv "$SRCDIR"/build
cd "$SRCDIR"/build

../configure \\
        --prefix=/opt/abcross/{arch} \\
        --target={target} \\
        --with-sysroot=/var/ab/cross-root/{arch} \\
        {extra_flags}

abinfo "Building binutils..."
make configure-host
make

abinfo "Installing binutils to target directory..."
make DESTDIR=$PKGDIR install
""".strip(), file=f)