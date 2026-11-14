#!/usr/bin/env bash
set -euo pipefail

SERVICE=".waybar-wrapped"

if pgrep -x "$SERVICE" > /dev/null; then
    pkill -9 waybar
else
    # The default config (modules/home/desktop/waybar/settings.nix) is the
    # Hyprland one, so a plain start works in every session.
    runbg waybar
fi
