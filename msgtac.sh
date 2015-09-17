#!/bin/sh
die(){ echo "$1"; exit "${2-1}"; }
## CC0
usage(){
	echo "Usage:	$0 POFILE [OUTPREFIX]
Creates a pair of po files with the same messages in reverse order. \`-' as
stdin is accepted as a special case.

Please be warned that this thing expects blank lines between messages.
Otherwise, let msgcat format it before you feed it in.

Current assumptions expect this script only processes filenames not starting
with \`!' and with messages < 100000."
	exit 1
}

# So bash gives us why there will be a problem automatically!
if [ "$1" && "$1" != '-' ]; then
	exec 4<"$1"
else
	exec 4<&0 && [ "$2" ]
fi || usage

outpre="${2:-$1}"; outpre="${outpre%.po*}"

IFS='' i=0
while read -r line; do case "$line" in
	('')	echo "
#: !DUMMY:$((100000-i))"  >> "$outpre.rev.po"; i=$((i+1));;
	(*) echo "$line" >> "$outpre.rev.po";;
esac; done <&4

msgcat -o "$outpre.rev.po" "$outpre.rev.po"
