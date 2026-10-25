#!/usr/bin/env bash
# Apply a wallpaper: set it with the configured backend, record it as the
# current wallpaper, then (optionally) run theming and a post hook.
#
# Usage: apply.sh [--restore] /absolute/path/to/image
#
# Configuration comes from BGSEL_* environment variables (exported by the
# qs-bgselector launcher). --restore skips theming/hooks and any transition.

set -u

restore=0
if [ "${1:-}" = "--restore" ]; then restore=1; shift; fi

path="${1:-}"
[ -n "$path" ] || { echo "apply.sh: no wallpaper given" >&2; exit 2; }
case "$path" in /*) ;; *) path="$PWD/$path" ;; esac
[ -f "$path" ] || { echo "apply.sh: not a file: $path" >&2; exit 1; }

have() { command -v "$1" >/dev/null 2>&1; }
log()  { printf 'qs-bgselector: %s\n' "$*" >&2; }

BACKEND="${BGSEL_BACKEND:-auto}"
TRANSITION="${BGSEL_TRANSITION:-fade}"
[ $restore -eq 1 ] && TRANSITION=none

# ---- backend selection -----------------------------------------------------
detect_backend() {
    local b
    # 1) If in Wayland, check running Wayland wallpaper daemons first
    if [ -n "${WAYLAND_DISPLAY:-}" ]; then
        for b in awww swww; do
            have "$b" && pgrep -x "$b-daemon" >/dev/null 2>&1 && { echo "$b"; return; }
        done
        have hyprpaper && pgrep -x hyprpaper >/dev/null 2>&1 && { echo hyprpaper; return; }
        for b in awww swww hyprpaper swaybg; do
            have "$b" && { echo "$b"; return; }
        done
    fi

    # 2) If in X11 (or fallback), check X11 wallpaper setters
    if [ -n "${DISPLAY:-}" ]; then
        for b in feh nitrogen xwallpaper hsetroot; do
            have "$b" && { echo "$b"; return; }
        done
    fi

    # 3) Otherwise check any installed tool in order of preference
    for b in feh nitrogen xwallpaper hsetroot awww swww hyprpaper swaybg; do
        have "$b" && { echo "$b"; return; }
    done
    echo none
}

# awww and swww share the same CLI; start the daemon if nobody did.
set_daemon_backend() {
    local tool="$1"
    if ! "$tool" query >/dev/null 2>&1; then
        ( "$tool-daemon" >/dev/null 2>&1 & )
        for _ in $(seq 1 30); do
            sleep 0.1
            "$tool" query >/dev/null 2>&1 && break
        done
    fi
    "$tool" img "$path" -t "$TRANSITION" \
        --transition-duration "${BGSEL_TRANSITION_DURATION:-1.5}" \
        --transition-fps "${BGSEL_TRANSITION_FPS:-60}" \
        --transition-bezier "${BGSEL_TRANSITION_BEZIER:-.4,0,.2,1}" &
}

set_hyprpaper() {
    # Best effort: works with hyprpaper's IPC. Newer versions may differ.
    hyprctl hyprpaper preload "$path" >/dev/null 2>&1
    hyprctl hyprpaper wallpaper ",$path" >/dev/null 2>&1 \
        || log "hyprpaper did not accept the IPC call; use BGSEL_SET_CMD for your version"
}

set_swaybg() {
    local old
    old="$(pgrep -x swaybg 2>/dev/null)"
    ( nohup swaybg -i "$path" -m fill >/dev/null 2>&1 & )
    sleep 0.3
    # shellcheck disable=SC2086
    [ -n "$old" ] && kill $old 2>/dev/null
}

set_feh() {
    feh --bg-fill "$path"
}

set_nitrogen() {
    nitrogen --set-zoom-fill --save "$path"
}

set_xwallpaper() {
    xwallpaper --zoom "$path"
}

set_hsetroot() {
    hsetroot -fill "$path"
}

# A custom command always beats auto-detection.
if [ "$BACKEND" = auto ]; then
    if [ -n "${BGSEL_SET_CMD:-}" ]; then BACKEND=custom; else BACKEND="$(detect_backend)"; fi
fi

case "$BACKEND" in
    feh)
        have feh || { log "backend 'feh' is not installed"; exit 1; }
        set_feh ;;
    nitrogen)
        have nitrogen || { log "backend 'nitrogen' is not installed"; exit 1; }
        set_nitrogen ;;
    xwallpaper)
        have xwallpaper || { log "backend 'xwallpaper' is not installed"; exit 1; }
        set_xwallpaper ;;
    hsetroot)
        have hsetroot || { log "backend 'hsetroot' is not installed"; exit 1; }
        set_hsetroot ;;
    awww|swww)
        have "$BACKEND" || { log "backend '$BACKEND' is not installed"; exit 1; }
        set_daemon_backend "$BACKEND" ;;
    hyprpaper)
        have hyprctl || { log "hyprpaper backend needs hyprctl"; exit 1; }
        set_hyprpaper ;;
    swaybg)
        have swaybg || { log "backend 'swaybg' is not installed"; exit 1; }
        set_swaybg ;;
    custom)
        [ -n "${BGSEL_SET_CMD:-}" ] || { log "BGSEL_BACKEND=custom needs BGSEL_SET_CMD"; exit 1; }
        BGSEL_WALLPAPER="$path" bash -c "$BGSEL_SET_CMD" ;;
    none)
        log "no wallpaper backend found (install feh, nitrogen, xwallpaper, hsetroot, awww, swww, hyprpaper or swaybg, or set BGSEL_SET_CMD)"
        exit 1 ;;
    *)
        log "unknown BGSEL_BACKEND '$BACKEND'"
        exit 1 ;;
esac

# ---- remember it -----------------------------------------------------------
link="${BGSEL_CURRENT_LINK:-${XDG_CACHE_HOME:-$HOME/.cache}/current-wallpaper}"
mkdir -p "$(dirname -- "$link")" && ln -sfn "$path" "$link"

[ $restore -eq 1 ] && exit 0

# ---- theming ---------------------------------------------------------------
# Give the transition a moment to start before the (slower) theme step.
sleep "${BGSEL_THEME_DELAY:-0.4}"

theme="${BGSEL_THEME:-auto}"
[ "$theme" = auto ] && { have matugen && theme=matugen || theme=none; }

case "$theme" in
    matugen)
        if have matugen; then
            read -ra margs <<< "${BGSEL_MATUGEN_ARGS:---source-color-index 0 -t scheme-smart}"
            matugen image "$path" "${margs[@]}" || log "matugen failed (wallpaper was still applied)"
        else
            log "BGSEL_THEME=matugen but matugen is not installed"
        fi ;;
    wal)
        if have wal; then wal -i "$path" >/dev/null || log "wal failed (wallpaper was still applied)"
        else log "BGSEL_THEME=wal but pywal is not installed"; fi ;;
    none) ;;
    *) log "unknown BGSEL_THEME '$theme'" ;;
esac

# ---- post hook -------------------------------------------------------------
if [ -n "${BGSEL_POST_CMD:-}" ]; then
    BGSEL_WALLPAPER="$path" bash -c "$BGSEL_POST_CMD" || log "BGSEL_POST_CMD failed"
fi

exit 0