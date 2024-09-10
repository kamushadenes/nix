#!/usr/bin/env bash

source "$HOME/.config/sketchybar/nix_path.sh"

calendar_date=(
	icon.font="$FONT:Bold:14.0"
	label.font="$FONT:Regular:12.0"
	label.width=45
	label.align=right
	popup.align=right
	popup.height=20
	update_freq=15
	background.padding_left=7
	script="$PLUGIN_DIR/date/scripts/ical.sh"
	click_script="$PLUGIN_DIR/date/scripts/zen.sh"
)

ical_details=(
	drawing=off
	background.corner_radius=12
	padding_left=7
	padding_right=7
	icon.font="$NERD_FONT:Bold:14.0"
	icon.background.height=2
)

sketchybar --add item calendar.date right \
	--set calendar.date "${calendar_date[@]}" \
	--subscribe calendar.date system_woke \
	mouse.entered \
	mouse.exited \
	mouse.exited.global \
	--add item calendar.date.details popup.calendar.date --set calendar.date.details "${ical_details[@]}"
