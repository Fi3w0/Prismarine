# Public regression checks

Normal CMake builds include these checks when `BUILD_TESTING=ON`. Run them with:

```sh
ctest --test-dir build --output-on-failure
```

They do not need the private `tests/` directory, a real library, an account or a game. CI runs
them on its build platforms. Source installers set `BUILD_TESTING=OFF` and skip them.

| Check | What it covers |
| --- | --- |
| `application_theme` | Deep and Light palettes, palette overrides reaching native dialogs, restoring the System palette, and scroll speed. |
| `navigation_motion` | The real navigation rail and top bar: idle rendering, the Now playing pulse, layout at minimum size, theme contrast, and the creator picture fetching and retrying. |
| `motion_components` | The real page loader and dialogs: direction, input during entry, interruption, reduced motion, and hide and show. |
| `launch_recovery` | The launch overlay, progress tracking, engine events, crash findings and reviewed fixes, using a loopback server. It never starts Prism or Minecraft. |
| `browse_flow` | The real Browse page with an in-memory catalog: direct and batch install, target and world rules, and layout at four sizes in both themes. |
| `gamepad_state` | Controller timing and direction rules, with no window or controller. |
| `gamepad_navigation` | Moving focus, dialogs, menus and scrolling, with simulated input. |
| `gamepad_values` | Sliders, number boxes, dropdowns and custom controls only changing when adjusted on purpose. |
| `launcher_mode` | Stable and Full detection with fixture engines, launch arguments, and validated preferences. |
| `appearance_preferences` | Allowed appearance values, persistence, staged Apply and Discard, colour dragging, and starting palette contrast. |

CTest uses Qt's offscreen platform and software rendering, so results do not depend on a
desktop. These checks do not measure CPU, memory or GPU use; the
[baseline runner](../scripts/baseline/README.md) does that for release builds. They do not
replace trying a physical controller. The fixture engines are shell scripts, so those cases
are skipped on Windows.
