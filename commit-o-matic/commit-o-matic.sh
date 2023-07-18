#!/bin/bash
export GIT_COMMIT_AFTER
aberr()  { echo -e "[\e[31mERROR\e[0m]: \e[1m$*\e[0m"; }
abinfo() { echo -e "[\e[96mINFO\e[0m]:  \e[1m$*\e[0m"; }
abdbg()  { echo -e "[\e[32mDEBUG\e[0m]: \e[1m$*\e[0m"; }

_help_message() {
	printf "\
Usage:

	commit-o-matic PACKAGE_GROUP TYPE [MESSAGE]

	- PACKAGE_GROUP: Path to the list of packages to be committed.
          (Example: TREE/groups/plasma)
	- TYPE: type of the desired operation (new, update, or bump-rel)
	- [MESSAGE]: if TYPE=bump-rel, you need to specify why. Input reason here.

"
}

## Outputs an array constrcuted from groupfile
_pkglist_comment_parser() {
	PATH_TO_GROUPFILE=$1
#	if [ ! -a "$1" ]; then
#		aberr "Groupfile does not exist: ${1}"
#		return 1
#	fi
	PKGLIST_PARSED=$(sed "s|#.*$||g" $1)
	echo $PKGLIST_PARSED
}

if [[ "$1" == "--help" || "$1" == "-h" ]]; then
	_help_message
	exit 0
fi

if [ -z "$1" ]; then
	aberr "Please specify a package group.\n"
	_help_message
	exit 1
fi

if [ -z "$2" ]; then
	aberr "Please specify an operation.\n"
	_help_message
	exit 1
fi

# Given a list of packages, automatically commit based on the new version number
if [[ $2 == "update" ]]; then
	for i in $(_pkglist_comment_parser $1); do
    		git add --all $i
    		git commit -m "${i##*/}: update to $(grep "VER=" $i/spec | cut -d "=" -f2)" $GIT_COMMIT_AFTER
	done
elif [[ $2 == "new" ]]; then
	for i in $(_pkglist_comment_parser $1); do
		git add --all $i
		git commit -m "${i##*/}: new, $(grep "VER=" $i/spec | cut -d "=" -f2)" $GIT_COMMIT_AFTER
	done
elif [[ $2 == "bump-rel" ]]; then
	if [ -z "$3" ]; then
		aberr "Need a reason for revision.\n"
		_help_messgae
		exit 1
	fi

	for i in $(_pkglist_comment_parser $1); do
		git add --all $i
		git commit -m "${i##*/}: $3" $GIT_COMMIT_AFTER
	done
fi
