# Phase 1: stop inactive navigation motion

Implemented 2026-11-05 as the first small implementation slice from the
[development plan](development-plan.md).

## Behavior

The Now playing indicator now pulses only when it is visible, animations are
enabled, and its window is visible and not minimized. Stopping restores full
opacity; showing the window or re-enabling motion resumes the pulse for an active
game. Game detection and the existing pulse timing are unchanged.

The original `parent.visible` expression resolved against the navigation button
rather than the indicator. A visible navigation button therefore kept the
indicator's animation running even while its dot was invisible. The fix names
the indicator explicitly and checks its containing window as well.
[NavigationRail](../qml/shell/NavigationRail.qml#L99)

## Regression evidence

Added a public `navigation_motion` check that loads the real navigation rail with
synthetic session state. It failed against the original source because idle
frames continued, and passed after the fix. It checks idle settling, followed and
externally discovered active games, reduced motion, hide/show, minimize/restore,
and returning to an ended session.
[Public check](../checks/navigationmotiontest.cpp)

All **8/8 local suites passed in 16.74 seconds**. A separate source copy without
the private `tests/` folder built and passed the public check, confirming that the
check does not depend on local-only test files. It also passed directly on the
native desktop renderer, beyond CTest's offscreen/software configuration.
CI and the Arch packaging check
now invoke CTest regardless of whether private tests are present. These workflow
changes have been checked locally; hosted cross-platform CI has not run here.

## Desktop measurements

Used the release executable with the same diagnostic runner, three sequential
runs per fixture, and animations enabled. The hardware, Qt version, desktop
session, and metric definitions are described in the
[original baseline](baseline-2026-11-05.md).

| Fixture | Idle rendered frames before → after, per 2.8-second observation | Median process CPU before → after | Median idle RSS before → after |
| --- | --- | --- | --- |
| Empty instance list | 175–177 → 0 | 2.90% → 0.36% | 301.8 → 298.3 MiB |
| 10 instances × 25 mods | 175 → 0 | 6.58% → 0.36% | 306.1 → 301.9 MiB |
| 250 instances × 100 mods | 175 → 0–1 | 6.13% → 0.36% | 322.9 → 320.7 MiB |

Continuous idle rendering is gone. One isolated frame in one large-library run
does not indicate a continuous render loop. No memory regression was observed.
CPU uses one fully occupied core = 100% and excludes subprocesses and the
compositor. Short samples have coarse clock-tick resolution; these numbers are
not long-term CPU or battery guarantees. Small RSS differences are not claimed
as a dedicated memory optimization.

Median first-render proxies were 334 ms, 340 ms, and 428 ms respectively, versus
350 ms, 551 ms, and 702 ms in the original runs. No startup regression was observed;
the apparent improvement is not assigned entirely to this fix because cache,
desktop, and graphics-driver variance were not controlled.

The runner completed successfully, including screenshots for all three fixture
sizes. The raw logs stayed local and are not kept. The release binary SHA-256 was
`f6dd289122b9d1bb9d52d4661782d0d69d5e5023b4169552be063c2d84a20df6`.

## Remaining scope

No reliable per-process GPU percentage or physical controller result is claimed.
Active-game behavior is exercised through synthetic state; no real Minecraft
session was launched. Page/dialog motion refinement and the larger-library
navigation delays remain separate implementation slices.
