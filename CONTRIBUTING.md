# Contributing to Prismarine

Issues, packaging fixes, screenshots of problems, and pull requests are welcome.
This is a solo project and still in beta. Keep changes focused; open an issue
before starting a large feature so its scope can be discussed first.

## Get started

Fork and clone the repository, then follow the [build instructions](TECHNICAL_REPORT.md#building).
The core library is in `src/core`, the interface is in `qml`, app-level theme and controller
input are in `src/ui`, and the Qt plugin that hides Prism's launch windows is in
`src/prismquiet`. Packaging lives in
`packaging`, with the platform builds in [.github/workflows/ci.yml](.github/workflows/ci.yml).

## Check your change

```sh
cmake -S . -B build -G Ninja -DCMAKE_BUILD_TYPE=Release
cmake --build build
```

Run `ctest --test-dir build --output-on-failure` for the public regression checks
in `checks/`. Local checkouts with the private `tests/` folder run additional suites.
CI runs the public checks even when that private folder is absent.
Describe your manual checks in the PR.
Use a disposable Prism data directory and test instance, especially for changes
that install, delete, import, or update content. Never test against someone's real saves.

For interface changes, check the affected page and include a screenshot. For
packaging changes, install the package and confirm the app opens, QML loads,
and Prism Launcher can be found. Include your OS, desktop, Qt version, and
whether you tested Wayland or X11 when relevant.

Desktop icons use `assets/logos/desktop.svg`; the decorative in-app logos are
separate. After changing the desktop SVG, regenerate PNG, ICO and ICNS files
with `python3 scripts/generate-icons.py` (requires librsvg's `rsvg-convert` and Pillow).

## Pull requests

- Keep one fix or feature per PR and explain what users will see.
- Match the surrounding C++ and QML style; avoid unrelated formatting changes.
- Keep files small, with one clear purpose each. Give a new screen, component or service its
  own file. Around 300 lines, look for a split, and split out what you touch in a file that is
  already larger instead of growing it.
- Preserve unknown Prism settings and use atomic writes when editing its files.
- Update installation instructions when dependencies or package behavior change.
- Do not commit credentials, account files, personal paths, or private instance data.
- Use small commits that each make sense on their own, with a human author and no AI co-author
  trailers. You own the changes you submit.
- Add user-facing changes to CHANGELOG in the same commit.
- Follow [SECURITY.md](SECURITY.md) for vulnerabilities.

## Documentation

Keep README focused on the overview and quick start. Update DOCUMENTATION for
usage changes and TECHNICAL_REPORT for architecture, build requirements, and
validation status. Summarize release-facing changes in CHANGELOG; put detailed
implementation history and evidence in DEV_CHANGELOG. Link dated reports and
design notes through the [docs index](docs/README.md).

The ignored root TODO is the local work queue. Keep personal paths, account data and raw local
logs out of public documentation, and summarise results instead of citing local folders.

Contributions follow the license of the component being changed: GPL-3.0-only
for code, CC BY-NC-ND 4.0 for the existing logos, and OFL-1.1 for the bundled
fonts. See [NOTICE](NOTICE) and [TRADEMARKS.md](TRADEMARKS.md) before changing branding.
