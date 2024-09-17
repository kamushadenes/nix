#!/usr/bin/env bash

source "$HOME/.config/sketchybar/nix_path.sh"

magic_trackpad=(
	update_freq=30
	icon="󰟸"
	icon.color="$GREY"
	background.padding_left=0
	background.padding_right=0
	label.font="$FONT:Heavy:12"
	label=CPU%
	label.color="$TEXT"
	script="$PLUGIN_DIR/stats/scripts/magic_trackpad.sh"
)

sketchybar --add item bluetooth.battery.magic_trackpad right \
	--set bluetooth.battery.magic_trackpad "${magic_trackpad[@]}"

airpodsmax=(
	update_freq=30
	icon=""
	icon.color="$GREY"
	label="..."
	background.padding_left=0
	background.padding_right=0
	label.font="$FONT:Heavy:12"
	label=CPU%
	label.color="$TEXT"
	script="$PLUGIN_DIR/stats/scripts/airpodsmax.py"
)

sketchybar --add item bluetooth.battery.airpodsmax right \
	--set bluetooth.battery.airpodsmax "${airpodsmax[@]}"
