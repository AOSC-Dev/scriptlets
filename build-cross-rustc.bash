#!/bin/bash -e

# Usage information.
_help_message() {
	printf "\
Usage:

	$0 AOSC_ARCH

	- AOSC_ARCH: AOSC OS architecture (amd64, arm64, loongson3, etc.).

"
}

# Preformatted echo.
abwarn() { echo -e "[\e[33mWARN\e[0m]:  \e[1m$*\e[0m"; }
aberr()  { echo -e "[\e[31mERROR\e[0m]: \e[1m$*\e[0m"; exit 1; }
abinfo() { echo -e "[\e[96mINFO\e[0m]:  \e[1m$*\e[0m"; }
abdbg()  { echo -e "[\e[32mDEBUG\e[0m]: \e[1m$*\e[0m"; }

if [[ "$1" == "--help" || "$1" == "-h" ]]; then
	_help_message
	exit 0
fi

if [ -z "$1" ]; then
	aberr "Please specify a target architecture in AOSC OS format."
	_help_message
	exit 1
fi

# Triple map.
case $1 in
	amd64)
		CHOST="amd64-aosc-linux-gnu"
		;;
	arm64)
		CHOST="aarch64-aosc-linux-gnu"
		;;
	armv4)
		CHOST="arm-aosc-linux-gnueabi"
		;;
	armv6hf)
		CHOST="arm-aosc-linux-gnueabihf"
		;;
	armv7hf)
		CHOST="arm-aosc-linux-gnueabihf"
		;;
	i486)
		CHOST="i486-aosc-linux-gnu"
		;;
	loongson2f)
		CHOST="mips64el-aosc-linux-gnuabi64"
		;;
	loongson3)
		CHOST="mips64el-aosc-linux-gnuabi64"
		RUSTFLAGS="${RUSTFLAGS} -Clink-args=-fuse-ld=lld"
		;;
	loongarch64)
		CHOST="loongarch64-aosc-linux-gnu"
		;;
	m68k)
		CHOST="m68k-aosc-linux-gnu"
		;;
	mips32r6el)
		CHOST="mipsisa32r6el-aosc-linux-gnu"
		RUSTFLAGS='-Clink-arg=-latomic --cap-lints allow'
		;;
	mips64r6el)
		CHOST="mipsisa64r6el-aosc-linux-gnuabi64"
		RUSTFLAGS="${RUSTFLAGS} -Clink-args=-fuse-ld=gold"
		;;
	powerpc)
		CHOST="powerpc-aosc-linux-gnu"
		;;
	ppc64)
		CHOST="powerpc64-aosc-linux-gnu"
		;;
	ppc64el)
		CHOST="powerpc64le-aosc-linux-gnu"
		;;
	riscv64)
		CHOST="riscv64-aosc-linux-gnu"
		;;
	alpha)
		CHOST="alpha-aosc-linux-gnu"
		;;
esac

# Generate Rust architecture from triple.
RARCH="${CHOST%%-*}"

# Generate LLVM triple.
RHOST="${CHOST/aosc/unknown}"
# Generate LLVM tuple for variables.
RHOST_ENV="${RHOST//\-/_}"
RHOST_ENV="${RHOST_ENV^^}"

abinfo "Applying supplied patches ..."
shopt -s nullglob
if [[ -n $(echo *.patch) ]]; then
	for i in *.patch; do
		abinfo "... $i ..."
		patch -Np1 -i $i || \
			aberr "Failed to apply patch $i: $?"
	done
fi

abinfo "Generating config.toml ..."
cat > config.toml <<EOF
changelog-seen = 2

[llvm]
download-ci-llvm = false
optimize = true
ninja = true

[rust]
debug = false
debuginfo-level = 0
deny-warnings = false
parallel-compiler = false

[build]
target = ["${RHOST}"]
host = ["${RHOST}"]
vendor = true
EOF

cat >> config.toml <<EOF
extended = true
tools = ["cargo", "clippy", "rustfmt", "rustdoc", "rust-analyzer-proc-macro-srv"]

[install]
prefix = "/opt/rustc-bootstrap-$(cat version | cut -f1 -d' ')-$1"
EOF

abinfo "Building cross Rust for $1 ($CHOST) ..."
env \
	RUSTFLAGS="-Clink-arg=-lz ${RUSTFLAGS}" \
	CROSS_COMPILE="/opt/abcross/$1/bin/${CHOST}-" \
	DESTDIR=`pwd`/rustc-bootstrap-$(cat version | cut -f1 -d' ')-$1 \
	${RHOST_ENV}_OPENSSL_NO_VENDOR=y \
	${RHOST_ENV}_OPENSSL_INCLUDE_DIR="/var/ab/cross-root/$1/usr/include" \
	${RHOST_ENV}_OPENSSL_LIB_DIR="/var/ab/cross-root/$1/usr/lib" \
	${RHOST_ENV}_LIBFFI_NO_VENDOR=y \
	${RHOST_ENV}_LIBFFI_INCLUDE_DIR="/var/ab/cross-root/$1/usr/include" \
	${RHOST_ENV}_LIBFFI_LIB_DIR="/var/ab/cross-root/$1/usr/lib" \
	python3 ./x.py install || \
		aberr "Failed to build cross Rust for $1 ($CHOST): $?"

abinfo "Building cross Rust tarball for $1 ($CHOST) ..."
tar cvf - rustc-bootstrap-$(cat version | cut -f1 -d' ')-$1 | \
	xz -T0 -9 > rustc-bootstrap-$(cat version | cut -f1 -d' ')-$1.tar.xz || \
		aberr "Failed to build cross Rust tarball for $1 ($CHOST): $?"

abinfo "Generating checksums for the cross Rust tarball ($1, $CHOST) ..."
sha256sum rustc-bootstrap-$(cat version | cut -f1 -d' ')-$1.tar.xz \
	> rustc-bootstrap-$(cat version | cut -f1 -d' ')-$1.tar.xz.sha256sum || \
		aberr "Failed to generate checksums for the cross Rust tarball ($1, $CHOST): $?"

abinfo "Build complete, cross Rust tarball ($1, $CHOST) available at:"
echo -e "
    $PWD/rustc-bootstrap-$(cat version | cut -f1 -d' ')-$1.tar.xz
"
