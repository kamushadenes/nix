#!/usr/bin/env bash

source "$HOME/.config/sketchybar/colors.sh"
source "$HOME/.config/sketchybar/userconfig.sh"

IP_ADDRESS=$(scutil --nwi | grep address | sed 's/.*://' | tr -d ' ' | head -1)
IS_VPN=$(scutil --nwi | grep -m1 'utun' | awk '{ print $1 }')

if [[ $IS_VPN != "" ]]; then
    COLOR=$LAVENDER
    ICON=
    LABEL="VPN"
elif [[ $IP_ADDRESS != "" ]]; then
    COLOR=$BLUE
    ICON=
    LABEL=$IP_ADDRESS
else
    COLOR=$TEAL
    ICON=
    LABEL="Not Connected"
fi

sketchybar --set $NAME icon.color=$COLOR label.color=$COLOR \
    icon=$ICON \
    label="$LABEL"
