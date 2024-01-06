#!/usr/bin/env fish

set --local file_where_function_is_defined (status dirname)/fish/config/functions/link_settings.fish

if not test -e $file_where_function_is_defined
    echo "Could not find link_settings.fish where function is defined."
    exit 1
end

source $file_where_function_is_defined

for d in (find . -type d -name dotfiles -print0 | string split0)
    set --local dotfiles_parent_dir (dirname $d)

    echo "Linking dotfiles in $dotfiles_parent_dir"

    link_settings dotfiles $d
end
