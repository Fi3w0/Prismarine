#!/bin/sh
# Builds a FreeBSD package (.pkg) from an install tree. Usage:
#   make-package.sh <stage dir with usr/local/...> <version> <output dir>
set -eu
stage=$1 version=$2 out=$3
manifest=$(mktemp)
deps=""
for name in qt6-base qt6-declarative qt6-quick3d qt6-shadertools qt6-svg libarchive; do
    origin=$(pkg query %o "$name")
    ver=$(pkg query %v "$name")
    deps="$deps  \"$name\": { origin: \"$origin\", version: \"$ver\" },
"
done
cat > "$manifest" <<MANIFEST
name: prismarine
version: "$version"
origin: games/prismarine
comment: "Minecraft library and instance manager for Prism Launcher"
desc: "Prismarine is a modern home for Prism Launcher instances: mods, packs, live logs and hardware use."
maintainer: "Fi3w0"
www: "https://github.com/Fi3w0"
prefix: /usr/local
licenselogic: single
licenses: [GPLv3]
categories: [games]
deps: {
$deps}
MANIFEST
# Every installed file, by its absolute path on the target system.
plist=$(mktemp)
(cd "$stage" && find . -type f -o -type l) | sed 's|^\.||' > "$plist"
mkdir -p "$out"
pkg create -M "$manifest" -p "$plist" -r "$stage" -o "$out"
rm -f "$manifest" "$plist"
