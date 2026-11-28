#!/usr/bin/env bash
set -euo pipefail

if [[ $# -eq 0 ]]; then
    echo "Usage: wall-change <image-path>" >&2
    exit 1
fi

# Cinnamon draws its own background from dconf and has no awww daemon, so the
# X11 session sets picture-uri directly. realpath is used because the picker
# hands over ~/Pictures/wallpapers/wallpaper, a symlink that is swapped on
# every change — Cinnamon has to be told the new target, not the old symlink.
if [[ ${XDG_CURRENT_DESKTOP:-} == "Hyprland" ]]; then
    animations=("outer" "center" "any" "wipe")
    random_animation=${animations[RANDOM % ${#animations[@]}]}

    if [[ "$random_animation" == "wipe" ]]; then
        awww img --transition-type="wipe" --transition-angle=135 "$1" &
    else
        awww img --transition-type="$random_animation" "$1" &
    fi
else
    gsettings set org.cinnamon.desktop.background picture-uri "file://$(realpath "$1")"
fi
