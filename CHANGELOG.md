# Changelog

All notable changes to Prismarine are documented here, newest first.
Each release has a version and a name; beta releases remain marked as prereleases.

## [0.5.0] — Boron (Beta) — Unreleased

A redesign of daily use: a new look, clearer navigation, better recovery when a
launch fails, and much more control over how Prismarine looks. Prism Launcher is
still required; Full mode, controller navigation and auto-update are not in this
release.

### Added

- **Launcher mode settings.** See which backend Prismarine runs on and which features
  are marked Full mode only. Update to Full mode checks for the engine, which no
  version includes yet, and Remove Prism explains why Stable mode still needs it.
- **Controller navigation.** Move around every page and dialog with a controller when
  built with SDL2, and turn it off in Settings → Interface. It only works while Prismarine
  is in front. Sliders, number boxes and the colour square only change after pressing the
  confirm button. Text entry still needs a keyboard.
- Scroll speed setting. The mouse wheel now moves twice your system setting by default,
  with Standard and Faster choices in Settings → Interface.
- Friends is now off by default, unless you already saved friends. Turn it on or off
  in Settings → Interface. Hiding it also stops finding friends on your network. Prism Launcher shortcuts can be hidden too.
- `--interface desktop|handheld` and a matching setting that applies straight away.
  Handheld is a full-screen preview; controller navigation is not built yet. F11
  toggles full screen.
- **Palette editor.** Twenty colour roles with separate dark and light values, four
  starting palettes, HSV and hex editing, a live preview, contrast readings, and
  Apply, Discard and Defaults.
- Interface size, library density, cover size, corner style and Home section settings.
- Launch failure findings with links to logs, settings, Mods and Browse, plus a
  reviewed installation for a missing Fabric API and a manual retry.
- Home world shortcuts and adding favourite servers directly from Home.
- Direct install from Browse, with the target and compatibility always visible and
  an explicit Select multiple mode for batches.
- New instance: a cover preview on wide windows and a group choice.
- A Prismarine memory and CPU meter on the All games page.
- Light SVG placeholder for profiles with no skin, and native file dialogs when the
  platform supports them.
- Public regression checks that run in CI without the private test suites, plus a
  usage reference, technical report, developer history and documentation index.

### Changed

- Fewer Prism windows. Starting a game with no account now explains what to do in
  Prismarine instead of opening Prism's dialog, and the instance page's Prism link
  moved into its ⋯ menu. Microsoft sign-in still opens Prism.
- New top bar for search and the account switcher, and text labels on the rail.
- Square water covers with names and details below the artwork, and clearer actions
  for the selected instance in Library.
- Settings rebuilt with sections, search, a bounded width, and a compact layout for
  small windows. Appearance changes are previewed and need Apply.
- Shared type scale with 15 px body text and larger small labels.
- More layered dark colours, and clearer outlines on fields in both themes.
- Shorter page, dialog, menu and button animations with shared timing.
- Calmer account status: offline accounts no longer show as expired, and an expired
  token says it refreshes when you play.
- The Library sidebar field is now called Filter, to separate it from Search everything.

### Fixed

- Prismarine kept rendering while idle because of a hidden Now playing pulse. Idle
  rendering now stops, including when hidden or minimized.
- Sliders, progress bars and busy indicators follow the theme. The memory slider no
  longer looks inverted, and spinners stay visible on the dark theme.
- Completed launch steps and progress survive a failed launch, including when progress
  and failure arrive in the same log update.
- Applying colours after several slider drags no longer leaves Apply disabled.
- Native dialogs follow the app's theme instead of opening white.
- Page motion settles when hidden, minimized, disabled or interrupted.
- Alignment on the instance overview, Home tiles and compact Settings, and banner
  waves no longer cross text.
- Browse hides the version picker and Install until a project is chosen, and no longer
  repeats a connection error.
- Browse categories now narrow results: a project must match every selected category.
  Selecting several used to widen the search, so results barely changed.
- The creator's picture in About no longer gets stuck on a letter after reopening
  Settings. It now retries after a network failure and picks up a changed picture.
- A Back button on instance pages, with correct centring.

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

[0.5.0]: https://github.com/Fi3w0/Prismarine/releases/tag/v0.5.0
[0.4.0]: https://github.com/Fi3w0/Prismarine/releases/tag/v0.4.0
