# Prismarine development plan

Agreed in the first planning session, 2026-11-05. The product direction is a
professional daily launcher: improve core workflows, retain the deep-sea identity,
and simplify existing UI when useful. Additions must improve a named workflow.

## Scope and sequence

| Phase | Scope | Exit evidence |
| --- | --- | --- |
| 0. Baseline | Rebuild current source, run available tests, create disposable fixtures, measure desktop performance, audit navigation. | Reproducible measurements and a findings review before implementation. |
| 1. Daily polish | Find and launch instances; install/update content; understand and recover from failed launches. Refine hierarchy, motion, and customization. Fix measured backend problems. | Relevant regression checks, manual workflow checks, and agreed performance limits. |
| 2. Controller loop | Start with a PS4 controller on the desktop: account and instance selection, launch, failures, return, focus, back, and scrolling. | Physical controller verification; input does not interfere with Minecraft; keyboard and mouse remain usable. |
| 3. Full mode | Stable keeps using an installed Prism. Full runs on a Prism fork shipped as a hidden engine process, with extra features, so the Prism app can be removed. Share Prism locations with explicit conflict handling. | Clean-install authentication, launch/recovery, mode switching, and shared-library checks. |
| 4. Application updates | Stable checks and verified background downloads; apply on launcher restart; opt-out and separate nightly channel. Respect package-managed updates. | Recovery from interrupted downloads and failed updates; usable previous installation. |
| 5. Horizon experiment | Detect an existing Horizon installation; distinguish its instances; launch and monitor it. Separate data roots. | Useful, maintainable launch integration before installation/update management is considered. |
| Later: Steam Deck | Physical handheld validation, including readability, text input, suspend/resume, and returning from Minecraft. | Do not claim verified handheld support before device checks pass. |

Steam Deck testing was explicitly deferred. A PS4 controller is the immediate
physical test target; no controller was attached during the initial baseline.

## Product boundaries

- Independent means one Prismarine installation supplies a Prism-derived engine;
  it does not require embedding or reimplementing Prism's backend. Occasional
  upstream account/recovery dialogs are acceptable in the first preview.
- The fork changes Prism's code, so public builds need their own Microsoft client ID
  and CurseForge key, and must not present themselves as Prism. New Microsoft IDs
  reportedly need Mojang approval before Minecraft sign-in works.
- Features marked Full mode only stay disabled in Stable. No Prism removal code ships
  before the engine has passed its own acceptance checks.
- Preserve shared Prism locations, but initially coordinate ownership rather than
  promising simultaneous management by both launchers.
- First controller milestone is the complete everyday play/recovery loop. Full
  controller access to setup and management screens follows.
- Initial customization is bounded: theme/accent, scale, library density, artwork,
  Home sections, and reduced motion.
- Backend refactors need evidence or a direct dependency on an agreed workflow.
- Make necessary regression checks public and reproducible with synthetic data.
  This does not authorize publishing private fixtures or credentials.
- Performance limits are to be chosen from measurements, not assumed beforehand.

## Status

Updated 2026-11-06.

| Phase | Status |
| --- | --- |
| 0. Baseline | Done. See [the baseline](baseline-2026-11-05.md) and [animation research](qt-animation-research.md). |
| 1. Daily polish | Built, with [idle](phase1-idle-animation.md) and [motion](phase1-motion-polish.md) reports. Windows and macOS results and agreed performance limits are open. |
| 2. Controller loop | First version works on a test pad. See [controller support](controller-support.md). |
| 3. Full mode | Engine test only, on a local Prism fork. No release includes it. |
| 4. Application updates | Not started. |
| 5. Horizon experiment | Not started. |
| Later: Steam Deck | Not started. |

Current validation lives in the [technical report](../TECHNICAL_REPORT.md).
