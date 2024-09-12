#!/bin/bash

HELPER=git.felix.helper
killall helper
cd "$HOME"/.config/sketchybar/helper && make
"/tmp/.$(whoami)_sketchybar_helper" "$HELPER" >/dev/null 2>&1 &
