#!/usr/bin/env sh

source "$HOME/.config/sketchybar/nix_path.sh"
#SPACE_ICONS=(" " " " " " "" "" "" " " " ")
SPACE_ICONS=("1" "2" "3" "4" "5" "6" "7" "8" "9" "10")

workspace=${FOCUSED_WORKSPACE:-$1}

if [ "$1" = "$workspace" ]; then
    sketchybar --animate tanh 5 --set "$NAME" \
        icon.color="$RED" \
        icon="${SPACE_ICONS[$1 - 1]}" \
        click_script="aerospace workspace $1"
else
    sketchybar --animate tanh 5 --set "$NAME" \
        icon.color="$COMMENT" \
        icon="${SPACE_ICONS[$1 - 1]}" \
        click_script="aerospace workspace $1"
fi
