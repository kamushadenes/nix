#!/usr/bin/env bash

source "$HOME/.config/sketchybar/nix_path.sh"

magic_trackpad=(
	update_freq=180
	icon.font="$NERD_FONT:Bold:15.0"
	icon="󰟸"
	icon.color="$GREY"
	label="$LOADING"
	label.highlight_color="$BLUE"
	script="$PLUGIN_DIR/bluetooth-battery/scripts/magic-trackpad.sh"
)

sketchybar --add item bluetooth.battery.magic_trackpad right \
	--set bluetooth.battery.magic_trackpad "${magic_trackpad[@]}"
