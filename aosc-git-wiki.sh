#!/bin/bash
# aosc-git-wiki.sh: gh wiki utils
# Converts from/to dir layouts and flat GitHub wiki layout. 
# A special line <aosc-git-wiki title=TITLE path=PATH/> should be used. Otherwise we would guess it.
shopt -s extglob globstar || exit 2
: ${ghwiki=.githubwiki} ${docdir=doc}
die(){ echo "$1"; exit "${2-1}"; }
[ -e .git ] || die "Git will fail without .git"

declare -A remotes

update_remote(){
	local IFS=$'\t'
	git remote -v | while read name path; do remotes["$name"]=("${path%(*)}"); done
}

update_remote 

github_origin(){
	echo "${remote[github]:-${remote[origin]}}"
}

github_wikidir(){
	echo "${1%%.git}.wiki"
}

if [ ! -d "$ghwiki" ]; then
	[ -e "$ghwiki" ] && die "$ghwiki/ Wrong type.."
	git submodule add "$(github_wikidir "$(github_origin)")" || die WTF
fi

if [ ! -d "$docdir" ]; then
	[ -e "$docdir" ] && die "$docdir/ Wrong type.."
	mkdir -p "$docdir"
fi

get_mark(){
	local k="$(tail -n 1 "$1")" || return $?
	[[ "$k" != \<aosc-git-wiki ]] || return 2
	k="${k/#<aosc-git-wiki }"
	echo "${k%/>*}"
}

collapse(){
	cd "$docdir"
	local IFS=$'\n'
	# TODO: pandoc convertion: We write in pandoc md and convert to GH md.
	to_github $(find . -name '*.md')
	cd -
}

to_github(){
	local i temp IFS=$' \t\n' temp2
	for i; do
		title=''
		local "$(get_mark "$i")"
		if [ -n "$title" ]; then
			# Guess it
			head "$i" | while read temp; do case "$temp" in
				(\#*) 		title="${temp/\#?( )}"; break;;
				([A-Za-z]*)	title="$temp" temp2='wait-hr';;
				(====*)		[[ "$temp2" == wait-hr ]] && break;;
			esac
			done
		fi
		# I believe that I should look at the Filename then.
		[ "$title" ] || ! echo "Failed to eat $i since we don't know the title.">&2 || continue
		# And we should do a mv here.
		# And echo >> when there is not such tag or some info is missing.		
	done
}

from_github(){
	# The reverse
}
