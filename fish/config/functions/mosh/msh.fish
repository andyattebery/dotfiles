function msh --wraps=mosh --argument-names host
  set --local is_sga_guard_running_for_host false

  for process_command in (ps -o command | grep "[a]utossh")
    if string match --quiet "*autossh*$host*" "$process_command"
      set is_sga_guard_running_for_host true
    end
  end

  if not $is_sga_guard_running_for_host
    # echo "Starting sga-guard..."
    sga-guard $host > /tmp/sga-guard_$host.out 2>&1 &
  # else
  #   echo "sga-guard is running..."
  end

  mosh $host
end