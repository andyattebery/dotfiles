function bjobs
  for pid in (jobs -p)
    set command (ps -o command='' -p $pid)
    if string match --quiet '*yt-dlp*' $command
      set command (echo $command | sed -E 's/.*(yt-dlp)/\1/')
    end

    set process_info (ps -o pid='',time='' -p $pid)
    
    echo "$process_info   $command"
  end
end
