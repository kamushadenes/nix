#!/usr/bin/env bash

source "$HOME/.config/sketchybar/variables.sh"

sketchybar --set "$NAME" icon="" label="$(ps -A -o %cpu | awk '{s+=$1} END {s /= 8} END {printf "%.1f%%\n", s}')"
