#!/bin/sh
# Starts the Linux export on NixOS inside the runtime shell from flake.nix, which provides the
# display and audio libraries together with a matching glibc loader.
dir="$(dirname "$(realpath "$0")")"
exec nix develop "path:$dir" --command "$dir/soundboard.x86_64" "$@"
