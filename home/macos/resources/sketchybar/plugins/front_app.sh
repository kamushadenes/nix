#!/usr/bin/env bash

source "$HOME/.config/sketchybar/variables.sh"

case "$SENDER" in
"front_app_switched")
	sketchybar --set "$NAME" label="$INFO"
	;;
esac
