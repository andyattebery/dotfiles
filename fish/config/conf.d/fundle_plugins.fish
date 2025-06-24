fundle plugin 'danhper/fish-fastdir'
fundle plugin 'danhper/fish-ssh-agent'

switch $HOSTNAME
    case 'macbook-pro-01'
        fundle plugin 'pure-fish/pure'
        set --export pure_color_mute brgreen
end

fundle init
