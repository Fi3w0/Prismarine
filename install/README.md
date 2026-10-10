# Source installers

Run these from a Prismarine checkout. They check your distribution's package
database, install missing build/runtime dependencies through its package
manager, then build and install Prismarine under `~/.local`.
Only the dependency installation uses administrator privileges. Package
managers retain their normal confirmation prompts.

Each installer reports existing native/AUR/GURU, Nix, Flatpak, Snap, and
portable Prism installations. You can run `./install/detect-prism.sh` alone.
It never installs or launches Prism; custom locations can be selected in
Prismarine Settings.

```sh
./install/install.sh --dry-run        # detect your distro and show the commands
./install/install.sh --check          # dependencies only, no changes
./install/gentoo.sh                   # explicit distro entry point
./install/void.sh --deps-only         # install dependencies only
./install/fedora.sh --jobs 4          # choose the build parallelism
./install/debian.sh --prefix "$HOME/.local"
```

Entry points: `arch.sh`, `debian.sh`, `ubuntu.sh`, `fedora.sh`, `gentoo.sh`,
`void.sh`, `freebsd.sh`, `nix.sh`, and `nixos.sh`. FreeBSD needs Bash installed
before running these scripts. Debian requires Debian 13 or newer; Ubuntu
requires a release with Qt 6.6 or newer (25.04+ for these package names).
Gentoo checks Qt USE flags as well as versions. CMake checks the actual library
versions before building on every distribution.

`--check` exits with status 1 for missing dependencies. `--dry-run` never
installs packages, creates a build directory, or changes your prefix. Existing
build directories are reused. Rerun an installer after updating the checkout.
Uninstall a source build using its `build-install-<distro>/install_manifest.txt`
as the file list; remove only those files, not the whole prefix.

Nix and NixOS use the pinned flake and install into your Nix user profile.
`--deps-only` builds without installing the result. The `--prefix` and
`--jobs` settings apply only to the CMake installers. Nix must already be
installed with `nix-command` and `flakes` enabled. For a declarative NixOS
installation or native distribution packages, see [packaging](../packaging/README.md).

Prism Launcher is a separate requirement; install it using its
[official instructions](https://prismlauncher.org/download/) and sign in once.
