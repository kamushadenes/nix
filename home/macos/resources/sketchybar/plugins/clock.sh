#!/usr/bin/env bash

source "$HOME/.config/sketchybar/variables.sh"

LABEL=$(date '+%H:%M:%S')
sketchybar --set "$NAME" label="$LABEL"
