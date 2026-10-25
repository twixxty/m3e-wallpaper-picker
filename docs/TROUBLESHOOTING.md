# Troubleshooting

Start with `qs-bgselector --doctor`. It lists what is installed, which wallpaper
backend would be used, where the config and cache live, and how many images were found.

## Nothing happens when I press the keybind
Run `qs-bgselector` from a terminal; errors are printed there (and shown as a
notification if `notify-send` exists). Common causes:
- `quickshell` is not in the `PATH` that your window manager or compositor uses. Use the full path in the keybind.
- Another picker is already open (only one instance is allowed).
- Neither `DISPLAY` (X11) nor `WAYLAND_DISPLAY` (Wayland) is set.

## The background behind the carousel is black instead of translucent
On X11, translucent window overlays require an X11 compositor (such as `picom` or `compton`).
Run a compositor in your autostart:
```bash
picom -b
```
Without a compositor running, X11 cannot perform alpha blending on the root window, so the backdrop appears solid black.

## "Type Picker unavailable" / QML errors
Your Quickshell is too old or too new for this QML. The picker uses
`Quickshell.Widgets` (`ClippingRectangle`), so it needs a Quickshell build that
ships that module. Update Quickshell and open an issue with the output of
`quickshell --version` and the log it prints.

## The picker is empty
- Check the directory: `qs-bgselector --doctor`.
- Only jpg, jpeg, png, webp, gif, bmp, tif, tiff and avif are listed. For webp
  and avif, ImageMagick needs the matching delegates installed.
- Images ImageMagick cannot read are skipped with a warning.

## Thumbnails look stale
`qs-bgselector --rebuild --prepare` throws the cache away and rebuilds it.

## Wallpaper does not change
- On X11, ensure you have an X11 setter installed: `feh`, `nitrogen`, `xwallpaper`, or `hsetroot`.
- On Wayland, ensure you have `awww`, `swww`, `hyprpaper`, or `swaybg`.
- `BGSEL_BACKEND=auto` picks a running daemon first, then the first installed tool. Force one with `BGSEL_BACKEND=feh` or `BGSEL_BACKEND=swaybg`, for example.
- For anything else use `BGSEL_SET_CMD`. The image path is in `$BGSEL_WALLPAPER`.

## Colors did not update
Theming only runs when `matugen` (or `wal`) is installed and `BGSEL_THEME` is
not `none`. A theme failure never undoes the wallpaper change; the error is
printed to stderr.

## Fonts
The default font is JetBrains Mono. If it is not installed Qt falls back to a
system font. Set `BGSEL_FONT` to anything you have.
