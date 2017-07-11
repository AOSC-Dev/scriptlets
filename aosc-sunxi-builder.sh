#!/bin/bash
function print_tick() {
  echo -e "\e[92m✔\e[0m"
}
function print_cross() {
  echo -e "\e[91m✘\e[0m"
}
function adie() {
  echo -e "[!] \e[91mError(s) occurred! See logs for more information.\e[0m"
  grep -n -r "Error" "${LOGDIR}"
  exit 1
}
function print_progress() {
  # 1. build stage 2. build pace 3. sub items
  if [[ ! "${EXDESC}" ]]; then
    LAST_PRGS="${1} ${2} ${3}"
  fi
  printf "\r%s %s" "${LAST_PRGS}" "${EXDESC}"
  unset EXDESC
}
function fetch_kernel_version() {
  TMPFILE="$(mktemp --suffix=".py")"
  cat << EOF > "${TMPFILE}"
import json, sys
dist = json.load(sys.stdin)
for i in dist['releases']:
    if i['moniker'] == "${BUILD_MONIKER}":
        print(i['source'] or i['gitweb'])

EOF
  TBLURL=$(bash -c "curl --silent 'https://www.kernel.org/releases.json' | python \"${TMPFILE}\"")
  if [[ $? -eq 0 ]]; then
    print_tick
    rm "${TMPFILE}"
    return 0
  else
    print_cross
    rm "${TMPFILE}"
    return 1
  fi
}

function fetch_uboot_version() {
  TMPFILE="$(mktemp --suffix=".py")"
  cat << EOF > "${TMPFILE}"
import json, sys
dist = json.load(sys.stdin)
print(dist[0]['name'], dist[0]['tarball_url'], sep='\n')
EOF
  RETDATA=$(bash -c "curl -H 'Accept: application/vnd.github.v3+json' --silent 'https://api.github.com/repos/u-boot/u-boot/tags' | python \"${TMPFILE}\"")
  if [[ $? -eq 0 ]]; then
    print_tick
    rm "${TMPFILE}"
    return 0
  else
    print_cross
    rm "${TMPFILE}"
    return 1
  fi
}

function cp_dtb() {
  printf "[*] Copying final Device Tree Blobs... "
  for i in $DTB_TARGETS
  do
  	DTB_CNAME="$(echo "$i" | cut -d = -f 1)"
  	DTB_AOSCNAME="$(echo "$i" | cut -d = -f 2)"
  	mkdir -p "$OUTDIR"/dtb-"$DTB_AOSCNAME"
  	cp "$LINUX_DIR"/arch/arm/boot/dts/"$DTB_CNAME".dtb "$OUTDIR"/dtb-"$DTB_AOSCNAME"/dtb.dtb > /dev/null 2>&1 || { print_cross; adie; }
  done
  print_tick
}

