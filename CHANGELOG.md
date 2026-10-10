# Changelog

All notable changes to Prismarine are documented here, newest first.
Each release has a version and a name; beta releases remain marked as prereleases.

## [0.4.0] — Beryllium (Beta) — 2026-10-11

First public beta. A native Qt 6 Minecraft launcher powered by Prism Launcher,
with a deep-sea interface. Works on Linux, macOS and Windows; improvements are
still planned.

### Added

- Instance library with covers, groups, favourites, notes, search and a command palette.
- Modrinth and CurseForge browsing, content updates, dependency checks, mod profiles,
  and modpack import/export. CurseForge installation through Prism Launcher works
  without adding your own API key; direct browsing in Prismarine needs a key.
- Launch progress, live game logs, hardware graphs, favourite servers and crash help.
- Java discovery and downloads, account and skin management, storage cleanup,
  and optional shared content. Multi-account play is experimental and disabled by default.
- Deep sea, Light and System themes, custom accents, and SVG branding.
- Linux AppImage, Debian/Ubuntu, Fedora, Arch, Void and Nix packages; a Gentoo
  overlay; Windows installer and portable ZIP; macOS disk images for Apple silicon
  and Intel; and a FreeBSD package.
- Distro installers with dependency checks and detection of native, Flatpak, Snap,
  Nix, AppImage and portable Prism Launcher installations.
- Issue forms, contribution and security guides, and GitHub Sponsors/Ko-fi links.

### Fixed

- Windows packages now include the Qt runtime beside the executable.
- Windows settings and account changes save without the application's own file
  readers blocking atomic replacement.
- Open Prism Launcher works with older Prism versions. Windows executable selection
  handles file URLs correctly and discovery checks custom installer locations.
- Prism's quiet-launch plugin uses an isolated path, avoiding conflicts with its Qt
  plugins. The macOS plugin's required frameworks are bundled.
- The About page keeps its SVG logo, with the renderer included in macOS packages.
- Desktop icons use a larger prism to better match other launcher icons.

### Notes

- Prismarine is a UI and feature add-on, not a standalone launcher: both apps must
  be installed. Prism Launcher handles Microsoft sign-in, game downloads and launching.
- Windows builds are unsigned, and macOS builds are not notarised.
- Gentoo, Nix and Void recipes are provided here; they are not in the official
  distribution repositories. FreeBSD and additional Linux packages are built in CI.
- Packaged CI checks cover Windows settings persistence and Prism startup, plus
  SVG logo loading on both macOS architectures. Every release includes SHA256 checksums.

[0.4.0]: https://github.com/Fi3w0/Prismarine/releases/tag/v0.4.0
