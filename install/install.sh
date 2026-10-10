#!/usr/bin/env bash
set -euo pipefail
if [[ $(uname -s) == FreeBSD ]]; then
    distro=freebsd
else
    [[ -r /etc/os-release ]] || { echo 'Cannot detect your distribution.' >&2; exit 1; }
    # shellcheck source=/dev/null
    . /etc/os-release
    case "$ID" in
        arch|endeavouros|manjaro) distro=arch ;;
        debian|ubuntu|linuxmint|pop) distro=debian ;;
        fedora) distro=fedora ;;
        gentoo) distro=gentoo ;;
        void) distro=void ;;
        nixos) distro=nixos ;;
        *) echo "Unsupported distribution: $ID. See README.md for manual builds." >&2; exit 1 ;;
    esac
fi
exec bash "$(dirname -- "${BASH_SOURCE[0]}")/common.sh" "$distro" "$@"
