#!/usr/bin/env bash

NIX_PROFILES=${NIX_PROFILES:-"/Users/$(whoami).nix-profile /etc/profiles/per-user/$(whoami) /run/current-system/sw /nix/var/nix/profiles/default"}

for profile in ${NIX_PROFILES}; do
    if [ -e "${profile}" ]; then
        PATH="${profile}/bin:${PATH}"
    fi
done

export PATH
