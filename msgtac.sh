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
if [ "$1" ] && [ "$1" != '-' ]; then
	exec 4<"$1"
else
	exec 4<&0 && [ "$2" ]
fi || usage

outpre="${2:-$1}"; outpre="${outpre%.po*}"

IFS='' i=0 BUF=''
if ( _variable+=syntax_test ) >/dev/null 2>&1 &&
       { [ -z "$MSGTAC_NO_PLUSEQ" ] || [ "$MSGTAC_NO_PLUSEQ" == "0" ]; }; then
while read -r line; do case "$line" in
	('')	BUF+="
#: !DUMMY:$((100000-i))" i=$((i+1));;
	(*) BUF+="
$line";;
esac; done <&4
else
while read -r line; do case "$line" in
	('')	BUF="$BUF
#: !DUMMY:$((100000-i))" i=$((i+1));;
	(*) BUF="$BUF
$line";;
esac; done <&4
fi

printf '%s\n' "$BUF" | msgcat -F -o "$outpre.rev.po" -
