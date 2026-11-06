# Developer changelog

Implementation history and validation evidence. Use [CHANGELOG](CHANGELOG.md) for
the release-facing summary and [TECHNICAL_REPORT](TECHNICAL_REPORT.md) for current
architecture and status. Raw logs and captures from these runs stayed local and are not kept.

## 0.5.0: controller navigation, 2026-11-06

- Add `GamepadState` (timing and direction rules, no SDL), `SpatialFocus`, `GamepadNavigator`
  and `GamepadInput` (optional SDL2). No page needs its own navigation order.
- Rules: the newest held direction wins, because the test pad reports two on a diagonal.
  Sliders, dropdowns and spin boxes keep their value when passed through. The first press
  only shows focus. Text fields never receive a typed space.
- A private run of the real window found what fixtures missed: direction keys must go to
  the focused control, because active focus sits on a grid's card and a ScrollView may claim
  arrows from its children. Library edges let go only for controller input, so arrow keys
  behave as before.
- User test on the PS4-type pad: the colour square took every direction. Value controls now
  need confirm first, show a frame and hint, repeat faster while adjusting, and cancel restores
  the old value through the same signals as a user change. Memory saves are debounced.
- Make Playing tabs and close buttons, All games rows, screenshots and group headers
  focusable, and add a context-menu button. Skin removal asks first on a controller, because a
  stray press should not delete a file. A private test fails if a left-clickable item on the
  checked pages has no focusable control.
- User test: pressing the menu button with the account menu open also opened the instance menu.
  Page-level buttons now do nothing while a dialog, menu or welcome screen is on top.
- Add SDL2 to CI, installers and every package recipe, with package names checked against
  each distribution. Accept vcpkg's static `SDL2::SDL2-static` target, which the first version
  missed, so Windows and macOS would have built without controller support. Release jobs
  set `PRISMARINE_REQUIRE_CONTROLLER`. None of this has run on hosted CI yet.
- The owner confirmed navigation, value adjusting and menus by hand on a BigBen pad.
- Gaps: no on-screen keyboard; Steam Input duplicates; button prompts.

## 0.5.0: Full mode engine test, 2026-11-06

- Local fork branch `prismarine-engine` of Prism 11.0.3 (uncommitted, not shipped) adds
  `--engine-info` and `--engine-events <file>`. Events are JSON lines, so they survive
  Prismarine closing. In engine mode the first-run wizard and account dialogs become
  failure events, because a hidden blocking dialog hung the launch.
- `Prism::setEngineProgram`: launches use a valid engine and pass the events file. A Prism
  program the user chose wins, which means Stable mode. `LaunchProgress` reads events
  alongside the existing log reading, with real download fractions. No engine means no change.
- Opt-in private `engineEndToEnd` ran a real engine with throwaway data and a fake account:
  signin > files > java > failed ("Game crashed", no game files or display). Not exercised:
  real sign-in, real downloads and fractions, a running game, Windows or macOS.
- Observed: Prism marks accounts Disabled when the saved client ID differs, so a fork with
  its own ID needs a new sign-in. `PRISMARINE_ENGINE_DIR` points at an engine for testing.

## 0.5.0 feedback: filters, avatar, mode buttons, Friends, 2026-11-05

- Browse categories were one OR facet, so the live API returned 10,773 mods for ten
  categories with the same top results. Each category is now its own facet (AND). The
  old test asserted OR and was changed with it.
- Creator avatar: a recreated Canvas gets the cached pixmap with no `imageLoaded`, so
  `ready` stayed false. Reproduced with a two-visit probe. Add `RoundAvatar`: unique URL
  per fetch, handles the cached case and retries. Canvas `drawImage(Image item)` drew
  nothing and an initial `onSourceChanged` fetched twice; the public check caught both.
- Update to Full mode and Remove Prism open dialogs and check for the engine. No removal
  code exists. The handheld choice applies immediately through `LauncherMode`.
- Scrolling: Flickable wheel distance follows `QStyleHints::wheelScrollLines` at 24 px a
  line and ignored velocity settings in a probe (3 lines = 72 px, 6 = 144 px). Add a
  1-3 multiplier on the system value, default 2, applied by ApplicationTheme.
- Set the desktop file name only when the entry is installed or in an AppImage, which
  stops Qt's portal registration warning when running from a build folder.
- Private `application` suite started the real Prism on each run: Main.qml resets the
  program from empty preferences, which falls back to detection. It left hidden processes
  behind, each holding 3 inotify instances, until file-watcher tests failed intermittently.
  A stand-in now comes first on PATH during the suite.
