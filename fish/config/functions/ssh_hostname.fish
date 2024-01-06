function ssh_hostname --argument-names server 
  # Check to see if local server is available
  ping -o $server > /dev/null 2>&1
  # Set server information
  if [ $status -eq 0 ]
    echo $server
  else
    echo "$server.prime"
  end
end
