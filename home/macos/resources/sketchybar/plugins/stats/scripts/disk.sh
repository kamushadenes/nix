#!/usr/bin/env bash

source "$HOME/.config/sketchybar/nix_path.sh"
sketchybar -m --set "$NAME" label="$(df -H | grep -E '^(/dev/disk3s5 ).' | awk '{ printf ("%s\n", $5) }')"