- Move the Friends toggle to Interface, staged by SettingsDraft. Disabling it stops LAN
  discovery and leaves the Friends page.
- moc emitted an empty file when a raw string in a check held a URL with `//`; the check
  builds that URL outside the raw string.

## 0.5.0 preparation: version, modes and remaining UI, 2026-11-05

- Version is now only set by `project()` in CMakeLists.txt. `PRISMARINE_VERSION` feeds
  the app and every User-Agent. Packaging recipes and metainfo moved to 0.5.0, named
  Boron to continue the elements series. No tag exists.
- Add `LauncherMode`: Stable or Full from a `prismarine-engine --engine-info` handshake
  (protocol 1, 2 second limit, started only when the file exists). Add feature list,
  Settings section, `FullModeBadge`, and `friendsEnabled`, `prismShortcuts` and
  `startInterface` preferences. Update and Remove buttons are disabled; no removal code.
- `InstanceModel::startPrism` refuses `--launch` with no accounts and emits
  `accountRequired`, replacing Prism's No Accounts dialog. Move the instance page's
  Prism link to its menu. `--interface handheld` opens full screen only.
- UI: New instance preview and group; Prismarine meter from own-process sampling; static
  `PageDecor` only on Playing, Accounts and Friends, because it crossed form text
  elsewhere. Rename the sidebar field to Filter. Fix "avatar in the rail" copy.
- Do not add an expired sign-in badge to the top bar. `signedIn` only reads the Minecraft
  token's expiry, and Prism refreshes that on launch (LaunchController.cpp:186), so it
  would be a false alarm. The Accounts status was changed for the same reason, and
  offline accounts no longer read as expired.

## 0.5.0: visual defect pass, 2026-11-05

