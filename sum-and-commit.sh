#!/usr/bin/bash
# SPDX-License-Identifier: GPL-3.0
set -Eeuo pipefail
trap 'errorHandler "$?" "${FUNCNAME[0]}" "$LINENO"' ERR

error() {
    echo -e "\e[0;31m[ERROR] $*\e[0m" >&2
}

die() {
    error "$*"
    exit 1
}

log() {
    echo -e "\e[0;32m$*\e[0m" >&2
}

errorHandler() {
    echo -e "\e[0;31m[BUG] Line $3 ($2): $1\e[0m" >&2
    exit "$1"
}

getPkgDir() {
    local path
    path="$(find . -mindepth 2 -maxdepth 2 -type d -name "$1" -print -quit)"
    echo "${path#./}"
}

getPkgVer() {
    (
        # shellcheck source=/dev/null
        source "$1"/spec
        echo "$VER"
    )
}

sumAndCommit() {
    local pkg="$1"
    local pkgDir pkgVer
    pkgDir="$(getPkgDir "$pkg")"
    pkgVer="$(getPkgVer "$pkgDir")"

    log "[$pkg] Updated to $pkgVer"

    log "[$pkg] Updating checksum ..."
    abbs-update-checksum "$pkg"

    log "[$pkg] Committing ..."
    git add "$pkgDir"
    git commit -m "$pkg: update to $pkgVer" -- "$pkgDir"

    local commitLog
    commitLog="$(git -c core.abbrev=16 \
        log HEAD \
        --oneline -1 --no-decorate --color=always)"
    log "[$pkg] $commitLog"

    log "[$pkg] SUCCESS!"
}

readarray -t pkgs < <(git status --porcelain | cut -d' ' -f 3 | (grep -E '/spec$' || true) | cut -d'/' -f2)
for pkg in "${pkgs[@]}"; do
    if ! sumAndCommit "$pkg"; then
        error "[$pkg] FAILED"
    fi
done
