> Prismarine now ships a Qt plugin (`src/prismquiet/`) that does the same for an unmodified
> Prism Launcher, so this patch is only needed where the plugin cannot load (for example a
> Prism built with an older Qt, or Flatpak).

# Prism Launcher patch: quiet command-line launches

Prism shows a "Please wait…" progress window while it signs in and prepares a game,
even when Prismarine started the launch and shows its own launch screen. Prism has no
setting for this, so Prismarine ships a small patch instead.

With the patch, `LaunchController` shows those progress dialogs only while Prism's own
main window (the classic launcher) is open. Otherwise it waits for the same tasks without
a window; the result, error messages and account prompts are unchanged.

Files changed: `launcher/Application.{h,cpp}` (adds `isMainWindowVisible()`) and
`launcher/LaunchController.cpp` (`runLaunchTask`). Based on Prism Launcher 11.0.3.
Prism Launcher is GPL-3.0; the patch is under the same license.

## Build (Linux)

```sh
git clone --depth 1 --branch 11.0.3 --recurse-submodules https://github.com/PrismLauncher/PrismLauncher
cd PrismLauncher
git apply /path/to/Prismarine/packaging/prism-patch/0001-quiet-command-line-launches.patch
# Prism's helper jars target Java 7: build them with JDK 17 (JDK 20+ refuses).
cmake -S . -B build -G Ninja -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX="$PWD/install" \
      -DJava_JAVAC_EXECUTABLE=/path/to/jdk17/bin/javac -DJava_JAR_EXECUTABLE=/path/to/jdk17/bin/jar
cmake --build build && cmake --install build
```

Then set **Settings → Interface → Prism Launcher program** to `install/bin/prismlauncher`,
or place the patched `prismlauncher` (with its `share/PrismLauncher` jars) next to the
Prismarine executable, which Prismarine picks up automatically. Windows and macOS builds
follow Prism's own build instructions with the patch applied.

Only one Prism runs per data folder: if an unpatched Prism is already running (including
one left in the background after a game), launches are handed to it and it shows its
dialog. Close it once; the patched Prism then stays the running one.
