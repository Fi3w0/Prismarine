#!/usr/bin/env bash
# Read-only detection; does not install or launch Prism.
set -euo pipefail
found=false
report() { printf 'Prism Launcher (%s): %s\n' "$1" "$2"; found=true; }

for name in prismlauncher prismlauncher.exe; do
    if program=$(command -v "$name"); then report 'native / package / PATH' "$program"; fi
done
for program in \
    "$HOME/.local/bin/prismlauncher" "$HOME/.nix-profile/bin/prismlauncher" \
    "/etc/profiles/per-user/${USER:-}/bin/prismlauncher" "/run/current-system/sw/bin/prismlauncher" \
    /usr/bin/prismlauncher /usr/local/bin/prismlauncher \
    '/Applications/Prism Launcher.app/Contents/MacOS/prismlauncher' \
    "$HOME/Applications/Prism Launcher.app/Contents/MacOS/prismlauncher" \
    '/Applications/PrismLauncher.app/Contents/MacOS/prismlauncher' \
    "$HOME/Applications/PrismLauncher.app/Contents/MacOS/prismlauncher"; do
    [[ -f $program && -x $program ]] && report 'native / Nix / macOS' "$program"
done
if command -v flatpak >/dev/null; then
    for scope in user system; do
        if flatpak info --"$scope" org.prismlauncher.PrismLauncher >/dev/null 2>&1; then
            report "Flatpak ($scope)" 'org.prismlauncher.PrismLauncher'
        fi
    done
fi
for name in prismlauncher-alpo.prismlauncher prismlauncher-alpo prismlauncher.prismlauncher; do
    if program=$(command -v "$name"); then report Snap "$program"; fi
    for root in /snap/bin /var/lib/snapd/snap/bin; do
        [[ -x $root/$name ]] && report Snap "$root/$name"
    done
done
shopt -s nullglob
for root in "$HOME/Applications" "$HOME/AppImages" "$HOME/Downloads" "$HOME" /opt; do
    for program in "$root"/PrismLauncher*.AppImage "$root"/prismlauncher*.AppImage \
        "$root/PrismLauncher/prismlauncher" "$root/prismlauncher/prismlauncher"; do
        [[ -f $program && -x $program ]] && report 'portable / AppImage' "$program"
    done
done
if ! $found; then
    echo 'Prism Launcher was not found in PATH or common native, Flatpak, Snap, Nix, and portable locations.'
    echo 'Install it from https://prismlauncher.org/download/ or select its executable in Prismarine Settings.'
    exit 1
fi
echo 'AUR, GURU, and other source-package installs work through the native executable; no special launcher is needed.'
