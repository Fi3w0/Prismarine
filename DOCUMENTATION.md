# Prismarine usage reference

Prismarine uses your Prism Launcher instances and accounts. Install Prism and
sign in there before launching a game through Prismarine.

- [Prism detection and data](#prism-detection-and-data)
- [Library and content](#library-and-content)
- [Network and accounts](#network-and-accounts)
- [Launcher modes](#launcher-modes)
- [Controller](#controller)
- [Keyboard shortcuts](#keyboard-shortcuts)
- [Command-line options](#command-line-options)
- [Troubleshooting](#troubleshooting)

For installation packages, start with the [README](README.md#install). For builds and
architecture, see the [technical report](TECHNICAL_REPORT.md).

## Prism detection and data

Prismarine detects native packages, including AUR and Gentoo/GURU builds, Nix
profiles, Flatpak, the `prismlauncher-alpo` Snap, common AppImage/portable folders,
Windows installer/Scoop locations, and macOS application bundles.

Run `./install/detect-prism.sh` to inspect installer detection. For a custom Prism
location, select its executable in Settings. Pass `--prism-data` to select a
specific Prism data directory. Portable Prism installations can keep their data
beside the executable.

Both launchers use the same instance files. Prismarine preserves unknown settings
and uses atomic writes where it edits Prism configuration; simultaneous management
by two running launchers still needs coordination. Close the other launcher when
troubleshooting conflicting changes or unexpected launch windows.

Flatpak and Snap use their own data folders and sandbox permissions. Prismarine's
quiet-window plugin does not load into those sandboxed launches. A Prism process
already running for a data folder may receive a subsequent launch request; see
[the quiet-launch patch notes](packaging/prism-patch/README.md).

## Library and content

### Your library

- **Covers or rows**, search, loader filters, sorting, favourites and notes.
- **Library covers:** single-click to select, double-click the artwork to open,
  or use Play to launch. Names and version details sit below the cover. Double-click
  a name to rename it, or press F2. The selected-instance panel groups Mods,
  Worlds/screenshots, and settings above Duplicate, Rename, Cover, and Group
  shortcuts; More actions holds the remaining tools. Home's recent covers open
  the instance before launching.
- **Prism's groups**: create, rename and delete them, and drag instances (or their cards) onto a group.
- **Card and banner art** per instance: generated artwork, any screenshot, or your own image.
- **Quick rename** with a double-click or F2, plus a right-click menu everywhere.
- **Ctrl+K** (⌘K on macOS), or the search box in the top bar, finds instances, worlds, servers, groups, settings and actions.

### Appearance and layout

- **Interface** follows the Settings design: launcher previews, an HSV/hex colour
  editor, live application/Library previews, and measured contrast ratios.
- **Palette** offers twenty colour roles: window, rail, sidebars, cards, fields,
  rows, banners, outlines, text, headings, button text and status colours. Choose
  a role from the picker or a colour tile. Deep sea and Light keep separate colours.
- Start with **Deep sea**, **Midnight**, **Sea glass**, or **Slate**, then edit any
  colour. **Reset colour** restores just the selected role. Button text chooses a
  readable default unless you override it. Light mode deepens the base accent
  for readability.
- **Apply** saves Interface and Library appearance changes. Until then, colours,
  theme, corners, Home sections and layout changes stay in the preview.
  **Discard** reloads applied values; **Defaults** previews the defaults for review.
- **Interface size** offers 90%, 100%, and 115%; reopen Prismarine after applying
  to scale text and controls together. Choose rounded or angular corners, a start
  page, Home sections, window behavior while playing, and reduced motion.
- **Library & covers** previews Covers or List, Comfortable or Compact density,
  Small/Medium/Large covers, loader badges, screenshot defaults, and frames.
  Per-instance images use the Library's Cover action.
- **Scroll speed** sets how far each mouse wheel step moves: Standard follows your system
  setting, and Fast (the default) and Faster move two and three times as far.
- The Classic Prism card opens Prism's own window. **Prism integration** holds the executable
  and desktop integration controls, which apply straight away instead of waiting for Apply.
- On smaller or shorter windows, use the settings search and section picker above
  the scrolling form. Apply and Discard stay visible below it.

### Content

- **Browse Modrinth and CurseForge** for mods, resource packs, shaders, datapacks and full modpacks, filtered to your instance's version and loader.
- **CurseForge without your own API key**: use **Install with Prism Launcher** to open Prism's instance editor or modpack browser. Prism handles its own CurseForge access. Add your own key to browse directly inside Prismarine.
- **Install one project**: check **Installing to**, select a compatible release, and choose **Install…** to review its files and dependencies before confirming.
- **Install several projects**: choose **Select multiple**, add releases to the selection, then **Review & install**. Selections stay with their target instance and content type. Datapacks also need a saved world. Narrow windows open project details with a **Results** button.
- **Dependencies resolved** before anything installs, and every download is hash-verified.
- **Drag and drop** jars, packs and modpack archives onto the window or onto an instance.
- **Updates** for mods, resource packs, shaders and per-world datapacks.
- **Mod health**: duplicate mods, missing dependencies, incompatibilities and wrong-loader jars, each with a fix.
- **Mod profiles** to switch between saved sets of enabled mods.
- **Import and export** `.mrpack` and Prism ZIPs. *Share with friends* turns Modrinth-hosted files into downloads instead of copying them.

### Playing

- **Continue playing** uses the most recently launched instance. Its saved-world
  shortcuts start that instance in the chosen world; **Jump back in** includes a
  New instance tile.
- **Prismarine's own launch screen** with real steps (sign in, game files, Java, loading) and an **Abort** button.
- **Now playing**: a tab per running game with its live log, filters, memory and CPU, plus an **All games** view with CPU, RAM and GPU graphs.
- **Crash helper** that reads the log and crash report and explains the likely cause: missing dependencies, mixin conflicts, wrong Java, out of memory and more.
- **Favourite servers on Home** with live player counts and ping. Choose an instance and **Add server** directly from Home, or pin one from its Servers tab. Join uses the saved instance and launches straight in.
- **While playing**, Prismarine can stay open, minimise or hide (globally or per instance).
- **Multi-account play** *(experimental, off by default)*: run one instance with two accounts at once through a synced copy.

### Housekeeping

- **Storage** view of worlds, mods, screenshots, logs and caches per instance, with selective cleanup.
- **Shared content** *(optional)*: identical mods and packs across instances become hard links and use the space once.
- **Java**: find and test installed runtimes, or download a verified Eclipse Temurin.
- **Accounts**: default account, skin library and capes, previewed on a 3D model with an elytra view.
- **Network settings** for Prism's proxy, downloads and API overrides.
- **Themes**: Deep sea, Light or System, with your own accent colour.

Content updates affect mods and packs. Prismarine does not yet update its own
application binary; install a newer release or use your package manager.

## Network and accounts

Prismarine has no separate account service or telemetry. It goes online for content catalogs,
game and account data, news, Java downloads, server pings, and optional features such as
Friends. Log uploads to mclo.gs only happen when you choose them. Prism Launcher handles
Microsoft sign-in.

## Launcher modes

**Settings → Launcher mode** shows how Prismarine runs.

- **Stable** uses your installed Prism Launcher. No release offers anything else yet.
- **Full** runs on Prismarine's own Prism-based engine and keeps using Prism's folders, so you
  could remove the Prism app. Items marked *Full mode only* need that engine, which is still
  in development.

The same page has the handheld preview, which switches to full screen straight away, and a
switch that hides links to Prism's window. Microsoft sign-in and CurseForge installs without
a key still open Prism.

The Friends tab is hidden by default unless you already saved friends. Use **Friends**
in **Settings → Interface**, then Apply, to show or hide it.

## Controller

With a controller connected, the D-pad or left stick moves focus to the next control in
that direction. The first press only shows where focus is.

| Button | Action |
| --- | --- |
| Bottom (A, Cross) | Select. In the Library, play the selected instance. |
| Right (B, Circle) | Close a dialog, or go back. While adjusting, cancel the change. |
| Top (Y, Triangle) | Open details for the selected instance. |
| Left (X, Square) | Open the menu for the focused item, like a right click. |
| Start, Options | Play the selected instance. |
| Shoulder buttons | Previous or next page. |
| Right stick | Scroll. |

Sliders, number boxes and the colour square keep their value as focus passes over them.
Press the bottom button to start adjusting, use the directions, then press it again to
accept. Colours still need Apply in Settings.

Controller input only counts while Prismarine is the active window, so a game in front
keeps it. Turn it off with **Controller** in **Settings → Interface**. Text fields still
need a keyboard. Builds without SDL2 have no controller support; official packages include it.

## Keyboard shortcuts

| Shortcut | Action |
| --- | --- |
| Ctrl+K / Ctrl+Shift+P | Open the command palette. |
| Ctrl+F | Open library search. |
| F2 | Rename the selected instance in the library or instance page. |
| Ctrl+R / F5 | Reload the library. |
| Alt+Left | Go back. |
| F11 | Toggle full screen. |
| Arrow keys | Move selection when the library grid/rows have focus. |
| Enter | Launch the selected instance when the library browser has focus. |

On macOS, Qt maps Ctrl to Command. Dialogs and search fields handle Escape themselves.

## Command-line options

Run `prismarine --help` for the executable's option descriptions.

| Option | Purpose |
| --- | --- |
| `--prism-data <directory>` | Use a specific Prism data directory. |
| `--preferences <file>` | Use a separate Prismarine preferences file. |
| `--page <page>` | Open home, library, settings, accounts, friends, browse, instance, session, or firstrun. |
| `--instance <id>` | Select an instance for the instance/session page. Use its directory ID. |
| `--tab <tab>` | Select an instance tab; the session page accepts `all` for hardware. |
| `--section <name>` | Open a settings section, such as Storage or About. |
| `--interface <mode>` | Start in `desktop` or the `handheld` preview for this run. |
| `--dialog <name>` | Open a dialog for layout checks. |
| `--window-size <width>x<height>` | Set the initial logical window size, at least 960×640. |
| `--screenshot <file>` | Capture the rendered window and exit. |
| `--version` / `--help` | Print version or help and exit. |

Examples from a source build:

```sh
./build/prismarine --prism-data /path/to/PrismLauncher
./build/prismarine --page instance --instance "My Pack" --tab mods
./build/prismarine --page session --tab all
./build/prismarine --page settings --section About --screenshot about.png
```

`--preferences` changes the preferences file, not the Prism library. Use it with
`--prism-data` when working with disposable test data.

## Troubleshooting

- **Prism missing:** run the detector, confirm the executable in Settings, and
  check the selected data directory.
- **Token expired:** this is normal, and Prism refreshes it when you play. If sign-in
  fails at launch, open Prism Launcher and refresh the account.
- **Unexpected Prism windows:** check for an already-running Prism process and
  whether its Qt build or sandbox permits the quiet plugin.
- **CurseForge browsing needs a key:** add your key for direct browsing, or use
  Install with Prism Launcher for the supported Prism handoff.
- **A game fails:** the launch overlay keeps completed checkmarks and shows a
  finding from the current launch when one is available. Open its log link for
  more detail, or follow the settings, Mods, or Browse action. A missing Fabric
  API offers an installation review. Check the loader's required version against
  the proposed release before confirming; Browse lets you choose another version.
  After verification and installation, **Launch again** retries on your click.
  Other dependency ids use Browse because mod ids do not always name a project.
  Reproduce with the same instance in Prism when isolating launch problems.

For bug reports, include your OS, Qt version, packaging method, and the steps that
failed. See [Contributing](CONTRIBUTING.md) and [Security](SECURITY.md).
