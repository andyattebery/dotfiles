function oph
  op get item (hostname -s) | jq --raw-output '.details.sections[] | select(.name == "") | .fields[] | select(.t == "password").v'
end