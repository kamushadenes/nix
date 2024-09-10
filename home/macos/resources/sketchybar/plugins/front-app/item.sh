#!/usr/bin/env bash

source "$HOME/.config/sketchybar/nix_path.sh"

COLOR="$WHITE"

sketchybar \
    --add item front_app left \
    --set front_app script="$PLUGIN_DIR/front-app/scripts/front_app.sh" \
    icon.drawing=off \
    background.height=26 \
    background.padding_left=0 \
    background.padding_right=10 \
    background.border_width="$BORDER_WIDTH" \
    background.border_color="$COLOR" \
    background.corner_radius="$CORNER_RADIUS" \
    background.color="$BAR_COLOR" \
    label.color="$TEXT" \
    label.font="$FONT:Black:12.0" \
    label.padding_left=10 \
    label.padding_right=10 \
    associated_display=active \
    --subscribe front_app front_app_switched
