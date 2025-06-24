# Set built-in fish variables
set fish_greeting # Clear the default greeting

# Fundle
if not functions -q fundle; eval (curl -sfL https://git.io/fundle-install); end

# Set base environment variables
set --export DOTFILES_DIR $HOME/dotfiles
set --export HOSTNAME (hostname)

# Set platform environment variables
set --export IS_OS_LINUX false
set --export IS_OS_MACOS false
set --export IS_OS_MACOS_ARM64 false

switch (uname -a)
case 'Linux*'
  set --export IS_OS_LINUX true
case 'Darwin*arm64'
  set --export IS_OS_MACOS_ARM64 true
  set --export IS_OS_MACOS true
case 'Darwin*'
  set --export IS_OS_MACOS true
end

if $IS_OS_MACOS
  # Set DISPLAY so git will use it to determine the --gui switch for tools
  set --export DISPLAY ":0"
end

# Add to PATH
fish_add_path $DOTFILES_DIR/sh/config/bin
test -e $HOME/.local/bin; and fish_add_path "$HOME"/.local/bin
test -e $HOME/scripts; and fish_add_path "$HOME"/scripts

# Add fish/config/functions directories to fish_function_path
for function_dir in (find $DOTFILES_DIR/fish/config/functions -type d -print0 | string split0)
  set --local base_function_dir (basename "$function_dir")

  if test "$base_function_dir" = "functions"
  or command --query "$base_function_dir"
  or test -e "$PYENV_ROOT/shims/$base_function_dir"
  or test "$base_function_dir" = "linux" -a $IS_OS_LINUX
  or test "$base_function_dir" = "macos" -a $IS_OS_MACOS
    set --prepend fish_function_path "$function_dir"
  end
end

# source fish/config/conf.d files
for conf_dir in (find $DOTFILES_DIR/fish/config/conf.d -type d)
  set --local base_conf_dir (basename "$conf_dir")

  if test $base_conf_dir = "conf.d"
  or command -q $base_conf_dir
    for f in (find $conf_dir -type f -name "*.fish" -print0 | string split0)
      source $f
    end
  end
end

# homebrew
if test -e /opt/homebrew
  set --export HOMEBREW_DIR /opt/homebrew
  set --export HOMEBREW_BUNDLE_FILE "$DOTFILES_DIR/homebrew/config/Brewfile"
  /opt/homebrew/bin/brew shellenv | source
end

# dotnet
test -n "$HOMEBREW_DIR"; and type --query dotnet; and set --export DOTNET_ROOT $HOMEBREW_DIR/opt/dotnet/libexec

# golang
test -e "$HOME"/go/bin; and fish_add_path "$HOME"/go/bin

# rbenv
status --is-interactive; and type --query rbenv; and rbenv init - --no-rehash fish | source

# pyenv
status --is-interactive; and type --query pyenv; and pyenv init - fish | source

# bat
type --query batman; and set --export MANPAGER "env BATMAN_IS_BEING_MANPAGER=yes $(which batman)"

# mosh
set --export MOSH_TITLE_NOPREFIX 1

# rsync
set --export RSYNC_RSH 'ssh -o "ControlMaster no" -o "ControlPath /dev/null"'

# tide
# type --query tide; and tide configure --auto --style=Classic --prompt_colors='True color' --classic_prompt_color=Dark --show_time=No --classic_prompt_separators=Angled --powerline_prompt_heads=Sharp --powerline_prompt_tails=Flat --powerline_prompt_style='One line' --prompt_spacing=Compact --icons='Many icons' --transient=No; and tide reload

# iTerm 2 shell integration
test -e {$HOME}/.iterm2_shell_integration.fish ; and source {$HOME}/.iterm2_shell_integration.fish

# Added by LM Studio CLI (lms)
fish_add_path /Users/andy/.lmstudio/bin
# End of LM Studio CLI section

# Added by OrbStack: command-line tools and integration
# This won't be added again if you remove it.
source ~/.orbstack/shell/init2.fish 2>/dev/null || :
