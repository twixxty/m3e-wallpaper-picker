#!/usr/bin/env bash
# Remove qs-bgselector.
#
#   ./uninstall.sh                 remove from ~/.local (config and cache are kept)
#   ./uninstall.sh --prefix /usr   remove a system-wide install
#   ./uninstall.sh --purge         also delete your config and thumbnail cache

set -eu

prog=qs-bgselector
prefix="${PREFIX:-$HOME/.local}"
purge=0

while [ $# -gt 0 ]; do
    case "$1" in
        --prefix) prefix="${2:?--prefix needs a directory}"; shift ;;
        --purge)  purge=1 ;;
        -h|--help) sed -n '2,6p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'; exit 0 ;;
        *) echo "unknown option: $1" >&2; exit 2 ;;
    esac
    shift
done

rm -fv "$prefix/bin/$prog"
rm -rfv "$prefix/share/$prog"

if [ $purge -eq 1 ]; then
    rm -rfv "${XDG_CONFIG_HOME:-$HOME/.config}/$prog"
    rm -rfv "${XDG_CACHE_HOME:-$HOME/.cache}/$prog"
else
    echo "Kept your config (${XDG_CONFIG_HOME:-$HOME/.config}/$prog) and cache. Use --purge to delete them."
fi
