function create_m3u_multi_disc \
    --argument-names directory

    set --local multi_disc_directory_path "$directory/_Multi-Disc"
    mkdir "$multi_disc_directory_path"

    for multi_disc_prefix in (find "$directory" -maxdepth 1 -type f -iregex ".*(Disc.+).*" -printf '%f\n' | sed --regexp-extended 's/(.*)[ ][(]Disc [0-9]+[)].*/\1/' | uniq)
        echo "$multi_disc_prefix"
        set --local multi_disc_name (find "$directory" -maxdepth 1 -type f -iregex ".*/$multi_disc_prefix.*" -printf '%f\n' | sed --regexp-extended 's/(.*)[ ][(]Disc [0-9]+[)](.*)[.]...$/\1\2/' | uniq)

        # echo "$multi_disc_name"

        for disc_file_path in (find "$directory" -maxdepth 1 -type f -iregex ".*/$multi_disc_prefix.*" -print0 | string split0)
            # echo $disc_file_path
            mv $disc_file_path "$multi_disc_directory_path"
            set --local disc_file_name (basename $disc_file_path)
            echo ./_Multi-Disc/"$disc_file_name" >> "$directory"/"$multi_disc_name".m3u
        end
    end

end