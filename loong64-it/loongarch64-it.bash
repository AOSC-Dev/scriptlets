#!/bin/bash
# A simple loong64 => loongarch64 .deb converter to help traverse the worlds.
#
# Mingcong Bai <jeffbai@aosc.io>, 2024

_display_usage() {
	printf "\
Usage:

	loong64-it [PACKAGE1] [PACKAGE2] ...

        - PACKAGE{1..N}: Path to the new-world .deb package to convert.

"
}

# Autobuild-like echo functions.
abwarn() { echo -e "[\e[33mWARN\e[0m]:  \e[1m$*\e[0m"; }
aberr()  { echo -e "[\e[31mERROR\e[0m]: \e[1m$*\e[0m"; exit 1; }
abinfo() { echo -e "[\e[96mINFO\e[0m]:  \e[1m$*\e[0m"; }
abdbg()  { echo -e "[\e[32mDEBUG\e[0m]: \e[1m$*\e[0m"; }

_convert_loong64() {
	abinfo "Examining package information: $1 ..."
	dpkg -I "$SRCDIR"/$1 || \
		aberr "Invalid dpkg package: control (metadata) archive not found: $?"
	CONTROL_EXT="$(ar t "$SRCDIR"/$1 | grep control.tar* | cut -f3 -d'.')"
	case "${CONTROL_EXT}" in
		gz)
			TAR_COMP_FLAG="z"
			;;
		xz)
			TAR_COMP_FLAG="J"
			;;
		bz2)
			TAR_COMP_FLAG="j"
			;;
		"")
			TAR_COMP_FLAG=""
			;;
		*)
			aberr "Invalid control archive extension ${CONTROL_EXT}!"
			;;
	esac

	abinfo "Unpacking: $1 ..."
	cd $(mktemp -d) || \
		aberr "Failed to create temporary directory to unpack $1: $?."
	DEBDIR="$(pwd)"
	ar xv "$SRCDIR"/$1 || \
		aberr "Failed to unpack $1: $?."

	abinfo "Unpacking metadata archive: $1 ..."
	mkdir "$DEBDIR"/metadata || \
		aberr "Failed to create temporary directory for extracting the metdata archive from $1: $?."
	tar -C "$DEBDIR"/metadata -xvf control.tar."${CONTROL_EXT}" || \
		aberr "Failed to unpack metadata archive from $1: $?."

	abinfo "Converting dpkg Architecture key: $1 ..."
	if ! egrep '^Architecture: loong64$' "$DEBDIR"/metadata/control; then
		aberr "Failed to detect a \"loong64\" architecture signature in control file - this is not a valid new-world LoongArch package!"
	fi
	sed -e 's|^Architecture: loong64$|Architecture: loongarch64|g' \
	    -i "$DEBDIR"/metadata/control

	abinfo "Building metadata archive (control.tar.${CONTROL_EXT}): $1 ..."
	cd "$DEBDIR"/metadata
	tar cvf${TAR_COMP_FLAG} "$DEBDIR"/control.tar."${CONTROL_EXT}" * || \
		aberr "Failed to build metadata archive (control.tar.${CONTROL_EXT}) for $1: $?."
	cd "$DEBDIR"

	abinfo "Rebuilding dpkg package $1: loongarch64 ..."
	ar rv "$SRCDIR"/$1 control.tar.${CONTROL_EXT} || \
		aberr "Failed to rebuild dpkg package $1: $?."

        #abinfo "Cleaning up: $1 ..."
        #rm -r "$DEBDIR"

	abinfo """Your requested package:

    $1

Has been successfully converted as a loongarch64 package!
"""
}

# Display usage info if `-h' or `--help' is specified.
if [[ "$1" == "-h" || "$1" == "--help" ]]; then
	_display_usage
	exit 0
fi

# Display usage info with directions if no option is specified.
if [ -z "$1" ]; then
	abwarn "Please specify package(s) to convert.\n"
	_display_usage
	exit 1
fi

# Record working directory.
SRCDIR="$(pwd)"

# Rebuilding all requested packages.
for i in "$@"; do
	_convert_loong64 $i
done
