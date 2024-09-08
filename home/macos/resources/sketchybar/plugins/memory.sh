#!/usr/bin/env bash

sketchybar --set "$NAME" icon="" label="$(vm_stat | awk '/page size of/ {page_size=$8} /Pages free:/ {free=$3} /Pages active:/ {active=$3} /Pages wired down:/ {wired=$4} /Pages occupied by compressor:/ {compressed=$5} END {total=(active+wired+compressed+free)*page_size; used=(active+wired+compressed)*page_size; printf "%.2f\n", used/total*100}')"
