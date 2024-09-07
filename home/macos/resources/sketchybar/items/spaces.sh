#!/usr/bin/env bash

source "$HOME/.config/sketchybar/variables.sh" # Loads all defined colors

sketchybar --add event aerospace_workspace_change

for sid in $(aerospace list-workspaces --all); do
	sketchybar --add item space.$sid left \
		--subscribe space.$sid aerospace_workspace_change \
		--set space.$sid \
		label.drawing=off \
		icon.padding_left=10 \
		icon.padding_right=10 \
		background.padding_left=-5 \
		background.padding_right=-5 \
		click_script="aerospace workspace $sid" \
		script="$PLUGIN_DIR/aerospace.sh $sid"
done

sketchybar --add bracket spaces '/space.*/' \
	--set spaces background.border_width="$BORDER_WIDTH" \
	background.border_color="$RED" \
	background.corner_radius="$CORNER_RADIUS" \
	background.color="$BAR_COLOR" \
	background.height=26 \
	background.drawing=on

sketchybar --add item separator left \
	\
	icon.font="$FONT:Regular:16.0" \
	background.padding_left=26 \
	background.padding_right=15 \
	label.drawing=off \
	associated_display=active \
	icon.color="$YELLOW"
