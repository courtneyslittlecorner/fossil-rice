#!/bin/sh
# Mare Antiquum screensaver (Quickshell). Usage: screensaver.sh start|stop|toggle
# hypridle starts it after a few idle minutes and stops it when you come back.
dir="$HOME/.config/quickshell-screensaver"
running() { pgrep -f "quickshell.* -p $dir/shell.qml" >/dev/null; }
case "${1:-start}" in
    start)
        running && exit 0
        QML_IMPORT_PATH="$HOME/.nix-profile/lib/qt-6/qml" setsid -f qs -p "$dir/shell.qml" >/dev/null 2>&1 </dev/null ;;
    stop)
        pkill -f "quickshell.* -p $dir/shell.qml" ;;
    toggle)
        if running; then "$0" stop; else "$0" start; fi ;;
esac
exit 0
