#!/bin/bash
function gen_ninja() {
	python2 vendor/gyp/gyp_main.py -f ninja \
			--depth '.' electron.gyp \
			-Icommon.gypi \
			-Dlibchromiumcontent_component="$1" \
			-Dtarget_arch='x64' \
			-Dlibrary=static_library \
			-Dmas_build=0
}

function set_abflags() {
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
}

function fetch_cr_src() {
	CRVER="$(cat VERSION)"
	echo "[+] Downloading Chromium ${CRVER} full source package..."
	wget "http://commondatastorage.googleapis.com/chromium-browser-official/chromium-${CRVER}.tar.xz"
	echo "[+] Decompressing source package..."
	if ! { tar xf "chromium-${CRVER}.tar.xz"; mv "chromium-${CRVER}" src;} then
		echo "[!] Error extracting source code!"
		return 1;
	fi
}

function apply_additional_patches() {
	PATCH_VAR="PATCHES_${ELEC_GENVER/./_}"
	wget "" # ???
	# shellcheck disable=1091
	source "additional_patches_list" # ???
}

git clone https://github.com/electron/electron.git
ELEC_VER="$1"
if [[ ! "${ELEC_VER}" ]]; then ELEC_VER="HEAD"; fi
echo "[+] Building electron version ${ELEC_VER}..."
echo "[-] Notice: Building Electron using this script may take ~75 GB disk space!"
pushd electron
if ! git checkout -f "${ELEC_VER}"; then
	echo "[!] Error checking out Electron version ${ELEC_VER}! Please make sure the version number is correct!";
	exit 1;
fi
ELEC_SEMVER=$(perl -ne '/^\s+"version":\s+"(.*)",$/ && print $1' package.json)
ELEC_GENVER="$(echo "${ELEC_SEMVER}" | cut -d '.' -f 1-2)"
echo "[+] Updating submodules, it may take a while..."
git submodule update --init --recursive
if [[ -d brightray ]]; then
# 1.7.0 or later, brightray merged into main repository
	LIBCC_DIR="$(pwd)/vendor/libchromiumcontent"
elif [[ -d vendor/brightray ]]; then
	pushd vendor/brightray
	LIBCC_DIR="$(pwd)/vendor/libchromiumcontent"
	popd
else
	echo "[!] Error determining libchromiumcontent location"
	exit 1;
fi

pushd "${LIBCC_DIR}"
# determine which branch to check out
git checkout -f "electron-${ELEC_GENVER/./-}-x"
git submodule update --init --recursive  # update submodules due to branch change
if ! fetch_cr_src; then
	exit 1
fi
echo "[+] Applying patches from Electron..."
if ! python2 script/apply-patches; then
	echo "[!] Error applying patches!"
	exit 1
fi
pushd src

echo "[+] Apply additional patches from AOSC..."
# apply additional patches here

set_abflags

echo "[+] Chromium Core bootstraping in progress..."
echo "[+] Copying Electron spec files..."
cp -r ../chromiumcontent .

echo "[+] Building GN builder..."
if ! python2 tools/gn/bootstrap/bootstrap.py --gn-gen-args "${GNFLAGS[*]}"; then
	echo "[!] GN bootstraping failed..."
	exit 1
fi

echo "[+] Generating build files..."
out/Release/gn gen out/static_library \
		--args="${GNFLAGS[*]} import(\"//chromiumcontent/args/static_library.gn\")" \
		--script-executable=/usr/bin/python2 && \
if [[ $? ]]; then
	echo "[!] Error generating build files!"
	exit 1
fi
echo "[+] Start building libchromiumcontent, it may take as long as several hours, please wait..."
echo "[+] Start building static libraries..."
if ! ninja -C out/static_library chromiumcontent:chromiumcontent; then
	echo "[!] Failed to build Chromium Core static libs"
	exit 1
fi
echo "[+] Congratulations! libchromiumcontent is successfully built!"
echo "[+] Copying files into required positions and create zip snapshots..."
if ! python2 ../script/create-dist -c static_library --no_zip; then
	echo "[!] Failed to copy files..."
	echo "[+] This maybe caused by insufficient disk space, try to free up a bit and try again"
	exit 1;
fi
echo "[+] Generating file indexes for GYP..."
LIBCC_VENDOR_DIR="$(readlink -f "${LIBCC_DIR}"/../download/libchromiumcontent)"
mkdir -p "${LIBCC_VENDOR_DIR}"
# generate_filenames_gypi.py <output.gypi> <source files> <shared_library> <static_library>
python2 ../tools/generate_filenames_gypi.py "${LIBCC_VENDOR_DIR}"/filenames.gypi ../dist/src ../dist/static_library ../dist/static_library
if [[ $? ]]; then
	echo "[!] Generation failed"
	exit 1
fi
popd # src -> libcc
popd # libcc -> electron

# fill in version number
sed "s|{PLACEHOLDER}|$(cat "$LIBCC_DIR"/VERSION)|" script/chrome_version.h.in  > atom/common/chrome_version.h
# create dummy config for bundled node
printf "\n{'variables':{}}" > vendor/node/config.gypi
# generate files twice to workaround bugs in gyp
if ! { gen_ninja 0; gen_ninja 1; } then
	echo "[!] Generation failed"
	exit 1;
fi
# correct generated ninja files to make gcc happy
sed -i 's|-rpath \\$$ORIGIN|-Wl,-rpath=\\$$ORIGIN|' out/R/obj/electron.ninja
sed -i 's|-ldl|-ldl -lpulse|' out/R/obj/electron.ninja
if ! ninja -C out/R electron; then
	echo "[!] Build failure"
	exit 1
fi
