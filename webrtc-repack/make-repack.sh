#!/bin/bash -e
for i in curl jq perl git python3 tar xz rsync; do
    if ! command -v "$i" > /dev/null; then
        echo "[!] Please install $i!"
        exit 1
    fi
done

echo '[-] Fetching Chromium (stable) version information ...'
VERSION="$(curl -sL 'https://omahaproxy.appspot.com/all.json?channel=stable&os=linux' | jq --raw-output '.[0].versions[0].version' -)"
echo "[-] Current version seems to be $VERSION"
echo '[-] Fetching components information ...'
DEPS="$(curl -sL "https://chromium.googlesource.com/chromium/src/+/$VERSION/DEPS?format=TEXT" | base64 -d)"
echo '[-] Finding WebRTC commit information ...'
OWT_COMMIT="$(echo "$DEPS" | perl -ne "/Var\('webrtc_git'\).+?'([0-9a-f]{40})'/ && print \"\$1\"")"
[ -z "$OWT_COMMIT" ] && exit 1
echo "[-] WebRTC commit to use: $OWT_COMMIT"
echo "[+] Making a tmp directory ..."
TMPDIR="$(mktemp -d)"
pushd "$TMPDIR"
echo "[+] Downloading depot tools ..."
git clone --depth 1 https://chromium.googlesource.com/chromium/tools/depot_tools.git depot_tools
export PATH="$PATH:$(pwd)/depot_tools"
export DEPOT_TOOLS_UPDATE=0
cat << EOF > .gclient
solutions = [
  {
     "managed": False,
     "name": "src",
     "url": "https://webrtc.googlesource.com/src.git",
     "custom_deps": {},
     "deps_file": "DEPS"
  },
]
target_os = []
EOF
echo '[+] Downloading source trees using gclient, please wait patiently ...'
gclient sync --rev "$OWT_COMMIT" --no-history -n
echo '[+] Packing tarball ...'
TARBALL="webrtc-${OWT_COMMIT:0:7}.tar" 
tar cf "$TARBALL" src
xz -T0 "$TARBALL"
popd
rsync "$TMPDIR/$TARBALL.xz" .
echo "[-] Removing the directory ..."
rm -rf "$TMPDIR"
echo "Done. Your tarball is ready: $(readlink -f "$TARBALL.xz")"
