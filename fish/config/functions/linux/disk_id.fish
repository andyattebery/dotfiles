function disk_id --argument-name device_name
  for ls_line in (ls -l /dev/disk/by-id | grep -vE '(total|scsi-3500|scsi-0ATA|scsi-1ATA|wwn-)' | sort --key=9 --reverse)
    set --local disk_match (string match --regex '(\S+) ->.*\/(\w+)$' -- $ls_line)

    set --local current_device_name $disk_match[3]
    set --local current_disk_id $disk_match[2]

    # echo $disk_id
    # echo "current_device_name: $current_device_name"
    # echo "current_disk_id: $current_disk_id"

    if contains $current_device_name $device_names
      continue
    end

    set --append disk_ids $current_disk_id
    set --append device_names $current_device_name
  end

  if set --local index (contains --index -- $device_name $device_names)
    echo $disk_ids[$index]
  end
end