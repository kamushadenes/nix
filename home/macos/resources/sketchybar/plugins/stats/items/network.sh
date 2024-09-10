#!/usr/bin/env bash

source "$HOME/.config/sketchybar/nix_path.sh"
source "$HOME/.config/sketchybar/icons.sh"
source "$HOME/.config/sketchybar/colors.sh"

ip_address=(
	label.font="$FONT:Heavy:12"
	label.color="$TEXT"
	icon="$NETWORK"
	icon.font="$NERD_FONT:Bold:16.0"
	icon.color="$GREEN"
	icon.highlight_color="$BLUE"
	update_freq=5
	script="$PLUGIN_DIR/stats/scripts/ip_address.sh"
)

network_down=(
	#y_offset=-7
	label.font="$FONT:Heavy:12"
	label.color="$TEXT"
	icon="$NETWORK_DOWN"
	icon.font="$NERD_FONT:Bold:16.0"
	icon.color="$GREEN"
	icon.highlight_color="$BLUE"
	update_freq=1
)

network_up=(
	#background.padding_right=-72
	#y_offset=7
	label.font="$FONT:Heavy:12"
	label.color="$TEXT"
	icon="$NETWORK_UP"
	icon.font="$NERD_FONT:Bold:16.0"
	icon.color="$GREEN"
	icon.highlight_color="$BLUE"
	update_freq=1
	script="$PLUGIN_DIR/stats/scripts/network.sh"
)

sketchybar --add item ip_address right \
	--set ip_address "${ip_address[@]}" \
	--subscribe ip_address wifi_change

sketchybar --add item network.down right \
	--set network.down "${network_down[@]}" \
	--add item network.up right \
	--set network.up "${network_up[@]}"
