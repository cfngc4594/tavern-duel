# develop: Windows Forward+ experiment

This branch changes the desktop renderer to Forward+. Mobile retains its previous
Compatibility override. It is an experiment, not an assertion of better performance
or equivalent visuals. The working repository is used directly, without a project
copy or worktree. The normal main scene remains `main.tscn`.

`Windows Renderer Benchmark` exports a separate executable from this checkout using
the `renderer_benchmark` feature. A minimal game subclass fixes only the visual
clock to 1/60; it does not copy or rewrite production scripts. The driver runs idle,
Senjin play, taunt attack and Elven Archer battlecry twice and reports frame times
and four viewport CPU/GPU timing counters. `TIME_PROCESS` is an approximately
one-second window maximum, not per-frame CPU time. Viewport percentiles must not
be added as a synchronized whole-frame GPU timeline.

Build with Godot 4.7.1:

```text
godot --headless --path . --export-release "Windows Renderer Benchmark"
```

Run the same exported EXE/PCK with either renderer, at the same size:

```text
RendererBenchmark.exe --rendering-method gl_compatibility --rendering-driver opengl3 --resolution 1600x900 --audio-driver Dummy
RendererBenchmark.exe --rendering-method forward_plus --rendering-driver vulkan --resolution 1600x900 --audio-driver Dummy
```

For a separate visual-only run, append `-- --capture-dir=C:/absolute/output/path`.
This saves fixed-frame rendered PNGs. Readbacks affect timing, so capture runs
must not be used as performance results. Compare both cold and warm rounds and
repeat in reverse order. Check runtime renderer/GPU labels, state/event parity,
stderr and original raw assets before drawing conclusions.

The existing raw runtime export plugin is enabled for direct Windows exports:
otherwise imported PNGs used by `FileAccess` can be missing. The initial package
was rejected for this reason; the corrected pack has all 2026 baseline raw assets
byte-identical in a source-free verification environment.

Some shaders explicitly contain a GL-specific color bridge. Forward+ color,
brightness, transparency and layering still need comparison; no shader changes
or particle quality reductions are included in this initial experiment.

Status: imports and Release export pass; renderer performance/visual comparison
is pending. `main` and published Windows CI5 remain unchanged.
