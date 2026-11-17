#!/usr/bin/env bash

set -euo pipefail

# tput fails on terminals with no terminfo entry (e.g. xterm-kitty over ssh),
# so fall back to raw ANSI.
RESET=$(tput sgr0 2> /dev/null || printf '\033[0m')
RED=$(tput setaf 1 2> /dev/null || printf '\033[31m')
GREEN=$(tput setaf 2 2> /dev/null || printf '\033[32m')
BLUE=$(tput setaf 4 2> /dev/null || printf '\033[34m')

OK="[${GREEN}OK${RESET}]\t"
INFO="[${BLUE}INFO${RESET}]\t"
ERROR="[${RED}ERROR${RESET}]\t"

if [[ $EUID -eq 0 ]]; then
    echo -e "${ERROR}Do not run as root!"
    exit 1
fi

if ! command -v whiptail &> /dev/null; then
    echo -e "${INFO}Installing whiptail..."
    nix-shell -p newt --run "$(realpath "$0")"
    exit $?
fi

# DMI names are only a hint. They are missing on some boxes and generic on
# others (a plain desktop has seemed to be an HP laptop), and picking the
# wrong host installs the wrong hardware config — a silent, expensive
# mistake. So DMI only preselects the menu below, and the old 'hp' match is
# gone because it claimed every HP machine for victus. HOST=<host> skips
# the question; that is the only non-interactive path.
DMI_NAME="$(cat /sys/class/dmi/id/product_name 2> /dev/null || true)"
DMI_FAMILY="$(cat /sys/class/dmi/id/product_family 2> /dev/null || true)"

gpu_for() {
    case "$1" in
        victus) echo "nvidia" ;;
        t480s) echo "intel" ;;
        asus) echo "none" ;;
        *) echo "none" ;;
    esac
}

detect_host() {
    if grep -qi 't480s\|thinkpad\|20L8' <<< "$DMI_NAME"; then
        echo "t480s"
    elif grep -qi 'victus' <<< "$DMI_NAME$DMI_FAMILY"; then
        echo "victus"
    elif grep -qi 'x509\|asus' <<< "$DMI_NAME$DMI_FAMILY"; then
        echo "asus"
    else
        echo ""
    fi
}

radio() {
    [ "$1" = "$2" ] && printf 'ON' || printf 'OFF'
}

if [ -n "${HOST:-}" ]; then
    echo -e "${INFO}Host forced by environment: ${GREEN}$HOST${RESET}"
else
    DETECTED="$(detect_host)"
    HOST=$(whiptail --title "NixOS Installer" --radiolist \
        "Which machine is this?\n\nDMI name='${DMI_NAME}' family='${DMI_FAMILY}'\n\nDMI is a guess, not proof: confirm the host yourself." \
        18 78 5 \
        "victus" "HP Victus - laptop, NVIDIA" "$(radio victus "$DETECTED")" \
        "t480s" "ThinkPad T480s - laptop, Intel" "$(radio t480s "$DETECTED")" \
        "asus" "ASUS X509 - headless server" "$(radio asus "$DETECTED")" \
        "grandpa" "Grandpa - headless server, GT 210" "$(radio grandpa "$DETECTED")" \
        3>&1 1>&2 2>&3) || exit 0
    if [ -z "$HOST" ]; then
        echo -e "${ERROR}No host selected."
        exit 1
    fi
fi

GPU="$(gpu_for "$HOST")"

CONFIG_USER="$(sed -n 's/.*username = "\([^"]*\)".*/\1/p' "hosts/${HOST}/variables.nix" 2> /dev/null | head -1)"
SUMMARY="\
Username:   ${CONFIG_USER:-unknown} (from variables.nix)
Host:       ${HOST:-unknown}
GPU:        ${GPU:-unknown}
DMI seen:   name='${DMI_NAME:-}' family='${DMI_FAMILY:-}'"

if ! (whiptail --yesno "$SUMMARY\n\nProceed with installation?" 12 40 --title "NixOS Installer"); then
    exit 0
fi

# variables.nix is the source of truth; `whoami` is "nixos" on the live ISO.
TARGET_USER="${TARGET_USER:-}"
if [ -n "$TARGET_USER" ]; then
    echo -e "${INFO}Overriding username to ${GREEN}$TARGET_USER${RESET}"
    sed -i -e "s/username = \"[^\"]*\"/username = \"$TARGET_USER\"/" "hosts/${HOST}/variables.nix"
else
    echo -e "${INFO}Using username from hosts/${HOST}/variables.nix"
fi

# Desktop hosts only: the headless ones never load a wallpaper.
if [ "$GPU" != "none" ]; then
    echo -e "${INFO}Preparing environment"
    mkdir -p ~/Music ~/Documents ~/Pictures/wallpapers/others
    ln -sf "$PWD/assets/wallpapers/wallpaper.png" ~/Pictures/wallpapers/wallpaper 2> /dev/null || true
fi

if [ ! -f /etc/nixos/hardware-configuration.nix ]; then
    echo -e "${ERROR}/etc/nixos/hardware-configuration.nix not found! Aborting."
    exit 1
fi
# asus mounts by label on purpose (the SSD and the HDD can be swapped or the
# HDD moved to a USB enclosure), so never replace that file with the
# UUID-based output of the installer.
if [ "$HOST" = "asus" ]; then
    echo -e "${INFO}Keeping hosts/asus/hardware-configuration.nix (label-based mounts)"
else
    cp /etc/nixos/hardware-configuration.nix "hosts/${HOST}/hardware-configuration.nix"
fi

echo -e "${INFO}Starting system build..."
sudo nixos-rebuild switch --flake ."#${HOST}"

echo -e "${OK}Done! Reboot to apply."
