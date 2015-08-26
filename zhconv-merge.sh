#!/bin/bash
# zhconv-merge.sh: Merge zh variant translations with OpenCC and msgmerge.

usage="Usage:	$0 OLD_FILE MERGE_ME_IN [POT_FILE=MERGE_ME_IN]
	if OLD_FILE is missing, assume creation of new file.

Env vars:
	ZH_MSGMERGE_OPTS	\`linear' array of extra flags for \`msgmerge'.
	Example:		'(-E -C \"my compendia.po\" -w 79 --previous)'
	Default:		'(--backup=nil)'

	ZH_POST_OCC:function	What to do after invoking OpenCC. To use,
				define a function with this name in bash,
				and export it with \`export -f ZH_POST_OCC'.
	Example:		ZH_POST_OCC() { msgattrib --set-fuzzy \\
				--no-fuzzy -o \"\$new.\$oldtype\"{,}; }
"

# This script comes with ABSOLUTELY NO WARRENTY, and can be used as if it is in
# public domain, or (optionally) under the terms of CC0, WTFPL or Unlicense.

# Please make sure that there is no Chinese characters in msgid; or bad things
# will happen when opencc converts them by mistake.
# Also, don't pass non-UTF8 files in.
readonly {FALSE,NO,false,no}=0 {TRUE,YES,true,yes}=1 # boolean shorthands
die(){ echo "Fatal:	$1">&2; exit "${2-1}"; }
info(){ echo "Info:	$*">&2; }

[ "$2" -a -e "$2" ] || die "Arguments invalid

$usage"

type opencc sed msgmerge >/dev/null || die "required command(s) not found"

# Accept environment 'linear array' input.
declare -a ZH_MSGMERGE_OPTS="${ZH_MSGMERGE_OPTS:-(--backup=nil)}"

type ZH_POST_OCC &>/dev/null || ZH_POST_OCC(){ :; }

# OpenCC example cfgs used, all with Phrace Variants:
#  s2twp: CN -> TW
#  tw2sp: TW -> CN
#  s2hk:  CN -> HK
#  hk2s:  HK -> CN

# Extra sed commands for conversion.
to_cn_sed=(
  -r # ERE for grouping
  -e 's/函式/函数/g' # function
  -e 's/封存/归档/g' # archive
  -e 's/开启/打开/g' # open
  -e 's/命令稿/脚本/g' # script
  -e 's/盘案/文件/g' # file (save)
  -e 's/回传/返回/g' # return (function)
  -e 's/引数/参数/g' # argument (function)
  -e 's/签章/签名/g' # signature (PGP)
  -e 's/巨集/宏/g' # macro
  -e 's/魔术字符/幻数/g' # magic number
  -e 's/唯读/只读/g' # readonly
  -e 's/胚腾/模式/g' # pattern, un-standardly translated to 胚腾 in TW sometimes.
  -e 's/逾時/超时/g' # timed out
  -e 's/相依性/依赖关系/g' -e 's/相依/依赖/g' # dependency (pkgmgr)
  -e 's/万用匹配/通配符/g' -e 's/万用字符/通配符/g' # glob
  -e 's/([二八十]|十六)进位制?/\1进制/g' # bin, oct, dec, hex..
# -e 's/修补/补丁/g' # patch
# -e 's/套件/软件包/g' # package
  -e 's/不容许/不允许/g' # not permitted
  -e 's/暂存盘/临时文件/g' # tmpfile, word_struct (暂存 盘)
# -e 's/缩减/归约/g' # reduce (parser)
  -e 's/算子/算符/g' # operator (parser)
  -e 's/全域/全局/g' # global
  -e 's/做为/作为/g' # foo as(作为) bar
# -e 's/「/ “/g' -e 's/」/” /g' -e 's/『/ ‘/g' -e 's/』/’ /g' # crude quoting
)

from_cn_sed=(
  -e 's/函数/函式/g' # function
  -e 's/归档/封存/g' # archive
  -e 's/宏/巨集/g' # macro
  -e 's/只读/唯读/g' # readonly
  -e 's/全局/全域/g' # global
)

zhvar(){
	case "$1" in
		(*.zh_CN.po*)	echo "CN";;
		(*.zh_TW.po*)	echo "TW";;
		(*.zh_HK.po*)	echo "HK";;
		(*)	echo "??" ;;
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

if [ ! -e "$old" ]; then
	info "Creating $old."
	:> "$old"
fi

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

ZH_POST_OCC

msgmerge -C "$new.$oldtype" --lang="zh_$oldtype" "${ZH_MSGMERGE_OPTS[@]}" -U "$old" "$pot" ||
	die "msgmerge returned $?."

case "$oldtype" in
	(CN)	sed -i.pre_final "${to_cn_sed[@]}" "$old"
			OUTFILES+="SED	$oldtype	$old.pre_final"$'\n'
esac

echo "
OUT	$oldtype	$old
TMP	$oldtype	$new.$oldtype
$OUTFILES
Verify the results in a po editor, with some basic knowledge in zh_$oldtype."
