# Prismarine technical report

Current architecture and validation status. Updated 2026-11-06 for the source
checkout, which is version 0.5.0 and not yet released. The published beta is 0.4.0.

## Architecture

Prismarine is a C++17 / Qt 6 application with a QML interface. It runs Prism as a
separate process through its command line; it does not link an embedded Prism
launcher library. Prism handles Microsoft sign-in, Minecraft downloads, and game
launching. Prismarine supplies library/content management, launch progress,
monitoring, and its interface.

| Area | Source | Responsibility |
| --- | --- | --- |
| Startup and service wiring | [src/main.cpp](src/main.cpp) | Create Qt services and expose them to QML. |
| Interface | [qml](qml) | Pages, shared controls, navigation, themes, and motion. |
| Models and services | [src/core](src/core) | Instances, content, accounts, settings, storage, and sessions. |
| Prism integration | [src/core/prism](src/core/prism) | Data paths, config/account readers, and subprocess launch bridge. |
| Quiet-launch plugin | [src/prismquiet](src/prismquiet) | Suppress Prism progress/console windows when compatible. |
| OS integration | [src/core/system](src/core/system) | Process, hardware, filesystem, and platform operations. |
| App-level UI services | [src/ui](src/ui) | Native theme sync, and controller input and focus movement. |
| Packaging | [packaging](packaging) | Package recipes, runtime checks, and optional Prism patch. |
| Public regression checks | [checks](checks) | Reproducible checks without private test data. |

Prismarine and Prism share instance directories and configuration formats.
Prismarine preserves unknown configuration fields and uses atomic writes where
it edits these files. This does not provide cooperation between two launchers
holding stale in-memory state. The launch bridge can also encounter Prism's
single-instance forwarding for a shared data directory.

The quiet plugin depends on Qt compatibility and does not load into sandboxed
Flatpak/Snap launches. The [optional Prism patch](packaging/prism-patch/README.md)
provides another quiet-launch route; its documented base is Prism 11.0.3.

## Feature and validation status

| Area | Current state | Evidence limit |
| --- | --- | --- |
| Library, content, accounts, sessions | Implemented; see [usage reference](DOCUMENTATION.md). | README records daily Linux use; other platforms receive less hands-on testing. |
| Inactive navigation motion | Fixed in unreleased source. | Public regression check, native desktop check, and synthetic-library measurements pass. |
| Shared page/dialog motion | Refined in unreleased source. | Local suites and native motion checks pass. |
| Colour tokens, field outlines, labelled rail | Refined in unreleased source. | Local suites pass, with public rail-fit and contrast checks. |
| Top bar | Search and account switcher share a top bar; shortcut hints follow the platform. | Local Linux checks; Windows/macOS remain unverified. |
| Typography | Shared size tokens, 15 px body text, 11 px minimum explicit text size. | Synthetic-data screen checks; physical-display review remains open. |
| Launch failure recovery | Preserved stages, current-launch crash findings, and reviewed Fabric API installation with manual retry. | Public loopback checks and private application integration pass locally; real Minecraft and other platforms remain unverified. |
| Covers and Library | Seeded water covers, names below artwork, and grouped selected-instance actions. | Disposable 10/250-instance layout checks; no new large-library performance claims. |
| Browse installation flow | Prominent target/compatibility, direct reviewed install, explicit batch mode, and responsive project details. | Public checks cover both themes and four sizes; native Linux and verified loopback integration pass. Other platforms unrun. |
| Artwork editor and file chooser | Bounded artwork editor, SVG profile placeholders, system file dialogs when the platform supports them. | Native chooser verified on Linux with optional Qt Widgets; generic Qt theme synchronization, no KDE dependency. Quick fallback remains available. |
| Bounded settings | Reference layout; twenty colour roles with per-mode overrides, four starting palettes, HSV/hex editor, contrast and layout previews, staged Apply/Discard, size/density/Home controls. | Local suites, compiled HSV-drag regression, persisted/native palette checks and Linux captures pass. Other platforms unrun. |
| Home reference workflow | Latest-instance/world shortcuts, recent covers, direct favourite-server creation and compact news. | Preference validation/persistence, loopback news, and captured world/server launcher arguments pass; no real game launch claimed. |
| Windows, macOS, FreeBSD | Build/package workflows exist. | This session did not run hosted CI or those platforms. |
| Launcher mode | Stable runs on installed Prism. `LauncherMode` detects a Full mode engine through `prismarine-engine --engine-info`, protocol 1. No engine ships yet. A local Prism fork build reports launch events to `LaunchProgress`. No code removes Prism. | Public checks with fixture engines; opt-in private run of a real engine with throwaway data through a failed launch. No real sign-in, download or running game. |
| Handheld interface | `--interface handheld` and a setting open a full-screen preview. | No controller navigation or device check. |
| Native controller navigation | SDL2 input, optional at build time, with position-based focus across all pages (`src/ui`). CI and package recipes include SDL2, and release jobs fail if it is missing; hosted runs have not happened yet. | Public logic and fixture checks, private run of the real window through the launch loop. The owner confirmed navigation and value adjusting by hand on a BigBen pad, which is not a genuine PS4 controller. Disconnects, rumble and returning from a real game are unchecked. |
| Steam Deck | Planned for a later phase. | No handheld acceptance claim. |
| Full mode engine | A local Prism fork test build reports launch events to Prismarine. No release includes it. | Current installation still requires external Prism Launcher. |
| Application self-update | Planned. | Existing updater handles instance content. |
| Horizon launch integration | Research only. | No integration implemented or exercised end-to-end. |

See the [development plan](docs/development-plan.md) for agreed boundaries. Local
work order and verification debt live in the ignored TODO file. Historical
implementation details belong in [DEV_CHANGELOG](DEV_CHANGELOG.md).

