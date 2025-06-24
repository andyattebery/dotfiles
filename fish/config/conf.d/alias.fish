function psg; ps -e | grep -i $argv; end
function tms; tmux new-session -A -s $argv; end
function ncp; mosh nas-01 -- tmux new-session -A -s cp; end
function ndl; mosh nas-01 -- tmux new-session -A -s dl; end
function nsr; mosh nas-01 -- tmux new-session -A -s sr; end
