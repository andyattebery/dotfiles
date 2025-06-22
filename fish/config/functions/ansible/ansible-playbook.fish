function ansible-playbook --wraps ansible-playbook
  env OBJC_DISABLE_INITIALIZE_FORK_SAFETY=YES ansible-playbook $argv
end