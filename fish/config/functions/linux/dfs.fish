function dfs --wraps=df
  dfdi -h $argv | grep -vE "/dev/loop|tmpfs|udev" | awk 'NR<3{print $0;next}{print $0 | "sort --key=6"}'
end