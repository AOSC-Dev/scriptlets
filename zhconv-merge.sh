#!/bin/bash
# zhconv-merge.sh: Merge zh variant translations with OpenCC and msgmerge.
# Usage: ./zhconv-merge.sh OLD_FILE MERGE_ME_IN [POT_FILE]

# This script comes with ABSOLUTELY NO WARRENTY, and can be used as if it is in
# public domain, or (optionally) under the terms of CC0, WTFPL or Unlicense.

# Please make sure that there is no Chinese characters in msgid; or bad things
# will happen when opencc converts them by mistake.
# Also, don't pass non-UTF8 files in.

die(){ echo "Fatal:	$1">&2; exit "${2-1}"; }

[ "$2" -a -e "$1" -a -e "$2" ] || die "Arguments invalid"
type opencc sed msgmerge >/dev/null || die "required command(s) not found"

# Accept environment 'linear array' input.
declare -a MSGMERGE_FLAGS="${MSGMERGE_FLAGS:-(--backup=nil)}"

# OpenCC example cfgs used, all with Phrace Variants:
#  s2twp: CN -> TW
#  tw2sp: TW -> CN
#  s2hk:  CN -> HK
#  hk2s:  HK -> CN

# Extra sed commands for conversion.
to_cn_sed=(
  -e 's/函式/函数/g' # function
  -e 's/封存/归档/g' # archive
  -e 's/开启/打开/g' # open
  -e 's/命令稿/脚本/g' # script
  # -e 's/「/ “/g' -e 's/」/” /g' -e 's/『/ ‘/g' -e 's/』/’ /g' # crude quoting
)

from_cn_sed=(
  -e 's/函数/函式/g' # function
  -e 's/归档/封存/g' # archive
)

zhvar(){
	case "$1" in
		(*.zh_CN.po*)	echo "CN";;
		(*.zh_TW.po*)	echo "TW";;
		(*.zh_HK.po*)	echo "HK";;
		(*)	echo "?" ;;
	esac
}

occcfg(){
	case "$1,$2" in
		(CN,TW)	echo s2twp;;
		(TW,CN)	echo tw2sp;;
		(CN,HK)	echo s2hk;;
		(HK,CN)	echo hk2s;;
		(*)		die "Specified pair $oldtype，$newtype not supported."$'\n\t'\
				"Consider implementing chain conversion yourself."
	esac
}

old="$1" oldtype="$(zhvar "$old")"
new="$2" newtype="$(zhvar "$new")"
pot="${3:-$2}"

echo "
OLD	$oldtype	$old
NEW	$newtype	$new
POT	--	$pot
"

case "$newtype" in
	(CN)	sed "${from_cn_sed[@]}" "$new" > "$new.$oldtype";;
	(*) 	cp "$new" "$new.$oldtype"
esac


opencc -c "$(occcfg "$newtype" "$oldtype")" -i "$new.$oldtype" -o "$new.$oldtype" ||
	die "opencc returned $?."

msgmerge -C "$new.$oldtype" "${MSGMERGE_FLAGS[@]}" -U "$old" "$pot" ||
	die "msgmerge returned $?."

case "$oldtype" in
	(CN)	sed -i.pre_final "${to_cn_sed[@]}" "$old"
esac

echo "
OUT	$oldtype	$old
TMP	$oldtype	$new.$oldtype
SED	$oldtype	$old.pre_final

Verify the results in a po editor, with some basic knowledge in zh_$oldtype."
