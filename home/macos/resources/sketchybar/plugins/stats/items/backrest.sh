#!/usr/bin/env bash

source "$HOME/.config/sketchybar/nix_path.sh"
source "$HOME/.config/sketchybar/colors.sh"
source "$HOME/.config/sketchybar/userconfig.sh"

backrest=(
	background.padding_left=0
	label.font="$FONT:Heavy:12"
	label=-
	label.color="$TEXT"
	icon="$BACKREST_UNKNOWN"
	icon.color="$GREY"
	update_freq=5
	script="$PLUGIN_DIR/stats/scripts/backrest.sh"
)

for plan in ~/.config/backrest/status/*; do
    sketchybar --add item backrest."$plan" right "${backrest[@]}" \
        --set label="$plan" \
        --set icon="$BACKREST_UNKNOWN"
done
