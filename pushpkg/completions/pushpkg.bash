#!/bin/bash

_pushpkg_list_username() {
    [ -n "$PUSHPKG_USERNAME" ] && echo "$PUSHPKG_USERNAME"
    whoami
}

_pushpkg_list_branch() {
    local cwd
    cwd="$(basename "$PWD")"
    echo "${cwd/OUTPUT-}"
}

_pushpkg() {
    local cur
    COMPREPLY=()
    cur="${COMP_WORDS[COMP_CWORD]}"

    components="main bsp-sunxi bsp-rk bsp-rpi bsp-qcom"
    options="-v --verbose -d --delete -f --force-push-noarch-package -r --retro -h --help"
    if [[ ${cur} == -* || ${COMP_CWORD} -ge 4 ]] ; then
        COMPREPLY=( $(compgen -W "${options}" -- "${cur}") )
        return 0
    fi
    case "${COMP_CWORD}" in
        1)
        COMPREPLY=( $(compgen -W "$(_pushpkg_list_username)" -- "${cur}") )
        ;;
        2)
        COMPREPLY=( $(compgen -W "$(_pushpkg_list_branch)" -- "${cur}") )
        ;;
        3)
        COMPREPLY=( $(compgen -W "${components}" -- "${cur}") )
        ;;
    esac
}

complete -F _pushpkg -o default pushpkg
