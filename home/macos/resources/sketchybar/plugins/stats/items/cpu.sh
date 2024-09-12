#!/usr/bin/env bash

source "$HOME/.config/sketchybar/nix_path.sh"
source "$HOME/.config/sketchybar/colors.sh"
source "$HOME/.config/sketchybar/userconfig.sh"

cpu_percent=(
	background.padding_left=0
	background.padding_right=0
	label.font="$FONT:Heavy:12"
	label=CPU%
	label.color="$TEXT"
	icon="$CPU"
	icon.color="$BLUE"
	update_freq=2
	script="$PLUGIN_DIR/stats/scripts/cpu.sh"
)

sketchybar --add item cpu.percent right \
	--set cpu.percent "${cpu_percent[@]}"
