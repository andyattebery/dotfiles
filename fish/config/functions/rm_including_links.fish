function rm_including_links \
  --argument-names file_path

  find . -samefile $file_path -delete -print
end