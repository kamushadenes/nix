#!/usr/bin/env bash

COLOR="$WHITE"

sketchybar --add item upcoming center \
    --set upcoming \
    update_freq=20 \
    icon.color="$COLOR" \
    icon.padding_left=10 \
    label.color="$COLOR" \
    label.padding_right=10 \
    background.height=26 \
    background.corner_radius="$CORNER_RADIUS" \
    background.padding_right=5 \
    background.border_width="$BORDER_WIDTH" \
    background.border_color="$COLOR" \
    background.color="$BAR_COLOR" \
    background.drawing=on \
    script="python3 $PLUGIN_DIR/upcoming.py" \
    click_script="sketchybar -m --set upcoming popup.drawing=toggle"
