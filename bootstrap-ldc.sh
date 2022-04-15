#!/bin/bash -e

GDMD_WRAPPER="https://cdn.jsdelivr.net/gh/D-Programming-GDC/gdmd@ff2c97a47408fb71c18a2d453294d18808a97cc5/dmd-script"
TREE_DIR="/tree/extra-dlang/ldc/"

if [ ! -d /tree ]; then
    echo '[!] Must be run from a Ciel container!'
    exit 1
fi

echo '[+] Installing GDMD wrapper for gdc ...'
wget "$GDMD_WRAPPER" -O /usr/bin/gdmd
chmod a+x /usr/bin/gdmd

echo '[+] Removing ldc ...'
apt-get purge ldc || true
sed -i "s| ldc||" "${TREE_DIR}01-liblphobos/defines"

echo '[+] Patching LDC building scripts ...'
cat << 'EOF' | perl -
my $filename = '/tree/extra-dlang/ldc/01-liblphobos/build';
my $regex = qr/cmake \.\..+?ninja/msp;
my $subst = 'cmake .. -GNinja -DD_COMPILER=/usr/bin/gdmd -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX=/usr;ninja';

my $file_content = do{local(@ARGV,$/)=$filename;<>};
my $result = $file_content =~ s/$regex/$subst/rg;
open(FH, '>', $filename) or die $!;

print FH "$result\n";
EOF

echo '[+] Bootstrapping LDC ...'
acbs-build ldc

echo '[+] Restoring Git tree ...'
pushd /tree
git checkout -f 'extra-dlang/ldc/'
popd
rm -v /usr/bin/gdmd

echo '[+] Re-building LDC with LDC ...'
acbs-build ldc
