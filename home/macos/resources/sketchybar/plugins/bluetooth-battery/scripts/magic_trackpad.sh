#!/usr/bin/env bash

source "$HOME/.config/sketchybar/nix_path.sh"
source "$HOME/.config/sketchybar/colors.sh"
source "$HOME/.config/sketchybar/icons.sh"
source "$HOME/.config/sketchybar/userconfig.sh" # Loads all defined variables

update() {
	PERCENT="$(ioreg -c "AppleDeviceManagementHIDEventService" | grep -E -i '"Product"|BatteryPercent' | python -c 'import re, sys; print(re.sub(r".*Product.....(.*).\n.* (\d*)", r"\2%\t\1", sys.stdin.read()).strip())' | grep 'Magic Trackpad' | awk '{print$1}')"

	sketchybar --animate tanh 15 --set bluetooth.battery.magic_trackpad label.y_offset=5 label.y_offset=0 icon="󰟸" label="$PERCENT"
}

case "$SENDER" in
"routine" | "forced")
	update
	;;
esac
