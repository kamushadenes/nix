#!/usr/bin/env bash

source "$HOME/.config/sketchybar/nix_path.sh"

magic_trackpad=(
	update_freq=30
	icon.font="$NERD_FONT:Bold:15.0"
	icon="󰟸"
	icon.color="$GREY"
	label="..."
	label.highlight_color="$BLUE"
	script="$PLUGIN_DIR/bluetooth-battery/scripts/magic_trackpad.sh"
)

sketchybar --add item bluetooth.battery.magic_trackpad right \
	--set bluetooth.battery.magic_trackpad "${magic_trackpad[@]}"

airpodsmax=(
	update_freq=30
	icon.font="$NERD_FONT:Bold:15.0"
	icon=""
	icon.color="$GREY"
	label="..."
	label.highlight_color="$BLUE"
	script="$PLUGIN_DIR/bluetooth-battery/scripts/airpodsmax.py"
)

sketchybar --add item bluetooth.battery.airpodsmax right \
	--set bluetooth.battery.airpodsmax "${airpodsmax[@]}"
