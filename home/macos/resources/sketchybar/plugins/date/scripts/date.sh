#!/usr/bin/env sh

source "$HOME/.config/sketchybar/nix_path.sh"

sketchybar --set "$NAME" icon="$(date '+%a %d. %b')"
