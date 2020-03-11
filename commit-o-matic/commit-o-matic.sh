#!/bin/bash
_help_message() {
	printf "\
Useage:

	commit-o-matic PACKAGE_GROUPS

	- PACKAGE_GROUPS: Path to the list of packages. (Example: TREE/groups/plasma)

"
}

if [[ "$1" == "--help" || "$1" == "-h" ]]; then
	_help_message
	exit 0
fi

if [ -z "$1" ]; then
	echo -e "[!!!] Please specify a package group.\n"
	_help_message
	exit 1
fi

# Given a list of packages, automatically commit based on the new version number
for i in $(cat $1); do
    git add --all $i
    git commit -m "${i##*/}: update to $(grep "VER=" $i/spec | cut -d "=" -f2)"
done