function build_uboot() {
  STAGE="[*] Building U-Boot... "
  TGT_COUNT=$(echo "${UBOOT_TARGETS}" | wc -w)
  PRGS=0
  for i in $UBOOT_TARGETS; do
    ((PRGS+=1))
    UBOOT_CNAME="$(echo "$i" | cut -d = -f 1)"
    UBOOT_AOSCNAME="$(echo "$i" | cut -d = -f 2)"
    print_progress "${STAGE}" "[${PRGS}/${TGT_COUNT}]" "${UBOOT_AOSCNAME}"
    EXDESC="> Decompressing   " print_progress
    tar xf "${UBOOTTBLNAME}"
    UBOOT_DIR="$(echo u-boot-*/)"
    pushd "$UBOOT_DIR" > /dev/null
    EXDESC="> Patching   " print_progress
    for j in ../patches/u-boot/*
    do
      patch -Np1 -s -i "${j}" >> "${LOGDIR}/patch.log"
    done
    EXDESC="> Building       " print_progress
    { echo "${UBOOT_CNAME}"; make "${UBOOT_CNAME}"_defconfig; } >> "${LOGDIR}/u-boot.log" 2>&1
    make CROSS_COMPILE="${CROSS_COMPILE}" -j"$(nproc)" >> "${LOGDIR}/u-boot.log" 2>&1
    if [[ $? -ne 0 ]]; then
      print_cross
      adie
    fi
    EXDESC="> Completed   " print_progress
    mkdir -p "$OUTDIR"/u-boot-"$UBOOT_AOSCNAME"/
    cp u-boot-sunxi-with-spl.bin "$OUTDIR"/u-boot-"$UBOOT_AOSCNAME"/
    popd > /dev/null
    rm -r "$UBOOT_DIR"
  done;
  print_tick
}

function build_linux() {
  LINUX_SRC="$(echo linux-*.tar*)"
  LINUX_DIR="${TBLNAME//\.tar*/}"
  if [[ "${BUILD_CHOICE}" != "1" ]]; then
    git reset --hard
    if ! git checkout -f staging; then
      echo "[!] Failed to switch branch!"
      adie
    fi
  fi
  STAGE="[*] Building Linux kernel... "
  TGT_COUNT=2
  PRGS=0
  for tgt in 'sunxi-kvm-config' 'sunxi-nokvm-config';
  do
    ((PRGS+=1))
    print_progress "${STAGE}" "[$PRGS/$TGT_COUNT]" "$tgt"
    if [[ ! -d "${LINUX_DIR}" ]]; then
      EXDESC="> Decompressing   " print_progress
      tar xf "${LINUX_SRC}"
      LINUX_DIR="$(echo linux-*)"
      pushd "${LINUX_DIR}" > /dev/null
      EXDESC="> Patching   " print_progress
      for i in ../patches/linux/*
  		do
  			patch -Np1 -s -i "$i" >> "${LOGDIR}/patch.log" 2>&1
  		done
    else
      pushd "$LINUX_DIR" > /dev/null
    fi
    EXDESC="> Building kernel   " print_progress
    cp "../${tgt}" .config
    make ARCH=arm CROSS_COMPILE="${CROSS_COMPILE}" -j"$(nproc)" >> "${LOGDIR}/linux-${tgt}.log" 2>&1
    TMPDIR=$(mktemp -d)
    EXDESC="> Installing modules   " print_progress
    make ARCH=arm CROSS_COMPILE="${CROSS_COMPILE}" INSTALL_MOD_PATH="$TMPDIR" modules_install >> "${LOGDIR}/linux-${tgt}.log" 2>&1
    mkdir -p "$OUTDIR/linux-$tgt"
    cp -- arch/arm/boot/zImage "$OUTDIR/linux-$tgt/zImage"
    EXDESC="> Building extra modules " print_progress
    EXTRA_KMOD_DIR="$(echo "$TMPDIR"/lib/modules/*)/kernel/extra"
    mkdir -p "$EXTRA_KMOD_DIR"
    for i in ../extra-kmod/*
    do
      EXDESC="> Building extra modules > $(basename "${i}") " print_progress
      export KDIR=$PWD ARCH=arm CROSS_COMPILE="${CROSS_COMPILE}"
      pushd "$i" > /dev/null
      sh build.sh >> "${LOGDIR}/extramods.log" 2>&1
      cp -- *.ko "$EXTRA_KMOD_DIR/"
      popd > /dev/null
      unset KDIR
    done
    EXDESC="> Installing extra modules " print_progress
    depmod -b "$TMPDIR" "$(basename "$(readlink -f $EXTRA_KMOD_DIR/../..)")"
    cp -r -- "$TMPDIR"/lib/modules/ "$OUTDIR/linux-$tgt/"
    rm -r -- "$TMPDIR"
    popd > /dev/null
  done
}

if [[ ! "${CROSS_COMPILE}" ]]; then
  echo "Please set \`CROSS_COMPILE' environment variable."
  exit 1
fi
printf "Please select a channel:\n\t\t[1] stable\n\t\t[2] RC\n\t\t[3] next\n"
read -n 1 -r -p "[*] Your choice? [Default: 1] " BUILD_CHOICE
echo
case "${BUILD_CHOICE}" in
  2 )
    echo "[*] Will build RC version of kernel image. (Potentially unstable)"
    BUILD_MONIKER="mainline";;
  3 )
    echo "[*] Will build linux-next version of kernel image. (Warriors ONLY!)"
    BUILD_MONIKER="linux-next";;
  * )
    echo "[*] Will build stable version of kernel image."
    BUILD_CHOICE=1 && BUILD_MONIKER="stable";;
esac
printf "[*] Fetching Linux kernel releases information... "
if ! fetch_kernel_version; then
  exit 1
fi
printf "[*] Fetching Das U-Boot releases information...   "
if ! fetch_uboot_version; then
  exit 1
fi
for i in $RETDATA;
  do if [[ ${i:0:1} == 'v' ]]; then
    UBOOT_VERSION="${i}"
  else
    UBOOT_URL="${i}"
  fi;
done
TBLNAME=$(basename "${TBLURL}")
UBOOTTBLNAME="u-boot-${UBOOT_VERSION}.tar.gz"
echo "[*] Downloading U-Boot: ${UBOOT_VERSION}..."
if ! test -f "${UBOOTTBLNAME}"; then
  if ! (wget -c "${UBOOT_URL}" -O "${UBOOTTBLNAME}.dl" && mv "${UBOOTTBLNAME}.dl" "${UBOOTTBLNAME}"); then
    exit 127
  fi
fi
echo "[*] Downloading Linux kernel: ${TBLNAME//\.tar*/}..."
if [[ ${BUILD_CHOICE} -eq 3  ]]; then
  TBLURL="https://git.kernel.org/pub/scm/linux/kernel/git/next/linux-next.git/snapshot/linux-next-${TBLNAME//\.tar*/}.tar.gz"
  TBLNAME="linux-${TBLNAME}.tar.gz"
