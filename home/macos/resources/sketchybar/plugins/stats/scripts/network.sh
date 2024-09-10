#!/usr/bin/env bash

source "$HOME/.config/sketchybar/nix_path.sh"
UPDOWN=$(ifstat -i "en0" -b 0.1 1 | tail -n1)
DOWN=$(echo "$UPDOWN" | awk "{ print \$1 }" | cut -d. -f1)
UP=$(echo "$UPDOWN" | awk "{ print \$2 }" | cut -d. -f1)

function human_readable() {
	local abbrevs=(
		$((1 << 60)):ZiB
		$((1 << 50)):EiB
		$((1 << 40)):TiB
		$((1 << 30)):GiB
		$((1 << 20)):MiB
		$((1 << 10)):KiB
		$((1)):B
	)

	local bytes="$(echo ${1} \* 1000 | bc)"
	local precision="${2}"

	for item in "${abbrevs[@]}"; do
		local factor="${item%:*}"
		local abbrev="${item#*:}"
		if [[ "${bytes}" -ge "${factor}" ]]; then
			local size="$(bc -l <<<"${bytes} / ${factor}")"
			printf "%.*f %s\n" "${precision}" "${size}" "${abbrev}"
			break
		fi
	done
}

DOWN_FORMAT=$(human_readable $DOWN 1)
UP_FORMAT=$(human_readable $UP 1)

sketchybar -m --set network.down label="$DOWN_FORMAT" icon.highlight=$(if [ "$DOWN" -gt "0" ]; then echo "on"; else echo "off"; fi) \
	--set network.up label="$UP_FORMAT" icon.highlight=$(if [ "$UP" -gt "0" ]; then echo "on"; else echo "off"; fi)
