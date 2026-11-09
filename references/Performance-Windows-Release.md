# Windows release-runner comparison

## Scope and result

Measured on 2026-11-09 from isolated commit `22564f1`, not by modifying the user's main worktree. Both runners consumed **the same PCK** and ran the same desktop-layout scene. This compares the allowed Godot editor binary running a game against the official Windows release template; it is **not** a debug-export-template comparison.

Godot 4.7.1 official `a13da4feb`, Windows 11, i9-13900HX, RTX 4060 Laptop GPU, NVIDIA 592.82, GL Compatibility. Hidden offscreen window, 1600×900, Dummy audio, vsync off, unlimited FPS. Main visual clock fixed at 1/60; normal animation processing is not skipped. Each run has two rounds; initial project loading and 180-frame warmup are excluded. Idle has 120 frames; each action has 180. Action calls are inside the timed window.

Runtime checks printed `OS.is_debug_build()/OS.has_feature("editor")` as `true/true` for editor and `false/false` for release.

### Warm round (milliseconds)

| Phase | Editor mean / P95 / P99 | Release mean / P95 / P99 | Mean reduction |
| --- | --- | --- | --- |
| Idle | 16.019 / 16.664 / 17.025 | 13.983 / 14.758 / 14.989 | 12.71% |
| Play Senjin | 17.311 / 21.271 / 30.285 | 15.150 / 18.307 / 24.230 | 12.48% |
| Attack taunt | 22.068 / 29.718 / 50.153 | 19.094 / 25.674 / 46.033 | 13.48% |
| Archer battlecry | 30.537 / 40.928 / 58.143 | 27.026 / 35.037 / 48.980 | 11.50% |

Release helps, but attack/battlecry still exceed a 16.67 ms frame budget. This does not establish stable 60 FPS. First-round release P99 was **worse** for play (66.750 vs 40.550), attack (100.406 vs 87.708), and battlecry (112.689 vs 77.136). These spikes were not localized to shader compilation or any other single cause.

### Reverse-order confirmation (release→editor)

The unchanged PCK was subsequently run release first, editor second, again with two rounds each. Warm-round results:

| Phase | Editor mean / P95 / P99 | Release mean / P95 / P99 | Mean reduction |
| --- | --- | --- | --- |
| Idle | 15.723 / 16.574 / 17.745 | 13.993 / 14.606 / 15.023 | 11.00% |
| Play Senjin | 17.077 / 21.150 / 27.763 | 15.139 / 18.486 / 25.059 | 11.35% |
| Attack taunt | 22.310 / 30.118 / 52.219 | 19.043 / 25.102 / 44.674 | 14.65% |
| Archer battlecry | 30.661 / 39.414 / 59.432 | 26.530 / 34.260 / 48.782 | 13.47% |

Both orders show improvement, but this is only one run per order, not a statistically controlled stability guarantee. Thermal/cache effects are not eliminated. In the reverse run, first-round release action P99 was 33.169/66.069/65.994 ms versus editor 37.557/78.440/77.153 ms; the original order's worse release spikes must not be omitted. Neither order establishes stable 60 FPS in attack/battlecry. This is neither an Android result nor a normal vsync-on user FPS guarantee.

Reverse logs: `release-reverse.log/.err`, `editor-reverse.log/.err`. Both exited 0 with empty stderr. External validation again matched all eight phase health/hand/unit/busy records, both 17-event sequences, and all draw-call medians. No benchmark process remained running.

## Correctness and packaging checks

The original manual benchmark put `play_card()` and `attack()` inside `assert()`. Release removes the assertions **and their argument evaluation**, which would remove the actions. The diagnostic Node entry instead uses ordinary always-evaluated checks and a persistent failure flag/exit code. The maintained manual benchmark now follows that approach too. A PASS string alone is not proof of release correctness.

External log validation found:

- Eight phase records and two complete event traces per runner, with no stderr output; release exit code 0.
- Identical 17 event names/order in every round, including actual `attack_contact` and `battlecry_damage1`. Event timestamps need not be identical.
- Identical phase-end health/hand count/unit count/busy: idle `[30,30]/7/4/false`; play `[30,30]/6/5/false`; attack `[30,30]/6/4/false`; battlecry `[30,29]/5/5/false`.
- Identical draw-call medians: first round 457/435/416/426; warm round 457/435/416/422.

Standard PCK export omitted 879 raw runtime files. An **isolated** export plugin used `EditorExportPlugin.add_file()` to preserve source bytes. Independent verification mounted the PCK from a directory with no source-resource fallback and compared **2026 raw files** below `assets`, `original_board`, and `source_rope`: missing 0, different 0. Extensions matched the APK verification policy (PNG/WebP/JSON/BIN/hash/mip/WAV/OGG). Do not interpret missing-texture speedups as an optimization.

Measured PCK SHA256:
`72BA12F317926B864EAEE8FCFF57D470E6A704FE81107178D269EFA0198ADD5A`

## Local reproducibility

Local ignored artifacts, not portable repository dependencies:

- `build/release-bench-src`: detached worktree at `22564f1`; temporary `bench_entry.gd/.tscn`, Windows preset `Benchmark`, source-script export mode, and `addons/raw_bench` export plugin.
- `build/release-bench-bin`: unchanged release template copied as `bench.exe`, `bench.pck`, import/export logs, `editor-full.log/.err`, `release-full.log/.err`, and `REPRO.txt`.
- `build/verify_bench_pack.gd`: raw-resource byte comparison.

The official release template rejected both `--path` and source-project discovery from CWD (`disable_path_overrides` compiled in). Use a standard exported PCK beside the template, not an engine rebuild or security-setting change. The debug template was blocked by Windows application control and was not retried/bypassed.

PowerShell outline, with absolute paths in `$editor`, `$src`, `$bin`, and `$verify`:

```powershell
& $editor --headless --path $src --export-pack Benchmark "$bin/bench.pck"
# Must run from a directory without source-resource fallback:
& $editor --headless --path $bin --script $verify

# Execute sequentially, wait for each process to fully exit; keep stdout/stderr.
Start-Process $editor -WindowStyle Hidden -WorkingDirectory $bin -Wait `
  -ArgumentList @('--main-pack', "$bin/bench.pck", '--position', '-20000,-20000',
                  '--resolution', '1600x900', '--audio-driver', 'Dummy') `
  -RedirectStandardOutput "$bin/editor-full.log" -RedirectStandardError "$bin/editor-full.err"
Start-Process "$bin/bench.exe" -WindowStyle Hidden -WorkingDirectory $bin -Wait `
  -ArgumentList @('--position', '-20000,-20000', '--resolution', '1600x900',
                  '--audio-driver', 'Dummy') `
  -RedirectStandardOutput "$bin/release-full.log" -RedirectStandardError "$bin/release-full.err"
```

Append `-- --smoke` for script-load-only validation; this is not gameplay validation. The current main-tree manual script remains a development-checkout SceneTree script, not a formal shipping entry. No permanent Windows export preset/plugin is introduced by this note.
