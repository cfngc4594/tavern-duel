# Windows release packaging

The Windows workflow is independent of Android. It uses Godot **4.7.1 stable**, the Windows x86_64 release template, production `main.tscn`, and GL Compatibility. The Android preset/configuration scripts are unchanged.

## Build locally (after installing Python 3 and Godot 4.7.1)

Use a **new** output directory. Preparation refuses to replace an existing one.

```powershell
python ci/prepare_windows_export.py . build/windows-release
$godot = 'PATH/TO/Godot_v4.7.1-stable_win64_console.exe'
$out = (Resolve-Path build/windows-release).Path
& $godot --headless --editor --import --path "$out/project"
& $godot --headless --path "$out/project" --export-release 'Windows Release'
& $godot --headless --path "$out/verify-empty" --script "$PWD/ci/verify_windows_pack.gd" -- "$out/package/TavernDuel.pck" "$out/manifest.json" "$out/package/verification.json"
& $godot --headless --path "$out/verify-empty" --main-pack "$out/package/TavernDuel.pck" --script "$PWD/ci/smoke_windows_main.gd"
# After the smoke PASS, record production_main_smoke_pass=true in verification.json
# as the workflow does, then run:
python ci/package_windows.py $out
```

Stop on any nonzero exit, `SCRIPT ERROR`, or `ERROR:`. Verification must print `WINDOWS_PACK_VERIFY_PASS`. Workflow enforces these conditions automatically.

Staging copies tracked runtime files only, plus the explicitly named export plugin. The runtime `references/` JSON/binary/image data is retained, but reference code, analysis scripts and documents are not. No benchmark entry point or test is exported. Metadata reports the source commit and whether the source checkout was dirty.

The Windows-only EditorExportPlugin preserves original byte-loaded files, including the existing 2026 files under `assets/`, `original_board/` and `source_rope/`. Runtime reference data is additionally verified. The manifest discovers the current exact set; the report separately exposes the baseline runtime count and total. Added/removed assets therefore remain visible.

**No source fallback:** the verifier starts in a fresh directory with only a minimal `project.godot`, asserts no source assets/main scene are present, mounts the PCK and checks every original-file SHA256, the production export metadata, compiled scripts and forbidden paths. It must never be launched with the source checkout as its `--path`.

The ZIP contains only `TavernDuel.exe`, `TavernDuel.pck`, `README.txt`, `verification.json` and `SHA256SUMS`. The outer checksum covers the ZIP, and its CRC is checked before publication. A Godot console wrapper, if generated, is not shipped. Release publication should use the workflow's exact commit/artifact, not a local benchmark export.

The executable is unsigned. No certificate/security configuration is changed, and users are not instructed to disable Windows protections. Runtime smoke/performance verification is separate from byte-preservation verification and must be reported accurately.

The Godot import can report malformed Unicode metadata in existing Belwe font assets. These exact diagnostic lines are retained in verification.json as import_font_diagnostics; uppercase Godot ERROR/SCRIPT ERROR and nonzero exits still fail the build, matching the Android runner's strict check. The production-main smoke independently rejects runtime errors. This does not claim every font glyph has been audited.
