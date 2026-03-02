function movie_duplicates
    set MOVIES_DIR /mnt/storage/Movies

    for movie_dir in (find $MOVIES_DIR -maxdepth 1 -type d -print0 | string split0)
        # echo $movie_dir
        # set files (find $movie_dir -maxdepth 1 -type f -name "*.mkv")
        # echo $files
        set file_count (find $movie_dir -maxdepth 1 -type f -name "*.mkv" | wc --lines)
        if test $file_count -gt 1
            echo $movie_dir
            # echo $file_count
            # for f in (find $movie_dir -maxdepth 1 -type f -name "*.mkv" -print0 | string split0)
            #     echo $f
            # end
        end
    end
end

movie_duplicates