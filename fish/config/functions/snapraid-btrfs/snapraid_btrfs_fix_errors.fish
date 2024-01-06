function srb_fix_errors --wraps snapraid-btrfs
  snapraid-btrfs fix -e -l /var/log/snapraid/fix_errors_(date +%Y.%m.%d-%H.%M.%S).txt
end