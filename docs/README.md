# Documentation index

## Start here

| Document | Purpose |
| --- | --- |
| [README](../README.md) | Overview, screenshots, packages, and build quick start. |
| [Usage reference](../DOCUMENTATION.md) | Library/content features, shortcuts, CLI, and troubleshooting. |
| [Technical report](../TECHNICAL_REPORT.md) | Architecture, full build instructions, and current validation status. |
| [Changelog](../CHANGELOG.md) | Release-facing changes. |
| [Developer changelog](../DEV_CHANGELOG.md) | Implementation history and evidence links. |
| [Contributing](../CONTRIBUTING.md) | Development workflow and checks. |

## Plans and research

- [Development plan](development-plan.md): agreed scope, phase order, and acceptance
  boundaries. The local ignored TODO holds the active work queue.
- [Controller support](controller-support.md): how controller navigation works, its button
  map, and what still needs checking on real hardware.
- [Qt animation research](qt-animation-research.md): native motion types, possible
  applications, and performance tradeoffs.

## Measurement and implementation reports

- [2026-11-05 baseline](baseline-2026-11-05.md): initial environment, source/tests,
  desktop measurements, navigation findings, and evidence still owed.
- [Inactive navigation motion](phase1-idle-animation.md): first implementation
  slice, regression checks, and follow-up measurements.
- [Shared motion polish](phase1-motion-polish.md): page/dialog timing, lifecycle
  checks, and resource measurements.

Dated reports record what one run established, and their raw output stayed local. Use the
technical report for current status and the developer changelog for later corrections.

## Installation, testing, and policies

- [Source installers](../install/README.md)
- [Distribution packages](../packaging/README.md)
- [Optional Prism quiet-launch patch](../packaging/prism-patch/README.md)
- [Public regression checks](../checks/README.md)
- [Baseline runner](../scripts/baseline/README.md)
- [Security](../SECURITY.md), [trademarks](../TRADEMARKS.md),
  [code license](../LICENSE), and [notices](../NOTICE)
