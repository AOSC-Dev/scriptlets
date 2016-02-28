#!/bin/bash
# certainly useless stuffs

# Prototype!
_ancient_getlongopts(){
	declare -A OPTLONG
	OPTLONG[verbose]=v
	OPTLONG[quiet]=q
	OPTLONG[help]=H
	OPTLONG[wait]=W:
	OPTLONG['--']=--
	local OPTIONS=("$@")
	declare -p OPTIONS
	while getopts 'vqhHW:-:' OPT; do
		case "$OPT"	in
			(-)	_ancient_longopt_handler;;
			(*)	_opt_handler_$OPT "$OPTARG";;
		esac
	done
}
_ancient_longopt_handler(){
	local OPTEXPD="${OPTLONG[$OPTARG]}"
	case "$OPTEXPD" in
		(--)	echo "Unrecognized longopt $OPTARG" >&2; return 1;;
		(*::)	echo "Unsupported argument count $OPTARG">&2; return 1;;
		(*:)	((++OPTIND)); _opt_handler_${OPTEXPD::-1} "${OPTIONS[$OPTIND]}";;
		(*)		_opt_handler_$OPTEXPD;;
	esac
}

# shsplit "str" -> _shsplit_out[]
# shlex.split()-like stuff
# what, implementing that 'disregard quotes mid-token'? No.\
# robustness note: many end-quote replacments should test for the existance of the pattern first,
# and return 42 if patt not present.
# fixme: backslash even-odd not checked in patterns! this is fatal.
#	 You will need to have an extra var to hold ${tmp##[!\\]} and count.
shsplit(){
	_shsplit_out=()
	shopt -s extglob
	local _shsplit_ksh_cquote=1 _shsplit_bash_moquote=1
	local i="$1" thisword='' tmp='' dquote_ret
	# debug tip: set -xv freaks out for `[['.
	while [[ $i ]]; do
		case $i in
			"'"*)	# single quote, posix.1:2013v3c2s2.2.2
				i=${i#\'}
				# use till first "'"
				tmp=${i%%\'*}
				i=${i#"$tmp"\'}
				thisword+=$tmp
				;;
			"\""*)	# double quote, posix.1:2013v3c2s2.2.2
				_shsplit_dquote
				thisword+=$dquote_ret
				;;
			"$'"*)	# bash s3.1.2.4
				i=${i#'$'}
				if ((_shsplit_ksh_cquote)); then
					i=${i#\'}
					# dquote & norm magic
					tmp=${i%%!(!(\\)\\)\'*}
					i=${i#"$tmp"}
					tmp=${i:0:2}
					i=${i:3}
					# I am too lazy to play with you guys. Go get it, eval.
					eval "thisword+=$'$tmp'"
				else
					thisword+=\$
				fi
				;;
			'$"'*)	# bash s3.1.2.5
				i=${i#'$'}
				if ((_shsplit_bash_moquote)); then
					_shsplit_dquote
					if ((_shsplit_bash_moquote == 2)); then
						# re-escape. dirty, right?
						# only do this when you fscking trust the input.
						# no, I will not escape \$ and \` for you.
						dquote_ret=${dquote_ret//\\/\\\\}
						dquote_ret=${dquote_ret//\"/\\\"}
						eval 'dquote_ret=$"'"$dquote_ret\""
					# elif 3: gettext() .....
					fi
					thisword+=$dquote_ret
				else
					thisword+=\$
				fi
				;;
			[[:space:]]*)
				[[ $thisword ]] && _shsplit_out+=("$thisword")
				thisword=''
				i=${i##+([[:space:]])}
				;;
			*)
				_shsplit_eat_till_special
				;;
		esac
	done
	[[ $thisword ]] && _shsplit_out+=("$thisword")
}

_shsplit_eat_till_special(){
	local thisword2
	tmp=${i%%!(\\)[\$\'\"[:space:]]*}	# first non-escaped crap
	i=${i#"$tmp"}
	tmp=${i:0:1}				# add back the extra !(\\) char killed
	i=${i:1}
	_shsplit_soft_backslash
	thisword+=$thisword2
}

_shsplit_dquote(){
	local thisword2
	i=${i#\"}
	tmp=${i%%!(!(\\)\\)\"*}		# first non-escaped "
	i=${i#"$tmp"}
	tmp=${i:0:2}			# add back the extra !(!(\\)\\) chars killed
	i=${i:3}			# kill three -- including "
	_shsplit_soft_backslash
	dquote_ret=$thisword2
}

_shsplit_soft_backslash(){
	local tmp2
	while [[ $tmp ]]; do
		case $tmp in
			'\\'*)
				tmp=${tmp#'\\'}
				thisword2+='\'
				;;
			'\'$'\n'*)
				tmp=${tmp#'\'$'\n'}
				;;
			'\'*)	# means nothing
				tmp=${tmp#'\'}
				;&	# fallthru
			*)
				tmp2=${tmp%%\\*}
				tmp=${tmp#"$tmp2"}
				thisword2+=$tmp2
				;;
		esac
	done
}
