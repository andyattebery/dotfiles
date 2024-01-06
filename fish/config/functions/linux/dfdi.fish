function dfdi --wraps=df
  set index 0
  for df_line in (df $argv)
    if test $index -eq 0
      set df_line (string replace "Mounted on" "MountedOn" $df_line)
    end

    if string match --quiet --regex '\/dev\/(?<disk_name>sd\w+)' -- $df_line
      set --local disk_id (disk_id $disk_name)
      set new_df_line (string replace "/dev/$disk_name" "/dev/disk/by-id/$disk_id" $df_line)
    else
      set new_df_line "$df_line"
    end

    set --append new_df_lines $new_df_line
    set index (math $index + 1)
  end

  string collect $new_df_lines | column -t
end