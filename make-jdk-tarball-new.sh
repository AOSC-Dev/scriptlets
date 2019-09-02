#!/bin/bash
JDK_VER='8u222-ga'
ICEDTEA_WEB='1.8'

function download_jdk_src() {
  wget http://hg.openjdk.java.net/jdk8u/jdk8u/archive/jdk${JDK_VER}.tar.gz \
    -O jdk8u-jdk${JDK_VER}.tar.gz

  for i in corba hotspot jdk jaxws jaxp langtools nashorn; do
    wget http://hg.openjdk.java.net/jdk8u/jdk8u/${i}/archive/jdk${JDK_VER}.tar.gz \
      -O ${i}-jdk${JDK_VER}.tar.gz
  done

  for i in *.tar.gz; do
    echo "Decompressing ${i}..."
    tar xf "$i"
  done

  mv jdk8u-jdk${JDK_VER}/ openjdk-${JDK_VER}/
  cd openjdk-${JDK_VER}/ || exit 2
  for i in corba hotspot jdk jaxws jaxp langtools nashorn; do
    mv ../"${i}-jdk${JDK_VER}" ${i}
  done
  cd .. || exit 2
}

function guess_download_link() {
  cat << EOF > /tmp/fetch.js
  var JDK_DL_PAGE="http://www.oracle.com/technetwork/java/javase/downloads/jdk8-downloads-2133151.html",page=require("webpage").create(),url=JDK_DL_PAGE;
  page.open(url,function(a){"success"!=a&&phantom.exit(1);a=page.evaluate(function(){var JDK_VER="${JDK_BIN_VER/-*/}";var b="";document.getElementById("agreementjdk-"+JDK_VER+"-oth-JPR-a").click();suffixes=["-linux-arm32-vfp-hflt.tar.gz","-linux-arm64-vfp-hflt.tar.gz","-linux-x64.tar.gz"];for(var c=0;c<suffixes.length;c++){console.log("jdk-"+JDK_VER+"-oth-JPRXXXjdk-"+JDK_VER+suffixes[c]);var a=document.getElementById("jdk-"+JDK_VER+"-oth-JPRXXXjdk-"+JDK_VER+suffixes[c]).href,b=a?b+(a+" "):b+"err "}return b});console.log("js-out: "+a);phantom.exit()});
EOF
  phantomjs /tmp/fetch.js | grep 'js-out:' | sed 's|js-out: ||'
}

download_jdk_src
mkdir binary; cd binary

# disable automated extraction for now
if ! which phantomjs-no > /dev/null 2>&1; then
  LINKS=("https://cdn.azul.com/zulu-embedded/bin/zulu8.40.0.178-ca-jdk1.8.0_222-linux_aarch32hf.tar.gz"
    "https://cdn.azul.com/zulu-embedded/bin/zulu8.40.0.178-ca-jdk1.8.0_222-linux_aarch64.tar.gz"
  "https://cdn.azul.com/zulu/bin/zulu8.40.0.25-ca-jdk8.0.222-linux_x64.tar.gz")
  LINKS=${LINKS[*]}
  echo "PhantomJS not found, not able to dynamically extract links. Using default links to download binaries..."
else
  LINKS=$(guess_download_link)
fi
wget -c --no-cookies \
  --header "Cookie: gpw_e24=http%3A%2F%2Fwww.oracle.com%2F; oraclelicense=accept-securebackup-cookie" \
  ${LINKS}
echo "Decompressing prebuilt binaries..."
tar xf zulu*-linux_aarch32hf.tar.gz
mv zulu*/ armel/
tar xf zulu*-linux_aarch64.tar.gz
mv zulu*/ arm64/
tar xf zulu*-linux_x64.tar.gz
mv zulu*/ amd64/
rm -rf -- *.tar.gz


cd .. || exit 2
mv binary openjdk-${JDK_VER}/

wget -c "http://icedtea.wildebeest.org/download/source/icedtea-web-$ICEDTEA_WEB.tar.gz"
tar xf "icedtea-web-$ICEDTEA_WEB.tar.gz"
mv "icedtea-web-$ICEDTEA_WEB" openjdk-${JDK_VER}/icedtea-web

if ! which pixz > /dev/null 2>&1; then
   echo "Compressing final tarball..."
   tar cJf openjdk-${JDK_VER/-b/b}.tar.xz openjdk-${JDK_VER}/
else
   echo "Compressing final tarball using pixz..."
   tar -Ipixz -cf openjdk-${JDK_VER/-b/b}.tar.xz openjdk-${JDK_VER}/
fi
