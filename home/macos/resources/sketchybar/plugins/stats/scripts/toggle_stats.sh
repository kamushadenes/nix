#!/usr/bin/env bash

source "$HOME/.config/sketchybar/nix_path.sh"

stats=(
	cpu.percent
	memory
	disk
	ip_address
	network.up
	network.down
	bluetooth.battery.airpodsmax
	bluetooth.battery.magic_trackpad
)

hide_stats() {
	args=()
	for item in "${stats[@]}"; do
		args+=(--set "$item" drawing=off)
	done

	sketchybar "${args[@]}" \
		--set separator_right \
		icon=
}

show_stats() {
	args=()
	for item in "${stats[@]}"; do
		args+=(--set "$item" drawing=on)
	done

	sketchybar "${args[@]}" \
		--set separator_right \
		icon=
}

toggle_stats() {
	state=$(sketchybar --query separator_right | jq -r .icon.value)

	case $state in
	"")
		show_stats
		;;
	"")
		hide_stats
		;;
	esac
}

case "$SENDER" in
"hide_stats")
	hide_stats
	;;
"show_stats")
	show_stats
	;;
"toggle_stats")
	toggle_stats
	;;
esac
