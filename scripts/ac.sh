#!/usr/bin/env bash
# ac — the AC, one command, with NO Home Assistant.
#
# The ESP8266 (ac-control) owns the IR codes and exposes ESPHome's built-in
# web server, so this script just talks HTTP to the device itself:
#
#   ac                 status — power, temp, swing
#   ac on | off
#   ac 24              set the temperature (16..30)
#   ac up | ac down    nudge by one
#   ac up 3            nudge by three
#   ac swing on|off    swing
#
# Why the "nudge and re-send" fallback exists: the firmware de-duplicates
# commands against what it last transmitted (globals last_on/last_t/last_sw),
# so if the AC was changed with its own remote the ESP's idea can be stale and
# a matching command would be skipped silently. When the state does not change
# we nudge the temperature off its value and back; the AC's IR word carries the
# whole state (power, temp, swing), so that forces a real frame out.
set -euo pipefail

# The device's address by default; AC_ESP overrides it with another IP/host.
# 192.168.8.7 is the DHCP address it got on 'Zalhammad' (2026-11-27). There is
# no mDNS resolver on the fleet hosts, so the name is not used here.
ESP="${AC_ESP:-http://192.168.8.7}"

POWER="switch/AC"
SWING="switch/AC%20Swing"
TEMP="number/AC%20Temperature"

die() {
    echo "ac: $*" >&2
    exit 1
}

state() { # state <path> -> just the state string
    curl -s -m 5 "$ESP/$1" |
        python3 -c 'import json,sys; print(json.load(sys.stdin).get("state","?"))' \
            2> /dev/null || echo "?"
}

post() { # post <path> <action>
    local code
    code=$(curl -s -m 5 -o /dev/null -w '%{http_code}' -X POST "$ESP/$1/$2")
    [ "$code" = 200 ] || die "$1/$2 -> HTTP $code"
}

send() { # send <path> <action> -> "changed" | "unchanged"
    local ent="$1" action="$2" before after i=0
    before=$(state "$ent")
    post "$ent" "$action"
    after="$before"
    while [ "$i" -lt 10 ] && [ "$after" = "$before" ]; do
        sleep 0.2
        after=$(state "$ent")
        i=$((i + 1))
    done
    if [ -n "$after" ] && [ "$after" != "$before" ]; then
        echo changed
    else
        echo unchanged
    fi
}

set_power() { send "$POWER" "turn_$1"; }
set_swing() { send "$SWING" "turn_$1"; }
set_temp() { send "$TEMP" "set?value=$1"; }

force() { # force — nothing registered, so re-send for real
    local t n
    t=$(state "$TEMP")
    case "$t" in '' | '?') return 0 ;; esac
    n=$(python3 -c "t=float('$t'); print(int(t-1) if t > 16 else int(t+1))")
    set_temp "$n" > /dev/null || true
    set_temp "$t" > /dev/null || true
}

cmd="${1:-status}"
case "$cmd" in
    status)
        printf 'power: %s\n' "$(state "$POWER")"
        printf 'temp:  %s\n' "$(state "$TEMP")"
        printf 'swing: %s\n' "$(state "$SWING")"
        ;;
    on)
        if [ "$(set_power on)" = changed ]; then
            echo "ac on"
        else
            force
            echo "ac on (device already read on — nudged and re-sent so a frame actually went out)"
        fi
        ;;
    off)
        if [ "$(set_power off)" = changed ]; then
            echo "ac off"
        else
            force
            echo "ac off (device already read off — nudged and re-sent so a frame actually went out)"
        fi
        ;;
    swing)
        case "${2:-}" in
            on | off)
                action="$2"
                if [ "$(set_swing "$action")" = changed ]; then
                    echo "swing $action"
                else
                    force
                    echo "swing $action (device already read $action — nudged and re-sent so a frame actually went out)"
                fi
                ;;
            *) die "usage: ac swing on|off" ;;
        esac
        ;;
    up | down | + | -)
        n="${2:-1}"
        case "$cmd" in up | +) dir=1 ;; *) dir=-1 ;; esac
        case "$n" in
            '' | *[!0-9]*) die "nudge must be a whole number, got '$n'" ;;
        esac
        cur=$(state "$TEMP")
        tgt=$(python3 -c "
c, d, n = float('$cur'), $dir, int('$n')
t = c + d * n
print(int(min(30, max(16, t))))")
        if [ "$(set_temp "$tgt")" = changed ]; then
            echo "temp $tgt"
        else
            force
            echo "temp $tgt (clamped — device already read $tgt, nudged and re-sent so a frame actually went out)"
        fi
        ;;
    [0-9]*)
        case "$cmd" in
            1[6-9] | 2[0-9] | 30) ;;
            *) die "temp must be 16..30 (the protocol's real span)" ;;
        esac
        if [ "$(set_temp "$cmd")" = changed ]; then
            echo "temp $cmd"
        else
            force
            echo "temp $cmd (device already read $cmd — nudged and re-sent so a frame actually went out)"
        fi
        ;;
    *)
        die "usage: ac [status|on|off|<16-30>|up [n]|down [n]|swing on|off]"
        ;;
esac
