#!/usr/bin/env bash
#

divider=(
	background.color="$SURFACE0"
	background.border_color="$SURFACE1"
	background.border_width=2
	background.padding_left=5
	background.padding_right=10
)

sketchybar --add bracket status volume_icon volume github.bell wifi.alias battery \
	--set status "${divider[@]}"
