#!/usr/bin/env bash

# Show memory pressure
sketchybar --set "$NAME" icon="" label="$(echo $((100 - $(memory_pressure | grep "System-wide" | awk '{print $NF}' | sed 's/%//')))%)"
