#!/bin/bash -e

# KDE Qt source repository.
KDE_QT_REPO='https://invent.kde.org/qt/qt/qt5'
KDE_QT_BANNED_MODULES=('qtcanvas3d' 'qtfeedback' 'qtpim' 'qtqa' 'qtrepotools' 'qtsystems' 'qtdocgallery')
# Catapult source repository.
CATAPULT_REPO='https://chromium.googlesource.com/catapult'
# QtWebEngine source repository.
QTWEBENGINE_REPO='https://code.qt.io/qt/qtwebengine'
# QtWebKit source archive
QTWK_URL="https://github.com/qtwebkit/qtwebkit/releases/download/qtwebkit-${QTWK_VERSION}-alpha4/qtwebkit-${QTWK_VERSION}-alpha4.tar.xz"

GIT_ARCHIVE_BIN="git-archive-all"

clone_kde_qt() {
    echo 'Cloning Qt 5 KDE fork sources ...'
    git clone "${KDE_QT_REPO}" 'kde-qt5'
    cd kde-qt5
    git checkout -f "${KDE_QT_COMMIT}"
    local COMMIT_TIMESTAMP="$(git log -1 --format=%ct)"
    date --date "@${COMMIT_TIMESTAMP}" '+%Y%m%d' > ../COMMIT-DATE
    echo '[+] Unregistering unwanted Qt components ...'
    git rm -rf "${KDE_QT_BANNED_MODULES[@]}"
    echo '[+] Replacing QtWebEngine submodule ...'
    git submodule set-url qtwebengine "${QTWEBENGINE_REPO}"
    echo '[+] Cloning Qt components ...'
    git submodule update --recursive --init --jobs 4
    echo '[+] Checking out QtWebEngine ...'
    git -C qtwebengine checkout -f tags/v"${QTWEBENGINE_VERSION}"-lts
    echo '[+] Committing changes ...'
    git add .gitmodules qtwebengine
    git config --local user.name 'Bot'
    git config --local user.email 'bot@aosc.io'
    git commit -m "[AUTO] Sync QtWebEngine to ${QTWEBENGINE_VERSION}"
    git submodule update --recursive --init
    echo '[+] Archiving Git repository using git-archive-all ...'
    "${GIT_ARCHIVE_BIN}" --force-submodules ../qt-5.tmp.tar
    cd ..
}

fetch_webkit() {
    echo '[+] Fetching Qt Webkit ...'
    wget "${QTWK_URL}"
    tar xf "qtwebkit-${QTWK_VERSION}-alpha4.tar.xz"
}

[[ x"${QT_VERSION}" = "x" ]] && echo "QT_VERSION not set." && exit 1
[[ x"${QTWEBENGINE_VERSION}" = "x" ]] && echo "QTWEBENGINE_VERSION not set." && exit 1
[[ x"${QTWK_VERSION}" = "x" ]] && echo "QTWK_VERSION not set. Go to https://github.com/qtwebkit/qtwebkit/tags to figure it out." && exit 1
[ -z "${KDE_QT_COMMIT}" ] && echo "KDE_QT_COMMIT not set. Go to https://invent.kde.org/qt/qt/qt5/-/tree/kde/5.15 to figure it out." && exit 1

echo '[+] Performing pre-repack clean-up ...'
rm -rf \
     'catapult' \
     'kde-qt5' \
     'qtwebengine' \
     "qtwebkit-${QTWK_VERSION}-alpha4.tar.xz" \
     "qt-5-${QT_VERSION}+webengine${QTWEBENGINE_VERSION}+wk${QTWK_VERSION}+kde"*.tar* \
     "qt-5.tmp.tar" \
     "qtwebengine.tmp.tar"

echo '[+] Installing git-archive-all utility ...'
pip3 install --user --upgrade git-archive-all
"${GIT_ARCHIVE_BIN}" --version

clone_kde_qt &
KDE_QT_JOB="$!"

fetch_webkit &
WEBKIT_JOB="$!"

wait $KDE_QT_JOB $WEBKIT_JOB

echo '[+] Cleaning up downloaded files ...'
rm -rf 'catapult' 'kde-qt5' "qtwebkit-${QTWK_VERSION}-alpha4.tar.xz"

echo '[+] Assembling Qt 5 repack (main sources) ...'
tar xf qt-5.tmp.tar
KDE_QT_COMMIT_DATE="$(cat COMMIT-DATE)" && rm -v COMMIT-DATE
mv -v qt-5.tmp qt-5

echo '[+] Assembling Qt 5 repack (QtWebKit) ...'
rm -v "qtwebkit-${QTWK_VERSION}-alpha4"/WebKit.pro
mv -v "qtwebkit-${QTWK_VERSION}-alpha4" ./qt-5/qtwebkit

echo '[+] Running syncqt.pl for module headers ...'
cd qt-5
for i in $(find . -maxdepth 1 -type d -name "qt*"); do
    ./qtbase/bin/syncqt.pl -version "${QT_VERSION}" "$i" || true
done
cd ..

echo '[+] Compressing final tarball ...'
tar cf "qt-5-${QT_VERSION}+webengine${QTWEBENGINE_VERSION}+wk${QTWK_VERSION}+kde${KDE_QT_COMMIT_DATE}.tar" qt-5
xz -9e -T0 "qt-5-${QT_VERSION}+webengine${QTWEBENGINE_VERSION}+wk${QTWK_VERSION}+kde${KDE_QT_COMMIT_DATE}.tar"

echo '[+] Cleaning up ...'
rm -rf qt-5 qt-5.tmp.tar

echo '[+] Done!'
