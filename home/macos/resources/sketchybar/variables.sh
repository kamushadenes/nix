#!/usr/bin/env sh

# Color Palette
# Catppuccin Macchiato
export BASE=0xff24273a
export MANTLE=0xff1e2030
export CRUST=0xff181926

export TEXT=0xffcad3f5
export SUBTEXT0=0xffb8c0e0
export SUBTEXT1=0xffa5adcb

export SURFACE0=0xff363a4f
export SURFACE1=0xff494d64
export SURFACE2=0xff5b6078

export OVERLAY0=0xff6e738d
export OVERLAY1=0xff8087a2
export OVERLAY2=0xff939ab7

export BLUE=0xff8aadf4
export LAVENDER=0xffb7bdf8
export SAPPHIRE=0xff7dc4e4
export SKY=0xff91d7e3
export TEAL=0xff8bd5ca
export GREEN=0xffa6da95
export YELLOW=0xffeed49f
export PEACH=0xfff5a97f
export MAROON=0xffee99a0
export RED=0xffed8796
export MAUVE=0xffc6a0f6
export PINK=0xfff5bde6
export FLAMINGO=0xfff0c6c6
export ROSEWATER=0xfff4dbd6

# Tokyonight Night
#BLACK=0xff24283b
#WHITE=0xffa9b1d6
#MAGENTA=0xffbb9af7
#BLUE=0xff7aa2f7
#CYAN=0xff7dcfff
#GREEN=0xff9ece6a
#YELLOW=0xffe0af68
#ORANGE=0xffff9e64
#RED=0xfff7768e
#BAR_COLOR=0xff1a1b26
#COMMENT=0xff565f89

# Tokyonight Day
# BLACK=0xffe9e9ed
# WHITE=0xff3760bf
# MAGENTA=0xff9854f1
# BLUE=0xff2e7de9
# CYAN=0xff007197
# GREEN=0xff587539
# YELLOW=0xff8c6c3e
# ORANGE=0xffb15c00
# RED=0xfff52a65
# BAR_COLOR=0xffe1e2e7

GREY=0xff939ab7
TRANSPARENT=0x00000000

# General bar colors
export BAR_COLOR=$BASE
ICON_COLOR=$TEXT  # Color of all icons
LABEL_COLOR=$TEXT # Color of all labels

ITEM_DIR="$HOME/.config/sketchybar/items"
PLUGIN_DIR="$HOME/.config/sketchybar/plugins"

FONT="MonaspiceNe Nerd Font Mono"

PADDINGS=3

POPUP_BORDER_WIDTH=2
POPUP_CORNER_RADIUS=11
POPUP_BACKGROUND_COLOR=$BLACK
POPUP_BORDER_COLOR=$COMMENT

CORNER_RADIUS=12
BORDER_WIDTH=0

SHADOW=on

source "$(dirname "$0")/nix_path.sh"
