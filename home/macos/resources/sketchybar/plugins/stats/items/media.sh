#!/usr/bin/env bash

source "$HOME/.config/sketchybar/nix_path.sh"
source "$HOME/.config/sketchybar/icons.sh"
source "$HOME/.config/sketchybar/colors.sh"

media=(
    label.font="$FONT:Heavy:12"
    label.color="$TEXT"
    label.max_chars=23
    icon="$MEDIA"
    icon.font="$NERD_FONT:Bold:16.0"
    icon.color="$PEACH"
    icon.highlight_color="$BLUE"
    updates=on
    scroll_texts=on
    script="$PLUGIN_DIR/stats/scripts/media.sh"
)

sketchybar --add item media center \
    --set media "${media[@]}" \
    --subscribe media media_change
