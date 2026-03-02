function embed_vobsub_subtitle

    argparse 'd/delete-original-file' -- $argv
        or return

    if test (count $argv) -ne 1
        echo "Only one file is supported."
        return 1
    end

    set -g EXIT_ON_ERROR 1

    set --local file_path $argv[1]

    set --local path_to_file (path dirname $file_path)
    set --local filename_without_extension (path change-extension '' $file_path)
    set --local file_extension (path extension $file_path)

    set --local sub_path "$path_to_file/$filename_without_extension.sub"
    set --local idx_path "$path_to_file/$filename_without_extension.idx"
    set --local new_file_path "$path_to_file/$filename_without_extension.withsubs$file_extension"

    if test ! -e $sub_path
        echo "$sub_path does not exist..."
        return 1
    end

    if test ! -e $idx_path
        echo "$idx_path does not exist..."
        return 1
    end

    echo "Embedding .sub and .idx subtitles to $file_path"

    ffmpeg -hide_banner -loglevel warning -stats \
        -i "$file_path" \
        -f vobsub -sub_name "$sub_path" \
        -i "$idx_path" \
        -c:v copy -c:a copy -c:s dvdsub \
        "$new_file_path" \
        || return 1

    if set -q _flag_delete_original_file
        echo "Deleting $file_path"
        rm "$file_path"
        echo "Renaming $new_file_path to $file_path"
        mv "$new_file_path" "$file_path"
    end

end