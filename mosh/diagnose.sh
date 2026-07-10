#!/usr/bin/env bash
#
# Capture the state of a mosh-on-macOS failure at the moment it happens.
#
# Two different macOS mechanisms produce the identical symptom
# ("mosh: Nothing received from server on UDP port ..."):
#
#   1. Application Firewall (ALF).  Keys exceptions to a BINARY PATH.
#      Homebrew's mosh lives at a versioned Cellar path behind a symlink, so
#      every `brew upgrade mosh` moves the real binary and voids the exception.
#      A self-built /usr/local/bin/mosh-client keeps its exception. Inert when
#      the firewall is globally off.
#
#   2. Local Network Privacy (Sequoia+).  Keys the grant to the RESPONSIBLE
#      APP, not the binary. A helper re-parented to launchd (ppid 1) -- e.g. an
#      iTermServer orphaned by an iTerm2 auto-update -- loses the grant, and
#      every child it spawns is denied the local subnet. No mosh rebuild can fix
#      this; relaunching the terminal can.
#
# This script tells you which one you are looking at. Run it FROM THE TERMINAL
# THAT IS FAILING -- the responsible-process chain is the whole point.
#
# Usage: ./diagnose.sh [host]        (default: docker-01.omegaho.me)

set -uo pipefail
HOST=${1:-docker-01.omegaho.me}

hdr() { printf '\n\033[1m== %s\033[0m\n' "$*"; }

hdr "system"
sw_vers | sed 's/^/  /'

hdr "responsible-process chain (this shell upward)"
# Local Network grants attach to the app at the top of this chain. If it ends at
# a bare helper instead of an .app bundle, that helper cannot hold a grant.
# Record any helper we pass through, so the orphan check below uses data we have
# already read rather than re-discovering it with a separate tool.
ancestor_helper_pid=''
ancestor_helper_ppid=''
p=$$
for _ in 1 2 3 4 5 6 7; do
  line=$(ps -o ppid=,comm= -p "$p" 2>/dev/null) || break
  ppid=$(echo "$line" | awk '{print $1}')
  comm=$(echo "$line" | sed 's/^ *[0-9]* *//')
  printf '  %s\n' "$comm"
  case $comm in
    *iTermServer*) ancestor_helper_pid=$p; ancestor_helper_ppid=$ppid ;;
  esac
  p=$ppid
  [ "$p" = 1 ] && { printf '  launchd\n'; break; }
done

hdr "iTermServer orphan check"
# ps -A rather than pgrep: pgrep silently returned nothing when this script ran
# from inside an iTermServer-parented shell, which is exactly the case that
# matters. Scan the full table instead.
found=0
while read -r pid ppid rest; do
  case $rest in *iTermServer*) ;; *) continue ;; esac
  found=1
  if [ "$ppid" = 1 ]; then
    printf '  \033[31mORPHANED\033[0m pid=%s ppid=1  %s\n' "$pid" "$rest"
    printf '            -> children lost the Local Network grant.\n'
    printf '            -> quit iTerm2, then: pkill -f iTermServer, then relaunch.\n'
  else
    printf '  ok       pid=%s ppid=%s (live child of iTerm2)  %s\n' "$pid" "$ppid" "$rest"
  fi
done < <(ps -Ao pid=,ppid=,command= 2>/dev/null)
[ "$found" -eq 0 ] && printf '  (no iTermServer running)\n'

if [ -n "$ancestor_helper_pid" ]; then
  printf '  this shell is served by iTermServer pid=%s (ppid=%s)%s\n' \
    "$ancestor_helper_pid" "$ancestor_helper_ppid" \
    "$([ "$ancestor_helper_ppid" = 1 ] && printf ' -- \033[31mORPHANED, this is your bug\033[0m')"
fi

hdr "Application Firewall"
FW=/usr/libexec/ApplicationFirewall/socketfilterfw
"$FW" --getglobalstate 2>/dev/null | sed 's/^/  /'
alf_off=0
"$FW" --getglobalstate 2>/dev/null | grep -q 'disabled' && alf_off=1

# NOT --getappblocked: with the firewall off it answers "would this be blocked
# right now?" and returns "permitted" for every path, including /bin/ls. Ask the
# app list for actual membership instead.
applist=$("$FW" --listapps 2>/dev/null)
for b in $(printf '%s\n' /usr/local/bin/mosh-client /usr/local/bin/mosh-server \
             "$(command -v mosh-client || true)" "$(command -v mosh-server || true)" \
           | grep -v '^$' | sort -u); do
  [ -x "$b" ] || continue
  if printf '%s' "$applist" | grep -qF " $b "; then
    printf '  %-32s in ALF list\n' "$b"
  else
    printf '  %-32s \033[33mNOT in ALF list\033[0m\n' "$b"
  fi
done
if [ "$alf_off" -eq 1 ]; then
  printf '  -> firewall is OFF: list membership is inert. Verified both ways --\n'
  printf '     a listed binary (mosh-client) still gets denied when its responsible\n'
  printf '     app lacks the grant, and an unlisted one succeeds when the app has it.\n'
fi

hdr "mosh-client binary"
mc=$(command -v mosh-client || echo "(not on PATH)")
printf '  path: %s\n' "$mc"
if [ -x "$mc" ]; then
  [ -L "$mc" ] && printf '  \033[33mSYMLINK\033[0m -> %s  (ALF exceptions must name the real file)\n' "$(readlink "$mc")"
  codesign -dvv "$mc" 2>&1 | grep -E 'Signature|Identifier=' | sed 's/^/  /'
  otool -L "$mc" | tail -n +2 | grep -cE 'protobuf|absl' \
    | sed 's/^/  dynamic protobuf\/abseil refs: /'
fi

hdr "connectivity probe -> $HOST"
python3 - "$HOST" <<'PY'
import socket, sys, errno
host = sys.argv[1]
try:
    ip = socket.gethostbyname(host)
except Exception as e:
    print("  cannot resolve %s: %s" % (host, e)); sys.exit(1)
print("  %s -> %s" % (host, ip))

def tcp(ip, port):
    s = socket.socket(socket.AF_INET, socket.SOCK_STREAM); s.settimeout(3)
    try:
        s.connect((ip, port)); return "OK"
    except OSError as e:
        return "%s (errno %d)" % (e.strerror, e.errno)
    finally:
        s.close()

def udp_send(ip, port):
    # A Local Network denial fails at sendto() with EHOSTUNREACH. No responder
    # needed on the far end: we are testing the policy, not the service.
    s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM); s.settimeout(2)
    try:
        s.sendto(b"probe", (ip, port)); return "sendto OK"
    except OSError as e:
        return "%s (errno %d)" % (e.strerror, e.errno)
    finally:
        s.close()

print("  TCP  %s:22       %s" % (ip, tcp(ip, 22)))
print("  UDP  %s:60001    %s" % (ip, udp_send(ip, 60001)))
print("  UDP  8.8.8.8:53      %s   <- public control" % udp_send("8.8.8.8", 53))
print()
print("  Reading: local TCP *and* UDP failing with EHOSTUNREACH (errno 65) while")
print("  the public control succeeds == Local Network Privacy denial. Fix the")
print("  responsible app, not mosh. If only the firewall is on and a path-keyed")
print("  exception is missing, that is ALF instead.")
PY
