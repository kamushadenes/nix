#!/usr/bin/env bash

source "$HOME/.config/sketchybar/variables.sh"

SPACE_ICONS=("1" "2" "3" "4" "5" "6" "7" "8" "9" "10")

if [ "$1" = "$FOCUSED_WORKSPACE" ]; then
    sketchybar --animate tanh 5 --set "$NAME" \
        icon.color="$RED" \
        icon="${SPACE_ICONS[$SID - 1]}" \
        click_script="aerospace workspace $SID"
else
    sketchybar --animate tanh 5 --set "$NAME" \
        icon.color="$COMMENT" \
        icon="${SPACE_ICONS[$SID - 1]}" \
        click_script="aerospace workspace $SID"
fi
