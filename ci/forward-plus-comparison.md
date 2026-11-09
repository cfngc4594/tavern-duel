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

## Measured result (2026-11-09)

Direct export from develop fcb6721; official Release, i9-13900HX / RTX4060 Laptop,
1600x900, VSync off, Dummy audio, fixed 1/60 visual clock. Same EXE/PCK, with only
the command-line rendering method/driver changed. Four timed runs in opposite
orders; no capture readbacks, competing benchmarks, compilation or downloads.
PCK SHA256: BC08B49D5AE607373CFD5E0CBDAF236DDDC6BC0098F9E2E99F1B4047308F9C5D.

Warm (second-round) means, in milliseconds:

| Phase | First pair GL / Forward+ | Reverse pair GL / Forward+ |
|---|---:|---:|
| Idle | 11.19 / 11.26 | 11.02 / 11.30 |
| Senjin play | 12.16 / 11.67 | 12.14 / 11.79 |
| Taunt attack | 16.23 / 17.38 | 16.23 / 16.77 |
| Archer battlecry | 22.16 / 24.20 | 22.21 / 24.06 |

Battlecry P95: GL 29.49 / 29.84 versus Forward+ 39.83 / 35.61 ms.
P99: GL 48.63 / 51.82 versus Forward+ 61.95 / 60.97 ms.
The first Forward+ run had cold play/attack maxima of 331/396 ms. These are
observed stalls, not a proven attribution to shader compilation. They were not
removed from the cold results or presented as normal warm performance.

The four viewport render CPU counters improved under Forward+, but the whole
frame did not. In the reverse warm battlecry, CPU means for board/spatial/RGB
transmission/root were GL 0.55/0.71/0.46/0.84 versus Forward+ 0.45/0.17/0.11/0.18
ms. Individual GPU means were GL 1.32/1.50/0.49/0.90 versus Forward+
1.35/1.45/0.79/0.71 ms. These asynchronous per-viewport counters do not represent
all CPU script work and must not be summed across percentile buckets.

All four timed runs exited 0 with empty stderr. Both 17-event traces and gameplay
outcomes matched in each pair. Draw-call counts naturally differ by backend and
were not treated as an equality criterion. Particle simulation remains CPU
GDScript: merely selecting Forward+ does not move the solver onto the GPU.

## Visual result

Separate capture runs, excluded from timing, saved five matching 1600x900 frames
per renderer. Inspection confirms visible regressions: Forward+ looks washed out,
card/minion color and brightness differ, and battlecry blending differs. Geometry
and the action timeline are retained, but this is NOT a visually equivalent switch.

Exact a13da4feb source inspection confirms different GL and Forward+ color/blend
domains. Project shaders have many explicit GL-specific inverse color bridges;
numeric masks also use `source_color` samples. A blanket `return c` change or a
depth flip is not justified. No shader fixes or quality reductions were applied.

Local evidence: `build/renderer-branch/perf-*.log`, `measurements.json`,
`raw-verify.log`, and `captures/`. These ignored build outputs are not another
source checkout. Older ignored benchmark copies predate the user's in-place
instruction; they were not used for these develop measurements.

Conclusion: switching alone did not materially improve performance and regressed
the battlecry workload in both orders. Keep this on develop for further renderer
work; do not merge it into the usable main branch as a performance fix. `main` and
the published Windows CI5 remain unchanged. A GPU particle/compute implementation
is a separate experiment and has not been added here.
