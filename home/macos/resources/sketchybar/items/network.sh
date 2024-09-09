sketchybar --add item ip_address right \
    --set ip_address script="$PLUGIN_DIR/ip_address.sh" \
    update_freq=30 \
    background.height=26 \
    background.corner_radius="$CORNER_RADIUS" \
    background.border_width="$BORDER_WIDTH" \
    background.border_color="$COLOR" \
    background.padding_right=5 \
    background.color="$BAR_COLOR" \
    background.drawing=on \
    label.padding_right=10 \
    icon.padding_left=10 \
    icon.color=$BLUE \
    label.color=$BLUE \
    --subscribe ip_address wifi_change

sketchybar --add item network.up right \
    --set network.up script="$PLUGIN_DIR/network.sh" \
    update_freq=2 \
    background.height=26 \
    background.corner_radius="$CORNER_RADIUS" \
    background.border_width="$BORDER_WIDTH" \
    background.border_color="$COLOR" \
    background.padding_right=5 \
    background.color="$BAR_COLOR" \
    background.drawing=on \
    label.padding_right=10 \
    icon=⇡ \
    icon.padding_left=10 \
    icon.color=$YELLOW \
    label.color=$YELLOW

sketchybar --add item network.down right \
    --set network.down script="$PLUGIN_DIR/network.sh" \
    update_freq=2 \
    background.height=26 \
    background.corner_radius="$CORNER_RADIUS" \
    background.border_width="$BORDER_WIDTH" \
    background.border_color="$COLOR" \
    background.padding_right=5 \
    background.color="$BAR_COLOR" \
    background.drawing=on \
    icon=⇣ \
    icon.padding_left=10 \
    label.padding_right=10 \
    icon.color=$GREEN \
    label.color=$GREEN

# Bracket
# sketchybar --add bracket status ip_address network.up network.down
