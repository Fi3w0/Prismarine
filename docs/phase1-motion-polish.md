# Phase 1: shared motion polish

Implemented 2026-11-05 after the inactive-indicator fix. This slice refines the
existing Qt animations and adds lifecycle checks; it does not replace navigation
or address the measured backend scanning delays.

## Behavior

| Interaction | New motion |
| --- | --- |
| Page entry | 180 ms fade and 200 ms slide over 12 logical pixels; back reverses direction. Previously 340/420 ms over 22 pixels. |
| Dialog entry/exit | 180/140 ms, with scale 0.985 → 1 on entry and 1 → 0.99 on exit. Previously entry lasted up to 320 ms with a larger scale change. |
| Launch overlay | The same 180 ms entry and 140 ms exit vocabulary. |
| Buttons | Shared 120 ms press/color feedback. |
| Context menus and palette | 120 ms fades, with OutCubic entry and InCubic exit. |
| Account menu | 180/140 ms fades matching dialog timing. |

The timing and slide-distance values live with the existing animation preference
in [Colors](../qml/theme/Colors.qml). The components continue to use Qt's native
animations; no additional rendering layer or runtime dependency was added.

[MotionLoader](../qml/components/MotionLoader.qml) settles its opacity and offset
when hidden, minimized, or motion is disabled. A replacement page restarts from
the proper direction without leaving the previous transform behind. Input remains
enabled during entry; tests activate the page button before the animation ends.

Reduced motion makes new dialog transitions immediate. If the setting changes
while a Qt-owned dialog transition is already running, Qt finishes that transition
before subsequent opens/closes snap. The public test covers that boundary and the
final opacity/scale. The implementation retains Qt's popup lifecycle rather than
adding a separate animation controller.

## Validation

- Current-source build passes; all **9/9 local suites** pass in the full run.
- The expanded `motion_components` check passes with offscreen/software rendering
  and directly on the native desktop renderer.
- Both public suites pass in a source copy without private tests; the expanded
  motion check is rebuilt and rerun there as well.
- Public checks cover direction, input during entry, rapid replacement, reduced
  motion, hide/show, interrupted dialog open/close, Escape, pointer access after
  closing a modal, and idle settling. They report no QML warnings.
- The full release probe completes navigation through library, settings, accounts,
  instance mods, palette, reload, and hide/show for small and large fixtures.

See [public test source](../checks/motioncomponentstest.cpp) and
[test instructions](../checks/README.md). Hosted CI and physical controller checks
remain pending.

## Measurements

The raw results stayed local and are not kept. Each release fixture had three sequential runs using the existing baseline runner.
The machine and metric definitions remain those of the
[original baseline](baseline-2026-11-05.md).

| Native release fixture | Median Home RSS | Median first-render proxy | Idle frames across three observation windows |
| --- | --- | --- | --- |
| 10 instances × 25 mods | 302.6 MiB | 552 ms | 0, 0, 0 |
| 250 instances × 100 mods | 321.4 MiB | 746 ms | 23, 9, 85 |

Home RSS remains close to the preceding idle-fix run (301.9/320.7 MiB). The native
desktop measurements include bursts of rendering and timing variance, so they do
not establish a clean CPU or startup comparison. No CPU or startup improvement is
claimed for this slice, and the cause of those bursts has not been isolated.

In the separate sequential navigation probes, settled Home, library, and hidden
windows each log **zero frames** in their observation windows for both fixture
sizes. Neither Home probe finds a running animation. Home process CPU is about
0.42% of one core in both probes; hidden samples are about 0.84% and 0.42%.
After visiting the pages, RSS is about 370/401 MiB. Retained memory after a short
navigation sequence alone does not establish a leak.

A separate offscreen/software large-library run also settles: all three idle
windows log zero frames and process CPU is 0–0.37% of one core. Its roughly
146 MiB RSS reflects a different renderer and must not be compared to native GPU
memory use.

Large-library reload still takes about 55 ms in the native probe. Shorter visual
transitions do not remove synchronous backend work. That investigation is next;
per-process GPU utilization and long-run resource budgets remain unverified.

## Review

Restart the launcher to see the rebuilt motion. Timing and distance are the first
prototype choices from the agreed research and can be tuned after hands-on use.
No claim of controller or Steam Deck support accompanies this change.