fi
if ! test -f "${TBLNAME}"; then
  if ! (wget -c "${TBLURL}" -O "${TBLNAME}.dl" && mv "${TBLNAME}.dl" "${TBLNAME}"); then
    exit 127
  fi
fi
if [[ ! "${OUTDIR}" ]]; then
  mkdir out || rm -r out/*
  OUTDIR="$(readlink -f out)"
fi
echo "[*] Fetching AOSC SUNXI building receipt..."
if test -d "aosc-os-armel-sunxi-boot/.git"; then
  pushd aosc-os-armel-sunxi-boot
  if ! ( git gc && git fetch --all && git pull -f ); then
    echo "[!] Git repository messed up!!! Please fix it manually or remove it!"
    exit 127
  fi
  popd
else
  if ! git clone "https://github.com/AOSC-Dev/aosc-os-armel-sunxi-boot"; then
    print_cross
    exit 127
  fi
fi
echo "[*] Output directory: ${OUTDIR}"
pushd "aosc-os-armel-sunxi-boot"
rm -rf logs || true
mkdir logs
LOGDIR="$(readlink -f ./logs)"
echo "[*] Log directory: ${LOGDIR}"
unlink linux-*.tar*
unlink u-boot-*.tar*
ln -s ../"${TBLNAME}" .
ln -s ../"${UBOOTTBLNAME}" .
chmod a+x ./list.sh
. ./list.sh
if [[ "${BUILD_UBOOT}" == "0" ]]; then
  echo "[*] Not building U-Boot as required."
else
  if ! build_uboot; then adie; fi
fi
if [[ "${BUILD_LINUX}" == "0" ]]; then
  echo "[*] Not building Linux kernel as required."
else
  if ! build_linux; then adie; fi
fi

cp_dtb

GIT_REV=$(git rev-parse --short HEAD)
popd
FILE_COUNT=$(find "${OUTDIR}" | wc -l)
if [[ $((FILE_COUNT)) -lt 76 ]]; then
	echo "[!] No enough files collected, suspecting a build failure!"
	adie
fi
echo "[*] Tarring final tarball..."
TARBALL_NAME="aosc-os-armel-sunxi-boot-$(date +%Y%m%d)-g${GIT_REV}-$(basename "${LINUX_DIR}")-$(basename ${UBOOT_DIR})"
tar cJf "$(pwd)/${TARBALL_NAME}.tar.xz" "${OUTDIR}/"*
FILE_SIZE=$(stat -c "%s" "$(pwd)/${TARBALL_NAME}.tar.xz")
if [[ $((FILE_SIZE)) -lt 20000000 ]]; then
	echo "[!] Resulting file too small (only ${FILE_SIZE} bytes), suspecting a build failure!"
	rm -- "${TARBALL_NAME}.tar.xz"
	adie
fi
echo "[+] Product: ${TARBALL_NAME}.tar.xz"
echo "[+] Size:    ${FILE_SIZE} bytes"
