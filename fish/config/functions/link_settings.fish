function link_settings \
    --description "Symlink settings to location based on folder structure"

    argparse 'n/dry-run' 'h/help' -- $argv
        or return

    if test (count $argv) -ne 2
        __link_settings_help
        return 1
    end

    set -l subdirectory $argv[1]
    set -l settings_dir $argv[2]

    set -l full_settings_dir_path (realpath $settings_dir)

    if set -q _flag_help
        __link_settings_help
        return 0
    end

    switch $subdirectory
        case 'dotfiles'
            set -l full_dotfiles_dir_path "$full_settings_dir_path/dotfiles"
            if test -e "$full_dotfiles_dir_path"
                __link_dotfiles (if set -q _flag_dry_run; echo '--dry-run'; end) "$full_dotfiles_dir_path"
            end
        case 'home'
            set -l full_home_dir_path "$full_settings_dir_path/home"
            if test -e "$full_home_dir_path"
                __link_home (if set -q _flag_dry_run; echo '--dry-run'; end) "$full_home_dir_path"
            end

        case 'root'
            set -l full_root_dir_path "$full_settings_dir_path/root"
            if test -e "$full_root_dir_path"
                __link_root (if set -q _flag_dry_run; echo '--dry-run'; end) "$full_root_dir_path"
            end
        case '*'
            __link_settings_help
    end

end

function __link_settings_help
    printf '%s\n' \
    'Usage: link_settings [options] subdirectory directory_to_link' \
    '' \
    'Subdirectories:' \
    '  dotfiles' \
    '  home' \
    '  root' \
    '' \
    'Options:' \
    '  -n or --dry-run  Only show what would be linked' \
    '  -h or --help     Print this help message'
end

function __link_file
    argparse --min-args=2 --max-args=2 'n/dry-run' -- $argv
        or return

    set -l source_file_path $argv[1]
    set -l destination_file_path $argv[2]

    if not test -e $destination_file_path
        echo "ln -s $source_file_path $destination_file_path"
        if not set -q _flag_dry_run
            ln -s $source_file_path $destination_file_path
        end
    else if test -L $destination_file_path
        echo "$destination_file_path already links to "(realpath "$destination_file_path")
    else
        echo "$destination_file_path file already exists"
    end
end

set -g _LINK_SETTINGS_EXCLUDE_FILES '.DS_Store' 'test'

function _find_exclude_parameters
    echo '-not -iname \''{$_LINK_SETTINGS_EXCLUDE_FILES}'\' '
end

function __link_dotfiles \
    --description 'Symlinks files prepending direct child files and folders of directory names with a dot to $HOME'

    argparse 'n/dry-run' -- $argv
        or return

    set -l full_dotfiles_dir_path $argv[1]

    echo "Linking $full_dotfiles_dir_path..."

    # echo "find $full_dotfiles_dir_path -type f \( "(_find_exclude_parameters)" \) -print0"

    for source_file_path in (find $full_dotfiles_dir_path -type f -not -name '.DS_Store' -print0 | string split0)
        set -l destination_file_path (string replace --regex "$full_dotfiles_dir_path/([^/]+)" "$HOME/.\$1" -- $source_file_path)

        set dotfile_dir_path (path dirname $destination_file_path)

        if ! test -e $dotfile_dir_path
            mkdir -p $dotfile_dir_path
        end

        if test -e $destination_file_path -a ! -L $destination_file_path
            rm $destination_file_path
        end

        __link_file (if set -q _flag_dry_run; echo '--dry-run'; end) $source_file_path $destination_file_path
    end
end

function __link_home \
    --description 'Symlinks files to $HOME'

    argparse 'n/dry-run' -- $argv
        or return

    set -l full_home_dir_path $argv[1]

    echo "Linking $full_home_dir_path..."

    # echo "find $full_home_dir_path -type f \( "(_find_exclude_parameters)" \) -print0"

    for source_file_path in (find $full_home_dir_path -type f -not -name '.DS_Store' -print0 | string split0)
        set -l destination_file_path (string replace --regex "$full_home_dir_path" "$HOME" -- $source_file_path)

        __link_file (if set -q _flag_dry_run; echo '--dry-run'; end) $source_file_path $destination_file_path
    end
end

function __link_root \
    --description 'Symlinks files to /'

    argparse 'n/dry-run' -- $argv
        or return

    set full_root_dir_path $argv[1]

    if test (id -u) -ne 0
        echo "-r/--root must be run as root"
        return 1
    end

    echo "Linking $full_root_dir_path..."

    for source_file_path in (find $full_root_dir_path -type f -not -name '.DS_Store' -print0 | string split0)
        set destination_file_path (string replace --regex "$full_root_dir_path" "" -- $source_file_path)

        __link_file (if set -q _flag_dry_run; echo '--dry-run'; end) $source_file_path $destination_file_path
    end
end
