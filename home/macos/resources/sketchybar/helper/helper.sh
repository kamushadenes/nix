#!/bin/bash

HELPER=git.felix.helper
killall helper
cd "$HOME"/.config/sketchybar/helper && make
"${DARWIN_USER_TEMP_DIR}/sketchybar_helper" "$HELPER" >/dev/null 2>&1 &