## Building

Requirements: **Qt 6.6+** (Base, Declarative, Quick3D, ShaderTools, Svg), **libarchive**,
**OpenSSL 3**, **CMake 3.21+** and a **C++17** compiler. **QtKeychain** is optional: it
enables the Friends feature and remembered CurseForge API keys. **SDL2** is optional:
it enables controller navigation.

Qt Widgets is optional. When present it enables additional desktop file-dialog integration and
the quiet-launch plugin; builds without it retain the Qt Quick dialog fallback.

The [source installers](install/README.md) check for missing dependencies and
install them with your distro's package manager, then build into `~/.local`:

```bash
git clone https://github.com/Fi3w0/Prismarine.git
cd Prismarine
./install/install.sh --dry-run
./install/install.sh
```

There are separate entry points for Arch, Debian, Ubuntu, Fedora, Gentoo, Void,
FreeBSD, Nix, and NixOS. Use `--check` to check dependencies without changing
anything, or `--deps-only` to install dependencies without installing Prismarine.
See [native package recipes](packaging/README.md) for Portage, NixOS configuration,
and XBPS builds.

```bash
# Arch
sudo pacman -S cmake ninja qt6-base qt6-declarative qt6-quick3d qt6-shadertools qt6-svg libarchive openssl qtkeychain-qt6 sdl2-compat

# Fedora
sudo dnf install cmake ninja-build gcc-c++ qt6-qtbase-devel qt6-qtdeclarative-devel qt6-qtquick3d-devel qt6-qtshadertools-devel qt6-qtsvg-devel libarchive-devel openssl-devel qtkeychain-qt6-devel SDL2-devel

# Debian 13 / Ubuntu 25.04+
sudo apt install cmake ninja-build g++ qt6-base-dev qt6-declarative-dev qt6-quick3d-dev qt6-shadertools-dev qt6-svg-dev libarchive-dev libssl-dev qtkeychain-qt6-dev libsdl2-dev

# Gentoo
./install/gentoo.sh --deps-only

# Void Linux (QtKeychain is unavailable; configure with -DPRISMARINE_KEYCHAIN=OFF)
./install/void.sh --deps-only

# Nix / NixOS (includes the pinned build dependencies)
NIXPKGS_ALLOW_UNFREE=1 nix develop --impure

# FreeBSD
sudo pkg install cmake ninja qt6-base qt6-declarative qt6-quick3d qt6-shadertools qt6-svg libarchive sdl2
```

```bash
git clone https://github.com/Fi3w0/Prismarine.git
cd Prismarine
cmake -S . -B build -G Ninja -DCMAKE_BUILD_TYPE=Release
cmake --build build
./build/prismarine
```

Install it for your user (desktop entry and icons included) with
`cmake --install build --prefix ~/.local`. Useful options:

| Option | Default | What it does |
| --- | --- | --- |
| `PRISMARINE_KEYCHAIN` | `ON` | Use QtKeychain for the Friends identity and API keys |
| `PRISMARINE_CONTROLLER` | `ON` | Use SDL2 for controller navigation when it is found |
| `PRISMARINE_REQUIRE_CONTROLLER` | `OFF` | Fail the configure step when SDL2 is not found, as release builds do |
| `PRISMARINE_DEPLOY_QT` | `OFF` | Copy Qt next to the app on install (Windows and macOS packages) |

Windows and macOS builds use Qt from the [online installer](https://www.qt.io/download-qt-installer-oss)
and libarchive and OpenSSL from [vcpkg](https://vcpkg.io). [`.github/workflows/ci.yml`](.github/workflows/ci.yml)
has the exact steps for every system and package.

The public checks also require Qt Test when `BUILD_TESTING=ON` (CMake's default).
Use `-DBUILD_TESTING=OFF` for a build without test targets.

## Validation

```sh
ctest --test-dir build --output-on-failure
python3 scripts/check-links.py
python3 scripts/check-installers.py
```

Public checks live in [checks](checks/README.md); optional private suites live in
local checkouts under `tests/`. CI invokes CTest even when private tests are absent.
Local results are not hosted CI results. CI has not run on the current source yet.

Use disposable data for content and launch tests. The
[baseline runner](scripts/baseline/README.md) builds synthetic libraries and records
release-process measurements. Its short idle windows exclude subprocess and
compositor CPU, and do not establish GPU utilization or battery use.

## Performance status

On the recorded Gentoo/Wayland/NVIDIA desktop, the idle-motion fix reduced idle
rendering from about 175 frames per observation window to 0–1. Median launcher
CPU was about 0.36% of one core; no memory regression was observed. These figures
are tied to that workload and machine.

Large-library page/reload delays and account-page stalls still need focused
investigation. No full QML profiler trace or reliable per-process GPU measurement
was captured in the initial session.

Shared transitions now use shorter entry/exit timings and smaller movements.
The [motion-polish report](docs/phase1-motion-polish.md) records the behavior,
resource measurements, and desktop timing variance.

See [the original baseline](docs/baseline-2026-11-05.md) and
[the fix report](docs/phase1-idle-animation.md) for methods and limitations.

## Documentation map

- [README](README.md): overview, screenshots, installation, and build quick start.
- [DOCUMENTATION](DOCUMENTATION.md): usage, shortcuts, CLI, and troubleshooting.
- This report: architecture, build details, and validation status.
- [CHANGELOG](CHANGELOG.md): release-facing changes.
- [DEV_CHANGELOG](DEV_CHANGELOG.md): implementation history and evidence links.
- [docs index](docs/README.md): plans, research, and dated reports.
- [CONTRIBUTING](CONTRIBUTING.md), [SECURITY](SECURITY.md),
  [TRADEMARKS](TRADEMARKS.md): contribution, disclosure, and branding policies.
