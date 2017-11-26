#!/bin/bash
TMP="$(mktemp -d)"
mkdir "${TMP}/autobuild"
cat << EOF > "${TMP}/autobuild/defines"
PKGNAME=test
PKGDES=test
PKGVER=1
PKGREL=0
EOF

FLAGS_SH=$(readlink -f "${TMP}/flags.sh")
cat << EOS > "${TMP}/autobuild/build"
echo "export CFLAGS='\${CFLAGS}'" > ${FLAGS_SH}
echo "export CXXFLAGS='\${CXXFLAGS}'" >> ${FLAGS_SH}
echo "export LDFLAGS='\${LDFLAGS}'" >> ${FLAGS_SH}
exit 1
EOS

pushd "${TMP}"
autobuild
source "${FLAGS_SH}"
popd
rm -rf "${TMP}"
