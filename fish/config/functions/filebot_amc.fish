function filebot_amc --argument-names download_path
    echo $download_path
    set download_dir (path dirname $download_path)
    set filename (path basename $download_path)

    if string match --quiet --regex 'movies$' $download_dir
        set media_type movie
    else if string match --quiet --regex 'tv_shows$' $download_dir
        set media_type tv
    end
    echo $media_type
    echo $filename

    curl -G http://nas-01.omegaho.me:8099/amc --data-urlencode "dir=$download_path" --data-urlencode "title=$filename" --data-urlencode "label=$media_type"
end