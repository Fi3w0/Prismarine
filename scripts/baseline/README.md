# Phase 0 diagnostic

Linux-only, using Python's standard library, the built release executable, and
optionally a C++ compiler plus Qt Core/Gui/Quick/Test development packages.

```sh
cmake -S . -B build -G Ninja -DCMAKE_BUILD_TYPE=Release -DBUILD_TESTING=ON
cmake --build build --parallel 4
ctest --test-dir build --output-on-failure --timeout 120
python3 scripts/baseline/run.py --output build-baseline-new
```

Choose a **new** output directory for each run. Build directories beginning with
`build-` are ignored by Git. Keep the desktop otherwise quiet for comparisons.
Windows open and close during the run. No controller input is generated.

The runner creates empty, small (10 instances × 25 mods), and large (250 × 100)
synthetic libraries. Mods contain minimal valid Fabric metadata, with identical
files hard-linked across instances; no Minecraft installation or real saves are
needed. Fixtures also contain synthetic offline accounts and artwork. Each
process gets isolated preferences and XDG config/data/cache folders. A local
Prism stub prevents an accidental game launch, and a refused local HTTP proxy
keeps application network requests from reaching external services. This is
application-level isolation, not a network or filesystem sandbox.

Release runs measure process RSS and CPU from `/proc` every 50 ms. CPU uses the
convention that one fully occupied core is 100%; child processes and the desktop
compositor are excluded. The measurement window is 3–5.8 seconds after process
creation. These short samples do not establish long-term idle behavior.

Startup is a **first-render-log proxy**: elapsed wall time from process creation
to Qt's first `frame rendered` log. It is not a measurement of input readiness or
screen presentation. Each run has a fresh application cache, but the operating
system's filesystem cache is not flushed. Logging adds overhead.

The optional `probe.cpp` is compiled into a temporary shared library and loaded
with `LD_PRELOAD`. It records first-frame, focus, event-loop gaps, and synchronous
navigation/reload call durations; sends keyboard events to this test window;
and hides/shows the window. Its actions run sequentially to prevent nested event
processing from overlapping scenarios. Instrumented results are separate from
release baseline results and are not full QML profiler traces. A 16 ms heartbeat
can reveal event-loop delays, but is not a frame-time or CPU profiler.

Release sampling processes receive SIGTERM after six seconds; instrumented runs
and screenshot checks exit normally. Unexpected exits, missing rendering, and
probe timeouts cause a failing runner exit status. Raw logs, samples, screenshots,
and a JSON summary remain in the output folder. GPU utilization and physical
gamepad behavior require additional measurements.

For a shorter check or to isolate the animation setting:

```sh
python3 scripts/baseline/run.py --output build-baseline-small --libraries small --repetitions 1
python3 scripts/baseline/run.py --output build-baseline-motion-off --libraries small --repetitions 1 --skip-probe --animations off
```

The application supports the minimum Qt version declared in its main CMake
configuration; build the diagnostic against the same Qt installation as the app.