- Root cause of the inverted memory slider: Main's palette left `dark`, `midlight`,
  `mid` and `light` at Basic defaults (#353637 fill, #e4e4e4 track). Set them from
  Colors, which also covers unstyled progress bars and busy indicators.
- Give the overview info card the row's full height; top-align Home's recent tiles;
  limit the compact Settings search and action rows to the page body's width. Keep
  HeroBackdrop waves in the bottom 28 px. Use `Ctrl+K`, matching `Ctrl+R` and the docs.
- Show Browse's version picker and Install only with a chosen project. Keep the
  catalog error line when results exist, because BrowseResults reports it otherwise.
- Private `layoutsAlignAndControlsFollowTheTheme` failed before these fixes with the
  measured offsets and slider pixels; public browse_flow and navigation_motion cover
  the Browse and shortcut changes. The slider is pixel-checked; progress bars and busy
  indicators were not rendered, and rely on the same palette roles.

## 0.5.0: expanded palette customization and Home, 2026-11-05

- Use Abyssal Settings' role editor, starting palettes and per-colour reset as
  interaction references while retaining Prismarine typography, sea colours,
  launcher cards and reference layout. Abyssal source/configuration was not edited;
  no Quickshell or desktop-specific dependency was introduced.
- Add twenty editable colour roles, four starting palettes, separate Deep sea and
  Light colour maps, live application/Library previews, and contrast readings.
  Apply/Discard/Defaults remain staged. Persist validated opaque colour maps in
  AppPreferences; update QML tokens and Qt's standard/native-widget palette.
- Track the desktop palette separately for System previews. Derive pressed button
  colours from the chosen accent and choose readable button text automatically
  unless the user overrides it. Repaint Canvas decorations/indicators on colour changes.
- Fix HSV edits leaving Apply disabled: the baseline held live QML colour values.
  Store immutable fingerprints instead. A compiled QML test reproduces consecutive
  H/S/V drags and verifies Apply, persistence, Discard, and subsequent edits.
- Refine Home around the reference: latest-instance hero and saved-world shortcuts,
  recent covers and New instance tile, favourite servers alongside compact news.
- Add favourites directly from Home with an explicit launch instance. Validate
  addresses/ports, keep repeated additions idempotent, and persist bookmarks.
  Integration checks capture the real world/server launch arguments through a
  test executable and exercise the news parser with a loopback feed.
- All 13 local CTest suites pass (25.89 seconds). Native Linux checks, preset
  contrast checks in both modes, and compiled-app captures pass. Other operating
  systems and real Minecraft launches remain unrun.

## 0.5.0: Settings reference and staged customization, 2026-11-05

- Restore the reference's banner, launcher preview cards, colour editor beside
  live preview and contrast panels, segmented options, grouped rows, and sidebar
  selection treatment. Keep compact forms scrollable and the action footer pinned.
- Add HSV pointer/keyboard controls, hex input, and six presets. Preview ratios
  are calculated from the draft colours and label low contrast honestly.
- Stage Interface and Library appearance changes in SettingsDraft. Apply persists
  them; Discard reloads applied preferences; Defaults stages default values.
  Instantiate a separate ColorPalette for previews so editing does not recolour
  the application. Keep backend integration controls explicitly immediate.
- Extend customization with rounded/angular controls and covers, cover sizes,
  loader badges, density, and optional Home sections. Add a Library layout preview.
- Initialize the start page once: saving preferences must not navigate away from
  Settings or destroy the draft while Apply is running.
- Public checks cover draft isolation, Apply, Discard, defaults, persistence, and
  validated extra preferences. Main tests check hex editing, independent theme
  preview, unchanged application colours before Apply, and staying in Settings.
- All 13 local suites pass; targeted native checks and a real compiled-app capture
  pass on Linux.
  Other operating systems remain unrun.

## 0.5.0: bounded settings, 2026-11-05

- Bound settings forms to 980 logical pixels. Use a searchable section picker
  on narrow or short windows, keep scrolling within the window, and group options
  under Interface, Library & covers, and Prism integration.
- Replace the large launcher chooser with an explicit Open Classic Prism action.
  Keep theme/accent choices together with a live preview and five colour presets.
- Add persisted, validated interface sizes (90/100/115%, applied on restart),
  library density (comfortable/compact), and six optional Home sections.
  Continue playing remains visible. Density changes cover columns and list rows.
- Apply sizing through Qt's application scale before GUI initialization, composing
  with an existing QT_SCALE_FACTOR and restoring the inherited environment before
  child processes start. Keep Qt 6.6 compatibility and generic platform APIs.
- Darken light-theme accents consistently in QML and native Qt palettes. Public
  checks verify all five presets meet 4.5:1 for accent text on all seven background
  tokens and for text on accent buttons, in both themes.
- Public appearance_preferences checks cover validation, persistence, invalid
  stored values, empty Home selections, and isolation. Main integration checks
  setting navigation, keyboard toggles, density changes, and Home visibility.
- All 13 local CTest suites pass (24.24 seconds). Native Linux settings checks pass;
  Deep/Light captures cover four sections at 960×640 and 1400×875. Six isolated
  process captures verify the three sizes, with inherited Qt factors 1 and 1.25.
  Other operating systems remain unrun.

## 0.5.0: Browse installation flow, 2026-11-05

- Keep the installation target and Minecraft/loader compatibility above results
  at every window width. Modpacks explicitly create a new instance.
- Offer a direct Install action for the chosen release, using the existing
  dependency review and verified installer. Pass the selected datapack world.
  Direct installation preserves the separate batch selection.
- Make Select multiple an explicit mode. The batch bar names its target, retains
  per-instance/type selections, and hides empty selection controls outside that mode.
- Use a full project view with a Results button on narrow or short windows;
  keep the split view on larger windows. Reuse ContentIcon for missing result art.
- Add public browse_flow checks for direct/batch actions, target isolation,
  explicit world selection, keyboard activation, and compact bounds in both themes.
  Private Main integration installs a hash-verified loopback download and checks
  that unrelated batch choices survive. Native Linux checks pass; other OSes unrun.
- All 12 local CTest suites pass.

## 0.5.0: artwork editor and native file chooser, 2026-11-05

- Use light/dark SVG profile placeholders when a skin is absent or unavailable.
  Register both assets in the app and account/navigation check resources.
- Start with QApplication when optional Qt Widgets is available, enabling the
  platform desktop file chooser. Keep QGuiApplication as the build fallback without
  Widgets. A local chooser probe reports KDEPlatformFileDialog with QApplication,
  versus the Quick popup with QGuiApplication. Windows/macOS were not run.
- Open image selection in Pictures. Rework Instance artwork with a single scope
  selector, quiet square/wide previews, source presets, separate upload row,
  named screenshot thumbnails, and a pinned footer. Reset follows the selected
  scope, and the dialog states that changes apply immediately.
- Validate card-only changes/reset, compact bounds, and native rendering with
  disposable data. The fresh demo excludes synthetic striped screenshots and
  synthetic flat skin textures; real library/account data was not edited.
- Synchronize explicit app themes with the Qt application palette and supported
  color-scheme hint. Uses generic Qt APIs with no KDE dependency; System restores
  the desktop palette. Guard newer APIs for the Qt 6.6 minimum.
- Add an explicit Back button to instance headers, including Shaders. With no
  history, return to Overview and then Library.
- Release rebuild and all eleven local CTest suites pass (21.70 seconds), including
  palette synchronization and Back navigation. Native dark-picker and compact
  Back-button captures were reviewed. Only Linux was run.

## 0.5.0: covers and Library, 2026-11-05

- Draw filled water bands and an outline motif, with stable wave variation from
  the instance id. Retain the existing cover colours, image/screenshot choices,
  and optional brass frame. Remove the cover Shape's 4× MSAA layer. This is a
  structural rendering change, not a measured performance improvement.
- Use square library artwork with names, loader/version, and last-played text
  underneath. Row height uses font metrics for two title lines. Selection,
  explicit Play, double-click open, title rename, drag/drop, and keyboard movement
  retain their existing roles. Show Play on hover or keyboard selection.
- Refine the selected-instance panel: preview, title, chips, Play, facts, three
  primary destinations, and four compact shortcuts. Keep other operations in a
  menu; retain the group sidebar for larger collections.
- Move Home's recent-instance names below the covers. Each whole tile opens the
  instance and supports keyboard focus. No automatic launch on those tiles.
- Provide an image fallback for the software renderer. Keep the native clipping
  mask available before an image loads; delaying its layer until Image.Ready
  left the selected preview blank in the native pixel check.
- Private layout checks exercise 250 synthetic instances, long names, three
  window sizes, selection after resize, keyboard movement, custom images in both
  the grid and preview, and artwork access. Native checks await rendered pixels
  and reacquire delegates after fixture file changes reset the model.
- Release rebuild, all ten local CTest suites, the native Linux layout/image
  check, and local Markdown link checks pass. Twenty-eight captures cover both
  themes, 10/250-instance libraries, cover/list views, three Library window sizes,
  and compact/wide Home views. The artwork picker previews square cards too.

Only Linux was exercised. The paused large-library performance investigation
was not resumed; 250-instance checks concern layout and scrolling, without
CPU, memory, frame-time, or startup claims.

## 0.5.0: launch failure recovery, 2026-11-05

- Keep the last non-failed stage in `LaunchProgress`, including intermediate
  stages consumed within one `poll()`. The overlay uses it for both completed
  checkmarks and the failure position; progress no longer falls to zero.
- Snapshot `GameSession::launchDiagnosis()` before dismissing a stopped launch.
  Only current-launch logs/reports count. Abort and retry clear the finding.
- Show a bounded finding summary and actions in the overlay. Recognize Fabric
  missing-dependency lines; only the known `fabric-api` project gets a direct
  install review. Unknown mod ids stay searchable instead of being treated as
  project slugs.
- Resolve the newest stable release for the instance's game and loader through
  the existing installer. Keep the loader requirement visible, offer Browse for
  a different version, require confirmation, verify downloads, preserve existing
  files, and offer a manual launch retry after completion. Reject installs when
  the instance is detected running, including a check before committing files.
- Add public `launch_recovery` regression coverage and a private Main.qml
  integration check, including installation and retry through a Prism stub.
  The original failing check took 105 ms: expected step 3, actual step 0.
- Release rebuild and all ten local CTest suites pass. Compact dark/light failure
  states and installation review were captured with disposable data. Local link
  checks pass for tracked and untracked public Markdown.

Only Linux was exercised. Fixtures do not establish real-game launch recovery,
cross-platform process detection, or version-range satisfaction beyond the game
and loader filters; the review retains the loader requirement for that decision.

## 0.5.0: typography scale, 2026-11-05

- Add the `Typography` QML singleton and register it in the application and both
  public check bundles. Use named size roles throughout pages, panels, dialogs,
  shared controls, and inline links. The instance icon's initial still follows
  its icon size; link labels still accept a caller-provided token.
- Follow the design scorecard's 15 px body direction. Use 13 px secondary text,
  12 px captions, and an 11 px floor for badges/chart labels. Consolidate the
  previous 26 explicit size values into 15 distinct sizes. Retain Marcellus SC,
  font weights, and responsive hero/welcome headings.
- Make the private settings click check scroll to its target at the minimum
  window size, instead of relying on a fixed window-height increase.
- Screen captures use synthetic instances, isolated preferences/XDG paths, and
  a refused proxy. They do not establish real launch behavior or platform parity.
- Release build and all nine local CTest suites pass. Review covers both themes
  at 960×640 and 1400×875; physical-display review and Windows/macOS checks remain
  open. Tracked and untracked public Markdown links also pass locally.

## 0.5.0: colour tokens, field outlines, labelled rail, 2026-11-05

- Lift the dark surfaces in `Colors.qml` and keep their existing light-to-dark
  order, so components that layer surfaces keep the same relationships. Add `rail`
  for the darkest layer and `outline` for field boundaries.
- Use `outline` on text fields, select boxes, library search, and instance notes.
  It stays at least 3:1 on every background token in both themes; `border` remains
  decorative.
- Add text labels to `NavButton`, used by the navigation rail, which fits at the
  640 px minimum window. Move search and the account switcher to a new `TopBar`.
  Shortcut hints show Command on macOS; only Linux was run.
- Add public checks for rail fit at 640 px, top bar actions and menu placement, and
  text, secondary text, and outline contrast in both themes.
- Nine local suites pass. Key pages were compared offscreen before and after, with
  one native library capture. Light-theme accent text remains about 4.1:1 on
  `surface`, below the 4.5:1 text minimum; that existing value is unchanged and not
  covered by the new check.

## 0.5.0: shared motion polish, 2026-11-05

- Centralize 120/180/140/200 ms feedback/entry/exit/page timings and a 12-pixel
  slide distance in the existing Colors singleton.
- Refine MotionLoader, MotionDialog, shared buttons, menus, palette, and launch
  overlay. Stop and reset page entry when hidden, minimized, or disabled.
- Add public `motion_components` coverage for input during entry, direction,
  rapid replacement, dialog interruption, reduced motion, and idle settling.
- Nine local suites pass; native rendering and a public-only source copy pass.
  The expanded motion check also covers dialog hide/show and pointer input after
  closing the modal.
- Native Home RSS is about 303/321 MiB for small/large fixtures. Settled navigation
  probe windows log zero frames; native release samples contain rendering bursts,
  so no clean CPU/startup improvement is claimed.

See [the motion report](docs/phase1-motion-polish.md) for measurements, limits, and
the in-progress Qt popup transition behavior when reduced motion changes.

## 0.5.0: documentation structure, 2026-11-05

- Keep overview, screenshots, package downloads, and a build quick start in README.
- Move the usage reference, keyboard shortcuts, CLI, and troubleshooting into
  DOCUMENTATION. Put architecture, full build instructions, and validation status
  in TECHNICAL_REPORT.
- Add this developer history and a docs index. Keep the agreed phase plan,
  animation research, and dated measurements under `docs/`.
- Put controller design notes in `docs/controller-support.md`; keep `claude.md`
  as a compatibility pointer. The ignored root TODO remains the local work queue.

Validation: local document link and anchor checks pass; build examples retain
the existing commands and the CLI reference matches the source parser.
No runtime behavior changes in this documentation pass.

## 0.5.0: inactive navigation motion, 2026-11-05

- Reproduce continuous idle rendering with a public check against the real
  navigation rail. The old `parent.visible` expression followed the navigation
  button's visibility while the indicator itself was invisible.
- Name the indicator in its running condition and gate on its window's visibility
  and minimized state. Stop at full opacity and resume for active games when
  visible and motion is enabled.
- Add `navigation_motion` under `checks/`, independent of private test data.
  CTest runs in CI and the Arch packaging check even without the private suites.
- Eight local suites pass, as do the native-renderer check and a public-only source
  copy. Hosted platform CI remains pending.
- Release measurements across empty, small, and large synthetic libraries show
  0–1 idle frames per observation window, versus about 175 before the fix.
  Median launcher CPU is about 0.36% of one core, with no observed RSS regression.

See [the implementation report](docs/phase1-idle-animation.md) for test details,
measurements, and limits. No real Minecraft session or controller check is claimed.

## Baseline and design research, 2026-11-05

Rebuild the source checkout and run the original seven local suites. Establish
synthetic-library measurements and audit navigation before implementation.
Record the agreed phases and native Qt animation candidates.

- [Baseline](docs/baseline-2026-11-05.md)
- [Qt animation research](docs/qt-animation-research.md)
- [Agreed development plan](docs/development-plan.md)
- [Diagnostic runner](scripts/baseline/README.md)

## Earlier releases

The existing [0.4.0 changelog](CHANGELOG.md#040--beryllium-beta--2026-10-11)
records the first public beta. This file starts with the 2026-11-05 development
session; it does not reconstruct an unrecorded implementation history.
