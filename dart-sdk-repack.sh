#!/bin/bash -e

# Google depot_tools repository.
DEPOT_TOOLS_REPO="https://chromium.googlesource.com/chromium/tools/depot_tools"
# Dart SDK source repository.
DART_REPO="https://dart.googlesource.com/sdk"

# Check if DART_VERSION environment variable is set; if not, print a message and exit
[[ x"${DART_VERSION}" = "x" ]] && \
    echo "DART_VERSION not set. Go to https://dart.googlesource.com/sdk/+/refs/heads/stable to figure it out." && \
    exit 1

echo "DEPOT_TOOLS_REPO=${DEPOT_TOOLS_REPO}"
echo "DART_REPO=${DART_REPO}"
echo "DART_VERSION=${DART_VERSION}"

echo "Cloning depot_tools ..."
git clone ${DEPOT_TOOLS_REPO} "depot_tools" --depth=1
PATH="${PATH}:${PWD}/depot_tools"
DEPOT_TOOLS_UPDATE=0

echo "Generating .gclient config file ..."
echo "
solutions = [
    {
        'name': 'sdk',
        'url': 'https://dart.googlesource.com/sdk.git@${DART_VERSION}',
        'custom_vars': {
            'download_android_deps': False,
            'download_reclient': False,
        },
    },
]
target_cpu = ['x64', 'arm64', 'arm', 'riscv64']
target_cpu_only = True
" > .gclient

echo "Fetching Dart SDK ${DART_VERSION} ..."
gclient sync --no-history --nohooks --shallow --verbose

echo "Removing all ELF binaries (executables and shared libraries)"
for elf in $(scanelf -RA -F "%F" sdk); do
    rm -vf "$elf"
done

echo "Renaming the sdk directory to dart-sdk-${DART_VERSION}"
mv -v sdk dart-sdk-${DART_VERSION}

echo "Removing unnecessary files and directories ..."
rm -rvf dart-sdk-${DART_VERSION}/tools/sdks/dart-sdk
rm -rvf dart-sdk-${DART_VERSION}/buildtools/sysroot
rm -rvf dart-sdk-${DART_VERSION}/buildtools/linux-x64
rm -rvf dart-sdk-${DART_VERSION}/buildtools/linux-arm64
rm -vf dart-sdk-${DART_VERSION}/buildtools/gn
rm -vf dart-sdk-${DART_VERSION}/buildtools/ninja/ninja
rm -rvf dart-sdk-${DART_VERSION}/benchmarks/FfiBoringssl/native/out
rm -rvf dart-sdk-${DART_VERSION}/benchmarks/FfiCall/native/out
rm -rvf dart-sdk-${DART_VERSION}/benchmarks/NativeCall/native/out
ln -svf /usr/lib/dart-sdk dart-sdk-${DART_VERSION}/tools/sdks/dart-sdk
ln -svf /usr/bin/gn dart-sdk-${DART_VERSION}/buildtools/gn
ln -svf /usr/bin/ninja dart-sdk-${DART_VERSION}/buildtools/ninja/ninja

echo "Generating final tarball.."
tar -cvf dart-sdk-${DART_VERSION}.tar \
    --exclude-backups \
    --exclude-caches-all \
    --exclude-vcs \
    dart-sdk-${DART_VERSION}
zstd --auto-threads=logical --ultra --long -22 -T0 -vv \
    dart-sdk-${DART_VERSION}.tar \
    -o dart-sdk-${DART_VERSION}.tar.zst

echo "Cleaning up ..."
rm -rvf depot_tools dart-sdk-${DART_VERSION} .cipd _bad_scm
rm -vf dart-sdk-${DART_VERSION}.tar \
    .gclient \
    .gclient_entries \
    .gclient_previous_custom_vars \
    .gclient_previous_sync_commits

sha256sum dart-sdk-${DART_VERSION}.tar.zst > dart-sdk-${DART_VERSION}.tar.zst.sha256sum
echo "Tarball SHA256: $(cat dart-sdk-${DART_VERSION}.tar.zst.sha256sum | awk '{print $1}')"

echo "Done!"
