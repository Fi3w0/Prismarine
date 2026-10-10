# Contributing to Prismarine

Issues, packaging fixes, screenshots of problems, and pull requests are welcome.
This is a solo project and still in beta. Keep changes focused; open an issue
before starting a large feature so its scope can be discussed first.

## Get started

Fork and clone the repository, then follow the [build instructions](README.md#build-from-source).
The core library is in `src/core`, the interface is in `qml`, and the Qt plugin
that hides Prism's launch windows is in `src/prismquiet`. Packaging lives in
`packaging`, with the platform builds in [.github/workflows/ci.yml](.github/workflows/ci.yml).

## Check your change

```sh
cmake -S . -B build -G Ninja -DCMAKE_BUILD_TYPE=Release
cmake --build build
```

If your checkout contains `tests/`, run `ctest --test-dir build --output-on-failure`.
The public checkout currently excludes that folder, so a successful CI build
does not mean the private test suites ran. Describe your manual checks in the PR.
Use a disposable Prism data directory and test instance, especially for changes
that install, delete, import, or update content. Never test against someone's real saves.

For interface changes, check the affected page and include a screenshot. For
packaging changes, install the package and confirm the app opens, QML loads,
and Prism Launcher can be found. Include your OS, desktop, Qt version, and
whether you tested Wayland or X11 when relevant.

## Pull requests

- Keep one fix or feature per PR and explain what users will see.
- Match the surrounding C++ and QML style; avoid unrelated formatting changes.
- Preserve unknown Prism settings and use atomic writes when editing its files.
- Update installation instructions when dependencies or package behavior change.
- Do not commit credentials, account files, personal paths, or private instance data.
- Use small commits with a human author and no AI co-author trailers. You own the changes you submit.
- Follow [SECURITY.md](SECURITY.md) for vulnerabilities.

Contributions follow the license of the component being changed: GPL-3.0-only
for code, CC BY-NC-ND 4.0 for the existing logos, and OFL-1.1 for the bundled
fonts. See [NOTICE](NOTICE) and [TRADEMARKS.md](TRADEMARKS.md) before changing branding.
