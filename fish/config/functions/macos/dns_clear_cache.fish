function dns_clear_cache
  sudo dscacheutil -flushcache; sudo killall -HUP mDNSResponder
end