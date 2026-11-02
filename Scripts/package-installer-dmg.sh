#!/bin/zsh
set -euo pipefail

# Wraps an Arma.app in the classic drag-to-install disk image: a Finder window
# of its own size over Brand/Installer's background, Arma on the left and
# Applications on the right, compressed with LZMA.
#
#   Scripts/package-installer-dmg.sh <Arma.app> <output.dmg> [--sign <identity>]
#
# Finder lays the window out through AppleScript, so the script needs a
# logged-in session and lets Finder open the image's window briefly. A
# release signs and notarizes the image after this, as its workflow does.

fail() { print -u2 "package-installer-dmg: $1"; exit 1; }

(( $# >= 2 )) || fail "usage: package-installer-dmg.sh <Arma.app> <output.dmg> [--sign <identity>]"
app="${1:A}"
output="${2:A}"
identity=""
shift 2
while (( $# > 0 )); do
    case "$1" in
        --sign) identity="${2:-}"; shift 2 ;;
        *) fail "unknown option $1" ;;
    esac
done
[[ -d "$app" ]] || fail "no app at $app"

root="${0:A:h:h}"
volume="Arma"
work="$(mktemp -d "${TMPDIR:-/tmp}/arma-dmg.XXXXXX")"
mount=""
trap '[[ -n "$mount" ]] && hdiutil detach "$mount" -quiet -force 2>/dev/null; rm -rf "${work:?}"' EXIT
[[ -e "/Volumes/$volume" ]] && fail "a volume named $volume is already mounted; eject it first"

# The window's contents: the app, Applications, and the hidden background.
staging="$work/staging"
mkdir -p "$staging/.background"
ditto "$app" "$staging/Arma.app"
ln -s /Applications "$staging/Applications"
tiffutil -cathidpicheck "$root/Brand/Installer/background.png" "$root/Brand/Installer/background@2x.png" \
    -out "$staging/.background/background.tiff" >/dev/null 2>&1

# A writable image Finder can lay out.
megabytes=$(( $(du -sm "$staging" | cut -f1) + 64 ))
hdiutil create -quiet -srcfolder "$staging" -volname "$volume" -fs HFS+ -format UDRW -size "${megabytes}m" \
    "$work/rw.dmg"
# Finder sees only volumes mounted under /Volumes.
mount="$(hdiutil attach -readwrite -noverify -noautoopen "$work/rw.dmg" | awk -F'\t' '/\/Volumes\// { print $NF; exit }')"
[[ -d "$mount" ]] || fail "could not mount the image"

osascript <<APPLESCRIPT
tell application "Finder"
    set theDisk to disk "$volume"
    open theDisk
    set theWindow to container window of theDisk
    set current view of theWindow to icon view
    set toolbar visible of theWindow to false
    set statusbar visible of theWindow to false
    set bounds of theWindow to {200, 120, 860, 562}
    set theOptions to icon view options of theWindow
    set arrangement of theOptions to not arranged
    set icon size of theOptions to 112
    set text size of theOptions to 13
    set background picture of theOptions to file ".background:background.tiff" of theDisk
    set position of item "Arma.app" of theWindow to {165, 245}
    set position of item "Applications" of theWindow to {495, 245}
    -- Where Finder shows hidden files, they sit outside the window.
    try
        set position of item ".background" of theWindow to {900, 900}
    end try
    try
        set position of item ".fseventsd" of theWindow to {1000, 900}
    end try
    update theDisk without registering applications
    delay 2
    close theWindow
    -- Open and close it again, so Finder writes the window's size and
    -- layout into the image before it is detached.
    open theDisk
    set bounds of container window of theDisk to {200, 120, 860, 562}
    delay 2
    close container window of theDisk
end tell
APPLESCRIPT

# Hide the background folder, let Finder write its layout, then compress.
SetFile -a V "$mount/.background" 2>/dev/null || chflags hidden "$mount/.background"
rm -rf "$mount/.fseventsd"
for _ in {1..20}; do [[ -f "$mount/.DS_Store" ]] && break; sleep 0.5; done
sync
hdiutil detach -quiet "$mount"
mount=""
rm -f "$output"
hdiutil convert -quiet "$work/rw.dmg" -format ULMO -o "$output"
if [[ -n "$identity" ]]; then
    codesign --force --timestamp --sign "$identity" "$output"
fi
print "Wrote $output ($(du -h "$output" | cut -f1))"
