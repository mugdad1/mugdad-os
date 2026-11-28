#!/usr/bin/env bash
set -euo pipefail

# toggle all outputs' power (DPMS off/on) without sleeping the machine
if [[ ${XDG_CURRENT_DESKTOP:-} == "Hyprland" ]]; then
    wlopm --toggle "*"
else
    if xset q | grep -q "Monitor is On"; then
        xset dpms force off
    else
        xset dpms force on
    fi
fi
