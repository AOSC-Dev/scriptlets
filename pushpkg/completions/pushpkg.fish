function __pushpkg_complete_username
    echo "$PUSHPKG_USERNAME" && whoami
end

function __pushpkg_complete_branch
    string replace "OUTPUT-" "" (basename "$PWD")
end

complete -c pushpkg -s h -l help -d 'Print help information'
complete -c pushpkg -s f -l force-push-noarch-package -d 'Force Push noarch package'
complete -c pushpkg -s d -l delete -d 'Clean OUTPUT directory after finishing uploading'
complete -c pushpkg -s r -l retro -d 'Push to AOSC OS/Retro repo'
complete -c pushpkg -s v -l verbose -d 'Enable verbose logging for ssh and rsync'
complete -xc pushpkg -n "__fish_is_nth_token 1" -a "(__pushpkg_complete_username)" -d 'LDAP username'
complete -xc pushpkg -n "__fish_is_nth_token 2" -a "(__pushpkg_complete_branch)" -d 'AOSC OS update branch'
complete -xc pushpkg -n "__fish_is_nth_token 3" -a "main bsp-sunxi bsp-rk bsp-rpi bsp-qcom" -d 'Repository component'
