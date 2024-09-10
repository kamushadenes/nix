#!/usr/bin/env bash

source "$HOME/.config/sketchybar/nix_path.sh"
separator_right=(
	icon=
	icon.font="$NERD_FONT:Regular:16.0"
	background.padding_left=10
	background.padding_right=10
	label.drawing=off
	click_script='sketchybar --trigger toggle_stats'
	icon.color="$TEXT"
)

sketchybar --add item separator_right right \
	--set separator_right "${separator_right[@]}"
