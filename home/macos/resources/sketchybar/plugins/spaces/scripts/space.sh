#!/usr/bin/env bash

SPACE_ICONS=("1" "2" "3" "4" "5" "6" "7" "8" "9" "10")
workspace=${FOCUSED_WORKSPACE:-$1}

update() {
    WIDTH="dynamic"
    if [ "$SELECTED" = "true" ]; then
        WIDTH="0"
    fi

    sketchybar --animate tanh 20 --set "$NAME" icon.highlight="$SELECTED" label.width="$WIDTH" icon="${SPACE_ICONS[$workspace - 1]}"
}

mouse_clicked() {
    aerospace workspace "$SID"
}

case "$SENDER" in
"mouse.clicked")
    mouse_clicked
    ;;
*)
    update
    ;;
esac
