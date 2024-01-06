function fish_title

    # regex hack on built-in varible $hostname because subcommand
    # execution of hostname -s breaks showing the prompt
    set hostname_short (string match --regex '([\w-]+)\.?' -- $hostname)[2]

    if set --query TMUX
        set prefix ""
    else
        set prefix "|$hostname_short| "
    end

    if set --query argv[1]
        echo "$prefix$argv"
    else
        echo $prefix(fish_prompt_pwd_dir_length=1 prompt_pwd)
    end
end
