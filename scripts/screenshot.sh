#!/usr/bin/env bash
set -euo pipefail

dir="$HOME/Pictures/Screenshots"
time=$(date +'%Y_%m_%d_at_%Hh%Mm%Ss')
file="${dir}/Screenshot_${time}.png"

notify() {
    notify-send -a screenshot "Screenshot saved to $1"
}

# Hyprland is the only session here that speaks wlr-screencopy. Cinnamon's
# experimental Wayland session does not, so everything else uses the X11
# tools — which also covers Cinnamon on X11, the default session.
if [[ ${XDG_CURRENT_DESKTOP:-} == "Hyprland" ]]; then
    session=wayland
else
    session=x11
fi

copy_area() {
    if [[ $session == wayland ]]; then
        out=$(slurp) || exit 0
        grim -g "$out" - | wl-copy -t image/png
    else
        maim -s | xclip -selection clipboard -t image/png
    fi
}

save_screen() {
    if [[ $session == wayland ]]; then
        grim "$file"
    else
        maim "$file"
    fi
    notify "$file"
}

save_area() {
    if [[ $session == wayland ]]; then
        out=$(slurp) || exit 0
        grim -g "$out" "$file"
    else
        maim -s "$file" || exit 0
    fi
    notify "$file"
}

swappy_() {
    if [[ $session == wayland ]]; then
        out=$(slurp) || exit 0
        grim -g "$out" "$file"
    else
        maim -s "$file" || exit 0
    fi
    swappy -f "$file"
}

if [[ ! -d $dir ]]; then
    mkdir -p "$dir"
fi

if [[ $# -eq 0 ]]; then
    echo "Usage: screenshot --copy | --save | --swappy" >&2
    exit 1
fi

case "$1" in
    --copy) copy_area ;;
    --save) save_screen ;;
    --swappy) swappy_ ;;
    *)
        echo "Unknown option: $1" >&2
        echo "Usage: screenshot --copy | --save | --swappy" >&2
        exit 1
        ;;
esac
