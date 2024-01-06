function aptup
  sudo apt update && sudo apt full-upgrade -y && sudo apt autoremove --purge -y
end
