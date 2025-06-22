function copy_photos_from_sd_card
    set --local sd_card_path "/Volumes/Untitled"

    set --local destination_paths \
        # "/Users/andy/Pictures/Imports" \
        # "/Volumes/2TB" \
        "/Volumes/Photos/Imports" \
        "nas-01:/mnt/tank/photos/Imports" \
        "nas-01:/mnt/sink/photos/Imports" \
        # "nas-01:/mnt/basin/photos/Imports"

    set --local raw_file_extensions "ARW" "RAF"
    set --local compressed_file_extensions "JPEG" "JPG" "HEIF" "HIF"

    set --local date_stamp (date "+%Y-%m-%d")

    # for source_photo_directory_path in (find $sd_card_path/DCIM -mindepth 1 -type d -print0 | string split0)
        set --local source_photo_directory_path "$sd_card_path/DCIM"

        set --local raw_file_count (__get_extensions_file_count "$source_photo_directory_path" $raw_file_extensions)
        set --local compressed_file_count (__get_extensions_file_count "$source_photo_directory_path" $compressed_file_extensions)

        echo "raw_file_count: $raw_file_count"
        echo "compressed_file_count: $compressed_file_count"

        set --local total_photo_file_count (math $raw_file_count + $compressed_file_count)

        if test $total_photo_file_count -eq 0
            # continue
        end

        set --local first_file_path (find $source_photo_directory_path -type f)
        set --local camera_model (exiftool -T -Model $first_file_path[1])
        echo $camera_model

        set --local source_directory_name (basename $source_photo_directory_path)

        if test \( $raw_file_count -gt 0 \) -a \( $compressed_file_count -eq 0 \)
            set import_photo_directory_name "$source_directory_name - $camera_model - RAW"
        else if test \( $raw_file_count -eq 0 \) -a \( $compressed_file_count -gt 0 \)
            set import_photo_directory_name "$source_directory_name - $camera_model - Lossy"
        else
            set import_photo_directory_name "$source_directory_name - $camera_model - Mixed"
        end

        set --local import_directory_name "Import - $date_stamp"

        set --local relative_import_photo_directory_path "$import_directory_name/$import_photo_directory_name"

        set --local source_movie_source_path "$sd_card_path/PRIVATE/M4ROOT/CLIP"
        set --local relative_import_movie_directory_path "$import_directory_name/M4ROOT-CLIP - $camera_model"
        set --local movie_file_count (find $source_movie_source_path -type f | wc -l)

        for destination_path in $destination_paths
            # if not test -d "$destination_path"
            #     echo "$destination_path is not available..."
            #     continue
            # end

            set --local import_photo_directory_path "$destination_path/$relative_import_photo_directory_path"
            echo "Copying $source_photo_directory_path to $import_photo_directory_path..."

            rsync -a --info=progress2 --mkpath $source_photo_directory_path/ $import_photo_directory_path

            if test $movie_file_count -gt 0
                set --local import_movie_directory_path "$destination_path/$relative_import_movie_directory_path"

                echo "Copying $source_movie_source_path to $import_movie_directory_path..."
                rsync -a --info=progress2 --mkpath $source_movie_source_path/ $import_movie_directory_path
            end
        end
    # end


end

function __get_extensions_file_count
    set --local directory_path $argv[1]
    # echo $directory_path

    set --local file_count 0

    for extension in $argv[2..-1]
        set --local extension_file_count (find $directory_path -type f -iname "*.$extension" | wc -l)
        # echo "$extension file count: $extension_file_count"
        set file_count (math $file_count + $extension_file_count)
    end

    echo $file_count
end
