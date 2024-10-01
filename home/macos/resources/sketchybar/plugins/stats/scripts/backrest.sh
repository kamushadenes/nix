#!/bin/bash

source "$HOME/.config/sketchybar/nix_path.sh"
source "$HOME/.config/sketchybar/colors.sh"
source "$HOME/.config/sketchybar/icons.sh"
source "$HOME/.config/sketchybar/userconfig.sh" # Loads all defined variables

plan="$(echo $NAME | cut -d . -f2)"

output="$(cat ~/.config/backrest/status/$plan)"

status="$(echo $output | awk '{print $1}')"
date="$(echo $output | awk '{print $2}')"

case $status in
"success")
    COLOR="$GREEN"
    ICON="$BACKREST_SUCCESS"
    ;;
"error")
    COLOR="$RED"
    ICON="$BACKREST_ERROR"
    ;;
"running")
    COLOR="red"
    ICON="$BACKREST_RUNNING"
    ;;
*)
    COLOR="$GREY"
    ICON="$BACKREST_UNKNOWN"
    ;;
esac

sketchybar --set "$NAME" color="$COLOR" icon="$ICON"
