#!/usr/bin/env bash

source "$HOME/.config/sketchybar/nix_path.sh"

zen_items=(
	apple.logo
	'/cpu.*/'
	calendar
	separator
	front_app
	disk
	memory
	separator_left
	separator_right
	volume
	volume_icon
	network_up
	network_down
	ip_address
	github.bell
	network.up
	network.down
	bluetooth.battery.airpodsmax
	bluetooth.battery.magic_trackpad
)

zen_on() {
	args=()
	for item in "${zen_items[@]}"; do
		args+=(--set "$item" drawing=off)
	done

	sketchybar "${args[@]}"
}

zen_off() {
	args=()
	for item in "${zen_items[@]}"; do
		args+=(--set "$item" drawing=on)
	done

	sketchybar "${args[@]}"
}

if [ "$1" = "on" ]; then
	zen_on
elif [ "$1" = "off" ]; then
	zen_off
else
	if [ "$(sketchybar --query apple.logo | jq -r ".geometry.drawing")" = "on" ]; then
		zen_on
	else
		zen_off
	fi
fi
