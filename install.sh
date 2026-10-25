#!/usr/bin/env bash
# Installer for qs-bgselector.
#
#   ./install.sh                  install to ~/.local
#   ./install.sh --prefix /usr    install system-wide (run with sudo)
#   ./install.sh --dev            symlink to this checkout instead of copying
#   ./install.sh --no-config      do not create ~/.config/qs-bgselector/config
#
# DESTDIR is honoured for packaging. Nothing is installed with a package
# manager; missing dependencies are reported at the end.

set -eu

prog=qs-bgselector
repo="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
prefix="${PREFIX:-$HOME/.local}"
dev=0
make_config=1

while [ $# -gt 0 ]; do
    case "$1" in
        --prefix)    prefix="${2:?--prefix needs a directory}"; shift ;;
        --dev)       dev=1 ;;
        --no-config) make_config=0 ;;
        -h|--help)   sed -n '2,11p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'; exit 0 ;;
        *) echo "unknown option: $1" >&2; exit 2 ;;
    esac
    shift
done

dest="${DESTDIR:-}$prefix"
share="$dest/share/$prog"
bin="$dest/bin"

mkdir -p "$bin"

if [ $dev -eq 1 ]; then
    ln -sfn "$repo/bin/$prog" "$bin/$prog"
    echo "Linked $bin/$prog -> $repo/bin/$prog"
else
    rm -rf "$share"
    mkdir -p "$share"
    cp -r "$repo/qml" "$repo/scripts" "$repo/config" "$share/"
    chmod +x "$share/scripts/apply.sh"
    install -m 755 "$repo/bin/$prog" "$bin/$prog"
    echo "Installed $bin/$prog"
    echo "Installed files in $share"
fi

if [ $make_config -eq 1 ] && [ -z "${DESTDIR:-}" ]; then
    cfg_dir="${XDG_CONFIG_HOME:-$HOME/.config}/$prog"
    if [ ! -e "$cfg_dir/config" ]; then
        mkdir -p "$cfg_dir"
        cp "$repo/config/config.example" "$cfg_dir/config"
        echo "Created $cfg_dir/config (edit it to taste)"
    else
        echo "Kept existing $cfg_dir/config"
    fi
    mkdir -p "$cfg_dir"
    cp "$repo/config/colors.template" "$cfg_dir/colors.template"
    echo "Installed matugen template: $cfg_dir/colors.template"
fi

in_path=1
case ":$PATH:" in
    *":$prefix/bin:"*) ;;
    *) in_path=0
       echo
       echo "Note: $prefix/bin is not in your PATH, so '$prog' will say 'command not found'."
       echo "  fish:      fish_add_path $prefix/bin"
       echo "  bash/zsh:  echo 'export PATH=\"$prefix/bin:\$PATH\"' >> ~/.profile   (then log in again)"
       echo "  or run it with the full path: $bin/$prog" ;;
esac

if [ -z "${DESTDIR:-}" ]; then
    echo
    echo "Checking your setup..."
    echo
    if "$bin/$prog" --doctor; then
        ok=1
    else
        ok=0
        echo
        echo "Install the missing required items above, then re-run: $prog --doctor"
    fi

    echo
    echo "Installed. Next steps:"
    echo "  1. Put wallpapers in ~/Pictures/Wallpapers (or set BGSEL_WALL_DIR in the config)"
    if [ $in_path -eq 1 ]; then echo "  2. Try it:          $prog"; else echo "  2. Try it:          $bin/$prog   (or fix PATH, see above)"; fi
    echo "  3. Bind a key, e.g. Hyprland:"
    echo "       bind = SUPER, W, exec, $bin/$prog"
    echo "       exec-once = $bin/$prog --restore"
    [ "${ok:-0}" -eq 1 ] || echo "  (some required dependencies are missing, see the checks above)"
fi
