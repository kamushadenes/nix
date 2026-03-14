if set -q fish_private_mode
    set -e fish_private_mode
    set -e ATUIN_HISTORY_DISABLE
    set -e PRIVATE_MODE
    echo "history enabled"
else
    set -gx fish_private_mode 1
    set -gx ATUIN_HISTORY_DISABLE true
    set -gx PRIVATE_MODE 1
    echo "history disabled"
end
