#!/usr/bin/env bash

source "$HOME/.config/sketchybar/nix_path.sh"
source "$HOME/.config/sketchybar/colors.sh"
source "$HOME/.config/sketchybar/icons.sh"
source "$HOME/.config/sketchybar/userconfig.sh" # Loads all defined variables

render_bar_item() {
    # Default values
    COLOR="$GREY"
    ICON="$BACKREST_UNKNOWN"
    LABEL="Backup Unknown"

    BACKUP_STATUS=""
    ANY_ERROR=false
    ANY_RUNNING=false
    ALL_SUCCESS=true

    # Iterate through backup status files
    for plan_file in "$HOME/.config/backrest/status/"*; do
        plan="$(basename "$plan_file")"
        output="$(cat "$plan_file")"
        status="$(echo "$output" | awk '{print $1}')"
        date="$(echo "$output" | awk '{print $2}')"

        # Accumulate backup statuses for the popup
        BACKUP_STATUS+="$(printf "%-25s" "$plan")\t$(printf "%-10s" "$status")\t$date\n"

        case $status in
            "success")
                # Do nothing, defaults to success
                ;;
            "error")
                ANY_ERROR=true
                ALL_SUCCESS=false
                ;;
            "running")
                ANY_RUNNING=true
                ALL_SUCCESS=false
                ;;
            *)
                # Unknown or other statuses
                ALL_SUCCESS=false
                ;;
        esac
    done

    # Decide global status based on collected information
    if [ "$ANY_ERROR" = true ]; then
        COLOR="$RED"
        ICON="$BACKREST_ERROR"
        LABEL="Backup Error"
    elif [ "$ANY_RUNNING" = true ]; then
        COLOR="$BLUE"
        ICON="$BACKREST_RUNNING"
        LABEL="Backup Running"
    elif [ "$ALL_SUCCESS" = true ]; then
        COLOR="$GREEN"
        ICON="$BACKREST_SUCCESS"
        LABEL="Backup OK"
    else
        COLOR="$GREY"
        ICON="$BACKREST_UNKNOWN"
        LABEL="Backup Unknown"
    fi

    # Check if backrest service is running
    backrest_status=$(brew services info backrest --json | jq '.[0].running')

    if [ "$backrest_status" != "true" ]; then
        COLOR="$GREY"
        ICON="$BACKREST_UNKNOWN"
        LABEL="Backrest Not Running"
    fi

    # Update the bar item
    sketchybar --set "$NAME" icon.color="$COLOR" icon="$ICON" label="$LABEL"
}

render_popup() {
    # Remove existing popup items
    args=(--remove '/backrest.details.plan\.*/')

    COUNTER=0

    # Split BACKUP_STATUS into lines
    IFS=$'\n'
    for line in $(echo -e "$BACKUP_STATUS"); do
        COUNTER=$((COUNTER + 1))
        plan_status="$(echo "$line" | sed -e "s/^'//" -e "s/'$//")"

        # Determine the color based on status
        status="$(echo "$plan_status" | awk '{print $2}')"

        case $status in
            "success")
                ICON_COLOR="$GREEN"
                ICON="$BACKREST_SUCCESS"
                ;;
            "error")
                ICON_COLOR="$RED"
                ICON="$BACKREST_ERROR"
                ;;
            "running")
                ICON_COLOR="$BLUE"
                ICON="$BACKREST_RUNNING"
                ;;
            *)
                ICON_COLOR="$GREY"
                ICON="$BACKREST_UNKNOWN"
                ;;
        esac

        backrest_popup_item=(
            label="$plan_status"
            label.color="$TEXT"
            icon.drawing=on
            icon.color="$ICON_COLOR"
            icon="$ICON"
            label.padding_left=10
            label.padding_right=10
            position=popup."$NAME"
            drawing=on
        )

        args+=(--clone backrest.details.plan."$COUNTER" backrest.details)
        args+=(--set backrest.details.plan."$COUNTER" "${backrest_popup_item[@]}")
    done

    # Apply the arguments to sketchybar
    sketchybar -m "${args[@]}" >/dev/null
}

popup() {
    sketchybar --set "$NAME" popup.drawing="$1"
}

case "$SENDER" in
    "routine" | "forced")
        render_bar_item
        render_popup
        ;;
    "mouse.entered")
        popup on
        ;;
    "mouse.exited" | "mouse.exited.global")
        popup off
        ;;
    "mouse.clicked")
        popup toggle
        ;;
esac
