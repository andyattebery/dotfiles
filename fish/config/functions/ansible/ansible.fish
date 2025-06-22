function ansible --wraps ansible
  env OBJC_DISABLE_INITIALIZE_FORK_SAFETY=YES ansible $argv
end