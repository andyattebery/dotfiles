function cseq \
    --argument-names starting_char ending_char

    set starting_ascii_code (printf '%d' "'$starting_char")
    set ending_ascii_code (printf '%d' "'$ending_char")

    for c in (seq $starting_ascii_code $ending_ascii_code)
        printf '%b\n' (printf '\\\x%x' $c)
    end
end