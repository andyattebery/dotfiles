#!/bin/sh

# pass in git repo using git scheme (i.e. install_vim_plugin.sh git@github.com:tpope/vim-sensible.git)

plugin_name=$(basename -s .git $1)

git submodule add $1 config/vim/pack/packages/start/"$plugin_name"