#!/bin/sh
# Start hyprlock reliably.
#
# The old `pidof hyprlock || hyprlock` trusted any running hyprlock. If one got
# stuck (alive but never actually locking), every later lock was silently skipped.
# This script only trusts a hyprlock that started in the last few seconds, and
# replaces anything older with a fresh one.
#
# That's safe: if a working hyprlock is killed, Hyprland keeps the session locked,
# and misc:allow_session_lock_restore (set in hyprland.lua) lets the new one take over.

# Lid-close fires both the Hyprland lid bind and hypridle at once: run one at a time.
exec 9>"${XDG_RUNTIME_DIR:-/tmp}/hypr-lock.sh.lock"
flock -w 5 9 || exit 0

pid=$(pidof -s hyprlock)
if [ -n "$pid" ]; then
    age=$(ps -o etimes= -p "$pid" 2>/dev/null | tr -d ' ')
    # Just started by the other trigger: leave it alone.
    [ "${age:-0}" -lt 15 ] && exit 0

    pkill -x hyprlock
    i=0
    while pidof -s hyprlock >/dev/null && [ $i -lt 20 ]; do sleep 0.1; i=$((i+1)); done
    pidof -s hyprlock >/dev/null && pkill -9 -x hyprlock
fi

# Don't let hyprlock inherit the flock fd, or a stuck hyprlock would block us again.
hyprlock 9>&- >/dev/null 2>&1 &
