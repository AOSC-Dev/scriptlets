#!/bin/bash -e
REPO_SLUG='aarch64-port/jdk8u-shenandoah'
REPO='jdk'
JDK_VER='8u262-b09'
TAG_NAME="aarch64-shenandoah-jdk${JDK_VER}-shenandoah-merge-2020-07-03"

# 1: REPO_SLUG 2: i (component) 3: TAG_NAME 4: JDK_VER 5: extra wget args
function download_single_comp() {
  echo "${2}: Downloading tarball ..."
  rm -f "${2}-jdk${4}.tar.gz"
  wget "$5" "http://hg.openjdk.java.net/${1}/${2}/archive/${3}.tar.gz" \
      -O "${2}-jdk${4}.tar.gz"
  echo "${2}: Download completed."
}

function download_jdk_src() {
  wget http://hg.openjdk.java.net/${REPO_SLUG}/archive/${TAG_NAME}.tar.gz \
    -O jdk8u-jdk${JDK_VER}.tar.gz

  if ! command -v parallel; then
    echo "[!] Not using parallel to download jdk."
    for i in corba hotspot jdk jaxws jaxp langtools nashorn; do
      download_single_comp "${REPO_SLUG}" "${i}" "${TAG_NAME}" "${JDK_VER}" "--"
    done
  else
    echo "[+] Using parallel to download jdk."
    export -f download_single_comp
    parallel --lb download_single_comp "${REPO_SLUG}" ::: corba hotspot jdk jaxws jaxp langtools nashorn \
    ::: "${TAG_NAME}" ::: "${JDK_VER}" ::: "-q"
  fi

  for i in *.tar.gz; do
    echo "Decompressing ${i}..."
    tar xf "$i"
  done

  mv "$(basename "${REPO_SLUG}")-${TAG_NAME}" openjdk-${JDK_VER}/
  cd openjdk-${JDK_VER}/ || exit 2
  for i in corba hotspot jdk jaxws jaxp langtools nashorn; do
    mv ../"${i}-${TAG_NAME}" ${i}
  done
  cd .. || exit 2
}

download_jdk_src

if ! which pixz > /dev/null 2>&1; then
   echo "Compressing final tarball..."
   tar cf - openjdk-${JDK_VER}/ | xz -T0 > openjdk-${JDK_VER/-b/b}.tar.xz 
else
   echo "Compressing final tarball using pixz..."
   tar -Ipixz -cf openjdk-${JDK_VER/-b/b}.tar.xz openjdk-${JDK_VER}/
fi
