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
# what, implementing that 'disregard quotes mid-token'? No.
shsplit(){
	_shsplit_out=()
	shopt -s extglob
	local _shsplit_ksh_cquote=1 _shsplit_bash_moquote=1
	local i="$1" thisword='' tmp='' dquote_ret
	while [[ $i ]]; do
		case $i in
			"'"*)	# single quote, posix.1:2013v3c2s2.2.2
				i=${i#\'}
				# use till first "'"
				tmp+=${i%%\'*}
				i=${i#"$tmp"}
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
					tmp+=${i%%\'*}
					i=${i#"$tmp"}
					# \' crap this time
					while [[ $tmp == *!(\\)\\ ]]; do
						tmp+=\'${i%%\'*}
						i=${i#"$tmp"}
					done
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
						dquote_ret=${dquote_ret//\\/\\\\}
						dquote_ret=${dquote_ret//\"/\\\"}
						eval 'dquote_ret=$"'"$dquote_ret\""
					# elif 3: gettext() .....
					fi
					thisword+=$dquote_ret
				else
					thisword+=\$
				fi
			[[:space:]]*)
				i=${i##+([[:space:]])}
				;;
			*)
				_shsplit_eat_till_special
				;;
		esac
	done
}

_shsplit_eat_till_special(){
	tmp=${i%%[\$\'\"[:space:]]}
	i=${i#"$tmp"}
	thisword+=$tmp
}

_shsplit_dquote(){
	local thisword2 tmp2
	i=${i#\"}
	# as naive as squote
	tmp=${i%%\"*}
	i=${i#"$tmp"}
	# now resolve \" crap
	while [[ $tmp == *!(\\)\\ ]]; do
		tmp+=\"${i%%\"*}
		i=${i#"$tmp"}
	done
	# resolve \\ and \$'\n'
	thisword2=''
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
	dquote_ret=$thisword2
}
