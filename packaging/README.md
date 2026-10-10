# Distribution packages

These recipes are maintained in this repository. They are not entries in the
official Gentoo, Nixpkgs, or Void repositories. Prism Launcher must also be
installed and signed in. All builds are still beta.

## Gentoo

The [overlay](gentoo) contains a live `games-util/prismarine-9999` ebuild that
follows `main`. From a Prismarine checkout, copy the overlay somewhere persistent:

```sh
sudo mkdir -p /var/db/repos/prismarine
sudo cp -R packaging/gentoo/. /var/db/repos/prismarine/
sudo mkdir -p /etc/portage/repos.conf
sudo tee /etc/portage/repos.conf/prismarine.conf <<'EOF'
[prismarine]
location = /var/db/repos/prismarine
masters = gentoo
auto-sync = no
EOF
sudo emerge --ask games-util/prismarine
```

The `keychain` USE flag is enabled by default. Disable it if you do not want
QtKeychain support. Portage may ask you to accept the noncommercial logo license:
`games-util/prismarine CC-BY-NC-ND-4.0` in `package.license`.
Update the overlay copy when the ebuild changes; source code is fetched from GitHub
on each live build. This is a live ebuild, not a versioned binary release.

## Nix

The root [flake](../flake.nix) provides packages, a development shell, an overlay,
and a NixOS module for `x86_64-linux` and `aarch64-linux`. Enable flakes and
`nix-command` in your Nix configuration first. From this checkout:

```sh
NIXPKGS_ALLOW_UNFREE=1 nix build --impure
./result/bin/prismarine
NIXPKGS_ALLOW_UNFREE=1 nix develop --impure
```

The unfree opt-in is required for the bundled CC BY-NC-ND logo. The code is
GPL-3.0-only. `flake.lock` pins the dependency set. Keep it committed and update
it deliberately. Qt plugins and QML paths are set by the package wrapper.

CI publishes an `x86_64-linux` Nix closure, including its runtime dependencies.
Download its `.nar.xz` file and matching `.store-path.txt` file, then:

```sh
xz -dc Prismarine-*-nix-x86_64-linux.nar.xz | nix-store --import
prismarine_store=$(cat Prismarine-*-nix-x86_64-linux.store-path.txt)
"$prismarine_store/bin/prismarine"
```

## NixOS

Add Prismarine to your system flake's inputs:

```nix
inputs.prismarine.url = "github:Fi3w0/Prismarine";
inputs.prismarine.inputs.nixpkgs.follows = "nixpkgs";
```

Include the module in your `nixosSystem` modules list:

```nix
prismarine.nixosModules.default
{
  nixpkgs.config.allowUnfreePredicate = pkg:
    builtins.elem (nixpkgs.lib.getName pkg) [ "prismarine" ];
  programs.prismarine.enable = true;
}
```

Here `prismarine` and `nixpkgs` are your flake output arguments. The module
installs Prism Launcher too. Set `programs.prismarine.installPrismLauncher = false`
if you manage it separately. Rebuild with `sudo nixos-rebuild switch --flake .`.

## Void Linux

The [XBPS template](void/template) builds a pinned source snapshot. QtKeychain
is disabled because Void does not currently package its Qt 6 version; Friends
identity and remembered API keys are unavailable in this build.

```sh
git clone https://github.com/void-linux/void-packages.git
mkdir -p void-packages/srcpkgs/prismarine
cp packaging/void/template void-packages/srcpkgs/prismarine/template
cd void-packages
./xbps-src binary-bootstrap
./xbps-src pkg prismarine
sudo xbps-install -R "$PWD/hostdir/binpkgs" prismarine
```

CI builds an `x86_64` glibc `.xbps` package. To install a downloaded package,
put it in its own directory and index that directory first:

```sh
xbps-rindex -a prismarine-*.xbps
sudo xbps-install -R "$PWD" prismarine
```

Dependencies come from your normal Void repositories. This binary is for
glibc; musl users should build the template locally or use the source installer.

## Recipe references

See the [Gentoo CMake eclass](https://devmanual.gentoo.org/eclass-reference/cmake.eclass/index.html),
[Nixpkgs Qt packaging guide](https://github.com/NixOS/nixpkgs/blob/master/doc/languages-frameworks/qt.section.md),
and [Void packaging manual](https://github.com/void-linux/void-packages/blob/master/Manual.md).
