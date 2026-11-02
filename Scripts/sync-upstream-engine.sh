#!/bin/zsh
set -euo pipefail

# Mirrors upstream Crest's published Chromium engine for this checkout's
# engine key into this fork's releases, so release builds here download it
# without anyone building Chromium.
#
# The engine inputs (CrestEngines/Chromium patches, overlay, host header, lock
# and the control-plane build scripts) stay byte-identical to upstream's, so
# the key Scripts/control-plane/chromium_engine.py computes names an engine
# upstream has already built. The only thing in the engine that looks at the
# host's bundle identifier is the name of the Keychain item that protects the
# Chromium profile; for Arma it falls back to Chromium's default name.
#
#   Scripts/sync-upstream-engine.sh [--upstream <owner/repo>] [--repository <owner/repo>]
#
# Run it after Scripts/sync-upstream.sh when the engine key changed.

script_root="${0:A:h:h}"
cd "$script_root"
upstream="pauljoda/Crest"
repository="devops-senpai/Arma"

fail() {
    print -u2 "sync-upstream-engine: $1"
    exit 1
}

while (( $# > 0 )); do
    case "$1" in
        --upstream) upstream="${2:-}"; shift 2 ;;
        --repository) repository="${2:-}"; shift 2 ;;
        -h|--help) sed -n '4,17p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
        *) fail "unknown option $1" ;;
    esac
done

tag="$(python3 Scripts/control-plane/chromium_engine.py tag)"
asset="$(python3 Scripts/control-plane/chromium_engine.py asset)"
if gh release view "$tag" --repo "$repository" >/dev/null 2>&1; then
    print "$repository already has $tag."
    exit 0
fi
gh release view "$tag" --repo "$upstream" >/dev/null 2>&1 \
    || fail "$upstream has no $tag; the engine inputs differ from upstream's, or upstream has not built this engine yet"

# Downloads land in their own empty directory and are checked before use.
staging="$(mktemp -d "${TMPDIR:-/tmp}/arma-engine.XXXXXX")"
trap 'rm -rf "$staging"' EXIT
print "Downloading $tag from $upstream."
gh release download "$tag" --repo "$upstream" --dir "$staging" \
    --pattern "$asset" --pattern "$asset.sha256" --pattern "$asset.json"
(cd "$staging" && shasum -a 256 -c "$asset.sha256" >/dev/null) || fail "checksum mismatch for $asset"

notes="Chromium engine mirrored from https://github.com/$upstream/releases/tag/$tag for the engine key this branch computes. Built by upstream from the same engine inputs; not modified."
print "Publishing $tag to $repository."
gh release create "$tag" --repo "$repository" --prerelease --title "$tag" --notes "$notes" \
    "$staging/$asset" "$staging/$asset.sha256" "$staging/$asset.json"
print "Mirrored $tag."
