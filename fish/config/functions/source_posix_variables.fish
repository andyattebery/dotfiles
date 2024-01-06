function source_posix_variables \
  --description "Sources a file with POSIX-style variable declarations. (i.e. NAME=VALUE)" \
  --argument-names SOURCE_FILE

  for v in (cat $SOURCE_FILE)

    if string match --quiet --regex '^#' $v
      continue
    end

    set arr (echo $v |tr = \n)
    set --global --export $arr[1] $arr[2]
  end
end
