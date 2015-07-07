#!/bin/bash
# This analyzer trys to create the appropriate flattened ab3 notition of a
# given build script.
# This is a dump of _misaka_base_brain_tmp_prog.

# We export the special builds as functions that record the calls, and then
# uses a ( subshell ) to let the build script touch the functions.

STEP=0
export PKGDIR='#{PKGDIR}' SRCDIR='#{SRCDIR}'
# BUILD STEPS
# ===========
#
# 0	build_start
# 1	[configure]
# 2	build_ready
# 3	[make]
# 4	build_final
# 5	[make install]
# 6	beyond

shopt -s extglob expand_aliases

export STATES="$(mktemp -d)"

# Sources from the stdin.
__source_stdin(){
	local __tmpf="$(mktemp)"
	echo "$(<&0)" > "$__tmpf"
	. "$__tmpf" "$@"
	rm "$__tmpf"
}

# Note that aliases are expanded as the lines are read.
alias __recordlineno='
	echo -n "${BASH_LINENO[${__LINENO_OVERRIDE:--2}]}	$__detected_type	$__anchor_type	$__anchor_name	$(printf '%q ' "$@")" | tee "$STATES/log" >> "$STATES"/parse
'

./configure(){
	__detected_type=autotools
	__anchor_type=configure
	local __anchor_name="${__anchor_name-./configure}"
	__recordlineno
	exit 0
}

cmake(){
	__detected_type=cmake
	__anchor_type=configure
	local __anchor_name="${__anchor_name-cmake}"
	__recordlineno
	exit 0
}

qmake(){
	__detected_type=qtproject
	__anchor_type=configure
	local __anchor_name="${__anchor_name-qmake}"
	__recordlineno
	exit 0
}

perl(){
	[[ "$1" == Makefile* ]] || return 0
}

python2(){
	case "$1" in
		(build)	;;
		(install)	;;
	esac
}
alias python3='__anchor_name=python3 python2'

make(){

}

command_not_found_handler(){
	local __LINENO_OVERRIDE=-3
	case "$1" in
		(*/configure)
			echo "Resolved command-not-found -> configure" | tee "$STATES/log"
			__anchor_name="$1" ./configure "$@";;
	esac
}

curscript=build
while [ -e "$curscript" ]; do
	# Invoke the currently-cut script
	# Read the last line of $STATE/parse and segment it into the temp dir
	# If there is still something left, go on.
done

exec 4<>"$STATES"/parse
while IFS=$'\t' read -u 4 line type name args; do
	# Do deeper considerations, combine the type guesses
done

# rm -r "$STATES"