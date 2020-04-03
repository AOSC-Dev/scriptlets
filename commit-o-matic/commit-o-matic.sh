#!/bin/bash
_help_message() {
	printf "\
Useage:

	commit-o-matic PACKAGE_GROUP TYPE [MESSAGE]

	- PACKAGE_GROUP: Path to the list of packages to be committed.
          (Example: TREE/groups/plasma)
	- TYPE: type of the desired operation (update or bump-rel)
	- [MESSAGE]: if TYPE=bump-rel, you need to specify why. Input reason here.

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

if [ -z "$2" ]; then
	echo -e "[!!!] Please specify an operation.\n"
	_help_message
	exit 1
fi

# Given a list of packages, automatically commit based on the new version number
if [[ $2 == "update" ]]; then
	for i in $(cat $1); do
    		git add --all $i
    		git commit -m "${i##*/}: update to $(grep "VER=" $i/spec | cut -d "=" -f2)"
	done
elif [[ $2 == "bump-rel" ]]; then
	if [ -z "$3" ]; then
		echo -e "[!!!] Need a reason for revision."
		_help_messgae
		exit 1
	fi

	for i in $(cat $1); do
		git add $i/spec
		git commit -m "${i##*/}: $3"
	done
fi
