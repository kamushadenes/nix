#!/usr/bin/env bash

source "$HOME/.config/sketchybar/nix_path.sh"
source "$HOME/.config/sketchybar/colors.sh"

SPACE_ICONS=("1" "2" "3" "4" "5" "6" "7" "8" "9" "10")

space=(
	icon.font="$NERD_FONT:Bold:14.0"
	icon.padding_left=7
	icon.padding_right=7
	background.padding_left=2
	background.padding_right=2
	label.padding_right=20
	label.font="$NERD_FONT:Regular:14.0"
	label.background.height=26
	label.background.drawing=on
	label.background.color="$SURFACE1"
	label.background.corner_radius=8
	label.drawing=off
	y_offset=-2
)

sketchybar --add event aerospace_workspace_change

for sid in $(aerospace list-workspaces --all); do
	sketchybar --add space space.$sid left \
		--subscribe space.$sid aerospace_workspace_change \
		--set space.$sid associated_space=$sid \
		click_script="aerospace workspace $sid" \
		script="$PLUGIN_DIR/spaces/scripts/space.sh $sid" \
		icon="${SPACE_ICONS[sid - 1]}" \
		icon.highlight_color="$(getRandomCatColor)" \
		"${space[@]}" \
		--subscribe space.$sid mouse.clicked
done

#spaces_bracket=(
#	background.color="$SURFACE0"
#	background.border_color="$SURFACE1"
#	background.border_width=2
#	background.drawing=on
#)

#sketchybar --add bracket spaces '/space\..*/' \
#	--set spaces "${spaces_bracket[@]}"
