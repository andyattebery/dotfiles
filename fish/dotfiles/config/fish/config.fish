# Set built-in fish variables
set fish_greeting # Clear the default greeting

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

# Set Homebrew environment variables
if test -e /opt/homebrew
  set --export HOMEBREW_DIR /opt/homebrew
else if test -e /usr/local/Homebrew
  set --export HOMEBREW_DIR /usr/local/Homebrew
end

# Add to PATH
set --query HOMEBREW_DIR; and fish_add_path "$HOMEBREW_DIR"/*bin;
test -e "$HOMEBREW_DIR"/opt/ruby/bin; and fish_add_path "$HOMEBREW_DIR"/opt/ruby/bin
# golang
test -e "$HOME"/go/bin; and fish_add_path "$HOME"/go/bin
test -e $HOME/scripts; and fish_add_path "$HOME"/scripts
fish_add_path $DOTFILES_DIR/sh/config/bin

# Add fish/config/functions directories to fish_function_path
for function_dir in (find $DOTFILES_DIR/fish/config/functions -type d -print0 | string split0)
  set --local base_function_dir (basename "$function_dir")

  if test "$base_function_dir" = "functions"
  or command -q "$base_function_dir"
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

# mosh
set --export MOSH_TITLE_NOPREFIX 1

# rsync
set --export RSYNC_RSH 'ssh -o "ControlMaster no" -o "ControlPath /dev/null"'

# dotnet
test -n "$HOMEBREW_DIR"; and type --query dotnet; and set --export DOTNET_ROOT $HOMEBREW_DIR/opt/dotnet/libexec

# iTerm 2 shell integration
test -e {$HOME}/.iterm2_shell_integration.fish ; and source {$HOME}/.iterm2_shell_integration.fish
