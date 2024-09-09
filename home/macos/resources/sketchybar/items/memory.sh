#!/usr/bin/env bash

COLOR="$YELLOW"

sketchybar --add item memory right \
    --set memory \
    update_freq=3 \
    icon.color="$COLOR" \
    icon.padding_left=10 \
    label.color="$COLOR" \
    label.padding_right=10 \
    background.height=26 \
    background.corner_radius="$CORNER_RADIUS" \
    background.padding_right=5 \
    \
    background.border_color="$COLOR" \
    background.color="$BAR_COLOR" \
    background.drawing=on \
    script="$PLUGIN_DIR/memory.sh" #background.border_width="$BORDER_WIDTH" \