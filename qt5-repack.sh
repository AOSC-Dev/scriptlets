#!/bin/bash -e

#KDE_QT_COMMIT
KDE_QT_REPO='https://invent.kde.org/qt/qt/qt5'
KDE_QT_BANNED_MODULES=('qtcanvas3d' 'qtfeedback' 'qtpim' 'qtqa' 'qtrepotools' 'qtsystems' 'qtdocgallery')
#CATAPULT_COMMIT
CATAPULT_REPO='https://chromium.googlesource.com/catapult'
QTWK_VERSION="${QTWK_VERSION:5.212.0}"
QTWK_URL="https://github.com/qtwebkit/qtwebkit/releases/download/qtwebkit-${QTWK_VERSION}-alpha4/qtwebkit-${QTWK_VERSION}-alpha4.tar.xz"
GIT_ARCHIVE_BIN="git-archive-all"

clone_kde_qt() {
    git clone "${KDE_QT_REPO}" 'kde-qt5'
    cd kde-qt5
    git checkout -f "${KDE_QT_COMMIT}"
    local COMMIT_TIMESTAMP="$(git log -1 --format=%ct)"
    date --date "@${COMMIT_TIMESTAMP}" '+%Y%m%d' > ../COMMIT-DATE
    echo '[+] Unregistering unwanted Qt components ...'
    git rm -rf "${KDE_QT_BANNED_MODULES[@]}"
    echo '[+] Cloning Qt components ...'
    git submodule update --recursive --init --depth 1000 --jobs 4
    echo '[+] Archiving Git repository using git-archive-all ...'
    "${GIT_ARCHIVE_BIN}" --force-submodules ../qt-5.tmp.tar
    cd ..
}

fetch_webkit() {
    echo '[+] Fetching Qt Webkit ...'
    wget "${QTWK_URL}"
    tar xf "qtwebkit-${QTWK_VERSION}-alpha4.tar.xz"
}

fetch_catapult() {
    echo '[+] Cloning Catapult ...'
    git clone "${CATAPULT_REPO}" catapult
    cd catapult
    git archive --format tar -o ../catapult.tmp.tar "${CATAPULT_COMMIT}"
}

[ -z "${KDE_QT_COMMIT}" ] && echo "KDE_QT_COMMIT not set. Go to https://invent.kde.org/qt/qt/qt5/-/tree/kde/5.15 to figure it out." && exit 1
[ -z "${CATAPULT_COMMIT}" ] && echo "CATAPULT_COMMIT not set. Go to https://chromium.googlesource.com/catapult/+/refs/heads/main to figure it out." && exit 1

echo '[+] Installing git-archive-all utility ...'
pip3 install --user --upgrade git-archive-all
"${GIT_ARCHIVE_BIN}" --version

fetch_catapult &
CATAPULT_JOB="$!"

clone_kde_qt &
KDE_QT_JOB="$!"

fetch_webkit &
WEBKIT_JOB="$!"

wait $KDE_QT_JOB $CATAPULT_JOB $WEBKIT_JOB

echo '[+] Cleaning up downloaded files ...'
rm -r 'kde-qt5' "qtwebkit-${QTWK_VERSION}-alpha4.tar.xz"

echo '[+] Assembling Qt 5 repack ...'
tar xf qt-5.tmp.tar
#tar xf catapult.tmp.tar
COMMIT_DATE="$(cat COMMIT-DATE)" && rm -v COMMIT-DATE
mv -v qt-5.tmp qt-5
rm -r ./qt-5/qtwebengine/src/3rdparty/chromium/third_party/catapult
mkdir -p ./qt-5/qtwebengine/src/3rdparty/chromium/third_party/catapult
tar xf catapult.tmp.tar -C ./qt-5/qtwebengine/src/3rdparty/chromium/third_party/catapult
rm -v "qtwebkit-${QTWK_VERSION}-alpha4"/WebKit.pro
mv -v "qtwebkit-${QTWK_VERSION}-alpha4" ./qt-5/qtwebkit

echo '[+] Compressing final tarball ...'
tar cf "qt-5-5.15.2+wk${QTWK_VERSION}+kde${COMMIT_DATE}.tar" qt-5
xz -9e -T0 "qt-5-5.15.2+wk${QTWK_VERSION}+kde${COMMIT_DATE}.tar"

echo '[+] Cleaning up ...'
rm -r qt-5 catapult catapult.tmp.tar qt-5.tmp.tar
echo '[+] Done!'
