#!/bin/bash
# suicide.sh: Running this is quite like ......
# FOR REFERENCE USE ONLY， NOT A LINTER

_grep(){ grep --color=auto -EHnr "$@"; }

# Dunno how to exclude stuffs like `string w' and `something else'.
# I said reference only.
_grep '`[[:alnum:]_]* .*`' *
_grep -A1 '(el(se|if)|then)' * | grep --color=auto -EB1 'true' # [:-]\s*(true|:|false)'
_grep 'echo\s+$[[:alnum:]_]*\s*\|[^|]' *
