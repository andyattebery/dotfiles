function ytdl --argument-names url

  if command -q yt-dlp
    set ytdl_command yt-dlp
  else if command -q youtube-dl
    set ytdl_command youtube-dl
  else
    return 1
  end

  set extension ($ytdl_command --simulate --get-filename -o '%(ext)s' $url)

  set --local download_dir '/mnt/storage/Videos/YouTube'

  if test -e $download_dir
    set --prepend extra_options --paths $download_dir
  end

  if test $extension != mp4
    set --prepend extra_options --merge-output-format mkv
  end

  $ytdl_command $extra_options -o '%(channel)s/%(title)s.%(ext)s' $url

end
