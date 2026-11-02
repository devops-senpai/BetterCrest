#!/usr/bin/env bash
# Builds Arma's Servo engine, libarma_servo.dylib, from CrestEngines/Servo.
#
# It downloads the published servo-net crate the lock file names, applies
# CrestEngines/Servo/Patches to it, and builds the library in release. The
# library is optional: Arma offers Servo only when the app carries it.
#
# Usage: Scripts/build-servo-engine.sh [--output DIR]
# CARGO_TARGET_DIR, when set, names the build folder to reuse.
set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
servo="$root/CrestEngines/Servo"
output=""
while [[ $# -gt 0 ]]; do
    case "$1" in
        --output) output="$2"; shift 2 ;;
        *) echo "Unknown argument: $1" >&2; exit 64 ;;
    esac
done

command -v cargo >/dev/null || { echo "cargo is not installed; install Rust with rustup." >&2; exit 69; }

version="$(awk '/^name = "servo-net"$/ { getline; gsub(/version = |"/, ""); print; exit }' "$servo/Cargo.lock")"
[[ -n "$version" ]] || { echo "Cargo.lock names no servo-net version." >&2; exit 65; }

patched="$servo/.build/servo-net"
stamp="$patched/.arma-patched"
expected="$version $(cat "$servo"/Patches/*.patch | shasum -a 256 | cut -d' ' -f1)"
if [[ ! -f "$stamp" || "$(cat "$stamp")" != "$expected" ]]; then
    rm -rf "${patched:?}"
    mkdir -p "$patched"
    curl -fsSL "https://static.crates.io/crates/servo-net/servo-net-$version.crate" \
        | tar -xz -C "$patched" --strip-components 1
    for patch in "$servo"/Patches/*.patch; do
        patch -d "$patched" -p1 --quiet < "$patch"
    done
    echo "$expected" > "$stamp"
fi

target="${CARGO_TARGET_DIR:-$servo/target}"
(cd "$servo" && CARGO_TARGET_DIR="$target" cargo build --release --locked)
library="$target/release/libarma_servo.dylib"
install_name_tool -id @rpath/libarma_servo.dylib "$library"

if [[ -n "$output" ]]; then
    mkdir -p "$output"
    cp "$library" "$output/"
    echo "$output/libarma_servo.dylib"
else
    echo "$library"
fi
