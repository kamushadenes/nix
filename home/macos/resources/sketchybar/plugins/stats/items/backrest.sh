#!/usr/bin/env bash

source "$HOME/.config/sketchybar/nix_path.sh"

if ! command -v backrest 2>&1 >/dev/null; then
	echo "backrest could not be found"
	exit 0
fi

source "$HOME/.config/sketchybar/colors.sh"
source "$HOME/.config/sketchybar/userconfig.sh"

backrest_config=(
	background.padding_left=0
	label.font="$FONT:Heavy:12"
	label="Backup"
	label.color="$TEXT"
	icon="$BACKREST"
	icon.color="$GREY"
	update_freq=5
	script="$PLUGIN_DIR/stats/scripts/backrest.sh"
)

backrest_details=(
	drawing=off
	background.corner_radius=12
	padding_left=7
	padding_right=7
	icon.font="$NERD_FONT:Bold:14.0"
	icon.background.height=2
)

sketchybar --add item backrest right \
	--set backrest "${backrest_config[@]}" \
	--subscribe backrest \
	mouse.entered \
	mouse.exited \
	mouse.exited.global \
	--add item backrest.details popup.backrest --set backrest.details "${backrest_details[@]}"
