#!/usr/bin/env bash

source "$HOME/.config/sketchybar/variables.sh"

# Show memory pressure
sketchybar --set "$NAME" icon="" label="$(echo $((100 - $(memory_pressure | grep "System-wide" | awk '{print $NF}' | sed 's/%//')))%)"
