#!/usr/bin/env bash

source "$HOME/.config/sketchybar/nix_path.sh"

sketchybar -m --set "$NAME" label="$(memory_pressure | grep "System-wide memory free percentage:" | awk '{ printf("%02.0f\n", 100-$5"%") }')%"
