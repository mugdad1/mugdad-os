#!/usr/bin/env bash
set -euo pipefail

# toggle mic on/off
if [[ ${XDG_CURRENT_DESKTOP:-} == "Hyprland" ]]; then
    swayosd-client --input-volume=mute-toggle
else
    # swayosd is a Wayland OSD; on X11 Cinnamon shows its own indicator.
    wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle
fi

# set mic status led on/off accordingly
micStatus=$(wpctl get-volume @DEFAULT_AUDIO_SOURCE@ | grep -c MUTED || true)
brightnessctl -d platform::micmute set "$micStatus" || true
