#!/usr/bin/env bash
# Smoke test for the thumbnail pipeline and apply logic. Needs ImageMagick only
# (no Quickshell, no Wayland). Run: tests/smoke.sh
# shellcheck disable=SC2016,SC2034  # checks are eval'd strings; vars are used inside them
set -u

repo="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
launcher="$repo/bin/qs-bgselector"
fails=0
pass() { printf '  ok   %s\n' "$1"; }
fail() { printf '  FAIL %s\n' "$1"; fails=$((fails + 1)); }
check() { if eval "$2"; then pass "$1"; else fail "$1"; fi; }

if command -v magick >/dev/null 2>&1; then IM=magick; ID="magick identify"; else IM=convert; ID=identify; fi

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
export HOME="$tmp/home" XDG_CACHE_HOME="$tmp/cache" XDG_CONFIG_HOME="$tmp/config"
mkdir -p "$HOME"
unset BGSEL_CONFIG BGSEL_WALL_DIR

walls="$tmp/walls"
mkdir -p "$walls/sub dir" "$walls/a" "$walls/a_b"
"$IM" -size 1000x500 xc:red   "$walls/red.png"
"$IM" -size 300x700  xc:blue  "$walls/blue.jpg"
"$IM" -size 640x480  xc:green "$walls/we ird [1] name.png"
"$IM" -size 640x480  xc:white "$walls/sub dir/white.webp" 2>/dev/null || "$IM" -size 640x480 xc:white "$walls/sub dir/white.png"
"$IM" -size 200x200 xc:red xc:blue -delete 0 -loop 0 "$walls/anim.gif" 2>/dev/null || "$IM" -size 200x200 xc:red "$walls/anim.gif"
"$IM" -size 200x200 xc:red "$walls/a/b_c.png"
"$IM" -size 200x200 xc:blue "$walls/a_b/c.png"
echo "not an image" > "$walls/broken.jpg"
n_images=7   # broken.jpg is listed but must be skipped

export BGSEL_WALL_DIR="$walls"
list="$XDG_CACHE_HOME/qs-bgselector"

echo "thumbnail cache"
out="$("$launcher" --prepare 2>&1)"; rc=$?
check "prepare succeeds"                 '[ $rc -eq 0 ]'
check "reports generated thumbnails"     'grep -q "Generated $n_images thumbnails" <<<"$out"'
check "warns about the broken image"     'grep -q "1 image(s) could not be read" <<<"$out"'
list_file="$(find "$list" -name .list)"
check "list has one line per good image" '[ "$(wc -l < "$list_file")" -eq $n_images ]'
check "list lines have 3 tab fields"     '! awk -F"\t" "NF!=3" "$list_file" | grep -q .'
check "bracket/space name is listed"     'grep -qF "we ird [1] name.png" "$list_file"'
check "a/b_c and a_b/c do not collide"   '[ "$(find "$(dirname "$list_file")" -name "*.jpg" | wc -l)" -eq $n_images ]'
thumb="$(cut -f2 "$list_file" | head -1)"
check "thumbnails are 800x600"           '[ "$($ID -format "%wx%h" "$thumb" 2>/dev/null | head -1)" = 800x600 ]'

out="$("$launcher" --prepare 2>&1)"
check "second run takes the fast path"   'grep -q "Cache up to date" <<<"$out"'

rm "$walls/red.png"
"$launcher" --prepare >/dev/null 2>&1
check "removed wallpaper leaves the list" '! grep -qF "red.png" "$list_file"'
check "its thumbnail is cleaned up"       '[ "$(find "$(dirname "$list_file")" -name "*.jpg" | wc -l)" -eq $((n_images - 1)) ]'

out="$("$launcher" --rebuild --prepare 2>&1)"
check "--rebuild regenerates everything"  'grep -q "Generated $((n_images - 1)) thumbnails" <<<"$out"'

echo "apply / restore / random"
applied="$tmp/applied"
export BGSEL_BACKEND=custom BGSEL_SET_CMD='printf "%s\n" "$BGSEL_WALLPAPER" > "$APPLIED_OUT"' APPLIED_OUT="$applied"
export BGSEL_THEME=none BGSEL_THEME_DELAY=0 BGSEL_POST_CMD='printf post > "$APPLIED_OUT.post"'
bash "$repo/scripts/apply.sh" "$walls/blue.jpg"
check "custom backend gets the path"      '[ "$(cat "$applied")" = "$walls/blue.jpg" ]'
check "current link is written"           '[ "$(readlink "$XDG_CACHE_HOME/current-wallpaper")" = "$walls/blue.jpg" ]'
check "post hook ran"                     '[ "$(cat "$applied.post")" = post ]'

rm -f "$applied" "$applied.post"
"$launcher" --restore
check "--restore re-applies current"      '[ "$(cat "$applied")" = "$walls/blue.jpg" ]'
check "--restore skips the post hook"     '[ ! -e "$applied.post" ]'

rm -f "$applied"
"$launcher" --random
check "--random applies something else"   '[ -s "$applied" ] && [ "$(cat "$applied")" != "$walls/blue.jpg" ]'

echo "misc"
"$launcher" --doctor >/dev/null 2>&1; rc=$?
check "--doctor runs (exit 0 or 1)"       '[ $rc -le 1 ]'
check "--help works"                      '"$launcher" --help | grep -q Usage'
check "unknown option fails"              '! "$launcher" --nope >/dev/null 2>&1'
check "missing dir is a clean error"      '! BGSEL_WALL_DIR="$tmp/nope" "$launcher" --prepare >/dev/null 2>&1'

echo
if [ $fails -eq 0 ]; then echo "all passed"; else echo "$fails failed"; exit 1; fi
