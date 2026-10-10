#!/usr/bin/env bash
# Shared implementation for the distro entry points in this folder.
set -euo pipefail

distro=${1:?Pass a distribution name}
shift
repo_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
prefix=${HOME}/.local
jobs=2
dry_run=false
check_only=false
deps_only=false

usage() {
    cat <<'EOF'
Usage: install/<distro>.sh [options]
  --dry-run       Show missing dependencies and commands without changing files
  --check         Check dependencies only; return 1 if any are missing
  --deps-only     Install missing build dependencies without building
  --prefix PATH   Installation prefix (default: ~/.local; must be absolute)
  --jobs N        Parallel build jobs (default: 2)
  --help          Show this help
Nix/NixOS use your Nix user profile; --prefix and --jobs do not apply there.
EOF
}

while (($#)); do
    case "$1" in
        --dry-run) dry_run=true ;;
        --check) check_only=true ;;
        --deps-only) deps_only=true ;;
        --prefix)
            [[ $# -ge 2 && $2 == /* ]] || { echo '--prefix needs an absolute path' >&2; exit 2; }
            prefix=$2; shift ;;
        --jobs)
            [[ $# -ge 2 && $2 =~ ^[1-9][0-9]*$ ]] || { echo '--jobs needs a positive integer' >&2; exit 2; }
            jobs=$2; shift ;;
        --help|-h) usage; exit 0 ;;
        *) echo "Unknown option: $1" >&2; usage >&2; exit 2 ;;
    esac
    shift
done

run() {
    if $dry_run; then
        printf 'Would run:'; printf ' %q' "$@"; printf '\n'
    else
        "$@"
    fi
}

as_root() {
    if (( EUID == 0 )); then run "$@"; else run sudo "$@"; fi
}

bash "$repo_dir/install/detect-prism.sh" || true

if [[ $distro == nix || $distro == nixos ]]; then
    if ! command -v nix >/dev/null; then
        echo 'Nix is missing. Install Nix and enable nix-command and flakes first.' >&2
        exit 1
    fi
    $check_only && { echo 'Nix is available; nix build resolves the pinned dependencies.'; exit 0; }
    if $deps_only; then
        run env NIXPKGS_ALLOW_UNFREE=1 nix build --impure --no-link "$repo_dir"
    else
        run env NIXPKGS_ALLOW_UNFREE=1 nix profile install --impure "$repo_dir"
        echo 'Nix profile installation selected. For system-wide NixOS configuration, see packaging/README.md.'
    fi
    exit 0
fi

keychain=ON
case "$distro" in
    arch)
        manager=pacman
        packages=(base-devel cmake ninja pkgconf qt6-base qt6-declarative qt6-quick3d qt6-shadertools qt6-svg libarchive openssl qtkeychain-qt6)
        installed() { pacman -Q "$1" >/dev/null 2>&1; }
        install_missing() { as_root pacman -Syu --needed "${missing[@]}"; }
        ;;
    debian|ubuntu)
        manager=apt-get
        packages=(build-essential cmake ninja-build pkg-config qt6-base-dev qt6-declarative-dev qt6-quick3d-dev qt6-shadertools-dev qt6-svg-dev libarchive-dev libssl-dev qtkeychain-qt6-dev)
        # QML modules are loaded at runtime and are not all pulled in by -dev packages.
        while IFS= read -r package; do
            [[ -z $package || $package == \#* ]] || packages+=("$package")
        done < "$repo_dir/packaging/linux/debian-runtime-depends.txt"
        installed() { [[ $(dpkg-query -W -f='${Status}' "$1" 2>/dev/null) == 'install ok installed' ]]; }
        install_missing() { as_root apt-get update; as_root apt-get install "${missing[@]}"; }
        ;;
    fedora)
        manager=dnf
        packages=(gcc-c++ cmake ninja-build pkgconf-pkg-config qt6-qtbase-devel qt6-qtdeclarative-devel qt6-qtquick3d-devel qt6-qtshadertools-devel qt6-qtsvg-devel libarchive-devel openssl-devel qtkeychain-qt6-devel)
        installed() { rpm -q "$1" >/dev/null 2>&1; }
        install_missing() { as_root dnf install "${missing[@]}"; }
        ;;
    gentoo)
        manager=emerge
        packages=(dev-build/cmake dev-build/ninja virtual/pkgconfig sys-devel/gcc '>=dev-qt/qtbase-6.6:6[concurrent,gui,network,opengl,ssl,widgets]' '>=dev-qt/qtdeclarative-6.6:6[opengl]' '>=dev-qt/qtquick3d-6.6:6' '>=dev-qt/qtshadertools-6.6:6' '>=dev-qt/qtsvg-6.6:6' app-arch/libarchive '>=dev-libs/openssl-3' dev-libs/qtkeychain)
        installed() { portageq has_version / "$1" >/dev/null 2>&1; }
        install_missing() { as_root emerge --ask --oneshot "${missing[@]}"; }
        ;;
    void)
        manager=xbps-install
        keychain=OFF
        packages=(base-devel cmake ninja pkg-config qt6-base-devel qt6-declarative-devel qt6-quick3d-devel qt6-shadertools-devel qt6-svg-devel libarchive-devel openssl-devel)
        installed() { [[ $(xbps-query -p state "$1" 2>/dev/null) == installed ]]; }
        install_missing() { as_root xbps-install -S "${missing[@]}"; }
        ;;
    freebsd)
        manager=pkg
        keychain=OFF
        packages=(cmake ninja pkgconf qt6-base qt6-declarative qt6-quick3d qt6-shadertools qt6-svg libarchive openssl)
        installed() { pkg info -e "$1" >/dev/null 2>&1; }
        install_missing() { as_root pkg install "${missing[@]}"; }
        ;;
    *) echo "Unsupported distribution: $distro" >&2; exit 2 ;;
esac

command -v "$manager" >/dev/null || { echo "$manager not found; use the script for your distribution." >&2; exit 1; }
missing=()
for package in "${packages[@]}"; do
    installed "$package" || missing+=("$package")
done
if ((${#missing[@]})); then
    printf 'Missing dependencies:\n'; printf '  %s\n' "${missing[@]}"
    $check_only && exit 1
    install_missing
else
    echo 'All listed build and runtime dependencies are installed.'
fi
$check_only && exit 0
$deps_only && exit 0

build_dir="$repo_dir/build-install-$distro"
run cmake -S "$repo_dir" -B "$build_dir" -G Ninja -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_INSTALL_PREFIX="$prefix" -DBUILD_TESTING=OFF -DPRISMARINE_KEYCHAIN="$keychain"
run cmake --build "$build_dir" --parallel "$jobs"
run cmake --install "$build_dir"
if ! $dry_run; then
    if command -v update-desktop-database >/dev/null; then
        update-desktop-database "$prefix/share/applications" || true
    fi
    echo "Installed: $prefix/bin/prismarine"
fi
echo 'Sign in once in Prism Launcher. Start Prismarine from your application menu or its installed path.'
