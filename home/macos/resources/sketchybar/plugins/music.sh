#!/usr/bin/env bash

source "$HOME/.config/sketchybar/variables.sh"

STATE="$(echo "$INFO" | jq -r '.state')"
#APP="$(echo "$INFO" | jq -r '.app')"

if [ "$STATE" = "playing" ]; then
    MEDIA="$(echo "$INFO" | jq -r '.title + " - " + .artist')"
    sketchybar --set "$NAME" label="$MEDIA" drawing=on
else
    sketchybar --set "$NAME" drawing=off
fi
