#!/usr/bin/env bash
set -euo pipefail

# foot is Wayland-only; Cinnamon's default session is X11. Both accept -e,
# so callers can keep using `terminal -e btop`.
if [[ ${XDG_CURRENT_DESKTOP:-} == "Hyprland" ]]; then
    exec foot "$@"
else
    exec alacritty "$@"
fi
