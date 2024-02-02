#!/bin/sh
# Usage: diff-deb.sh left.deb right.deb
left=$(mktemp /tmp/diff-deb.XXXXXX)
dpkg --contents $1 | awk '!($2=$3=$4=$5="")' > $left

right=$(mktemp /tmp/diff-deb.XXXXXX)
dpkg --contents $2 | awk '!($2=$3=$4=$5="")' > $right

diff -u $left $right
