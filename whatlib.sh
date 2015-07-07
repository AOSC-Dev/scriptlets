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