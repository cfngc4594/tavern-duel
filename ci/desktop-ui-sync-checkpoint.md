# Shared source-native UI checkpoint

Date: 2026-11-10. Implementation base: `865a7c92e75ed39ee1051fa77ccbcd0cca7a3d5e` on `develop`.

## Decision and audit

Desktop previously used a separate legacy presentation and input route while Android used the source-native phone presentation. Copying individual fixes into the legacy route would preserve two implementations and repeat the drift. The production `native_ui/shared_source_ui=true` setting now selects the source-native UI on both platforms. This is not `qa_phone_platform`, Android emulation or a fixture-only switch.

The coupled readiness gate activates the board scene, camera, layout, hit tests, actors and hand together. The old desktop branch remains available for explicit compatibility fixtures, not the shipping default. Historical names containing `phone` describe the recovered source assets, not the running operating system.

| Area | Previously divergent desktop behavior | Shared default and verification |
| --- | --- | --- |
| Board and layout | Legacy scene and camera | Shared source scene, camera, anchors and projected colliders; real resize and hit checks |
| Hand | Separate fan and pointer behavior | Click/tap expansion, collapse, native pickup/drop/return, out-of-turn browsing; mouse hover preview and 7-pixel drag retain desktop usability |
| Battlecry | Legacy targeting route | Archer enters the board provisionally before target selection; cancellation restores the card, commit charges once and damage waits for impact |
| Heroes and powers | Legacy presentation could miss native stat/animation fixes | Native hero health red tint, hidden zero-attack gem and Used/Restore power states; real power targeting/cancel/impact |
| Minions and targeting | Legacy screen-distance hover | Native hit polygons, attack selection, cancellation and combat resolution |
| Opening and lucky coin | Separate presentation gate | Normal opening, mulligan hit/confirm, second-player coin gather/flight and +1 temporary-mana play |
| Mana, decks and other source consumers | Different default presentation | Shared mana/deck renderers, opposing hand, history and banners; source/controller regressions remain in CI |
| Cancellation/restart | Native touch state could survive desktop cancellation or restart | Clear pressed state on cancel; reset native gesture and transition state on a new match |

The mouse adapter does not replace touch sliding/selection or the touch window-pixel threshold. No new hero-attack gameplay or gamepad support was added: this game's implemented attacker interactions are minions and hero powers.

## Window adaptation

Both old routes had resize code, but that did not prove every aspect ratio was framed correctly. Recovered source camera anchors cover approximately 3:2, 16:9 and 2.04:1. A 4:3 window previously clamped camera position to 3:2 while retaining the vertical FOV, clipping the right-side end-turn control. The shared adapter widens vertical FOV only below the minimum source aspect, preserving its horizontal framing. Board and gameplay cameras use the same policy without a later FOV overwrite.

At aspect >= 3:2 the source FOV and existing position interpolation/clamping are unchanged. Ordinary landscape Android phone ratios retain that layout. A 4:3 Android tablet would receive the narrow-window fix too, but no physical Android device/tablet or portrait/extreme-aspect test is claimed here.

## Accepted verification

- Real Windows 11, pinned Godot 4.7.1, Vulkan Forward+, NVIDIA GeForce RTX 4060 Laptop GPU.
- `tests/desktop_ui_integration_test.gd` loads unmodified `res://main.tscn` and requires the production shared setting, Windows identity and `qa_phone_platform=false`.
- Accepted run: **224 checks, zero failures, process exit 0, no script/runtime errors**. Normal opening plus deterministic gameplay sequences cover the rows above.
- Actual window sizes: **1920x1080, 1200x900, 2100x900 and 1280x720**. Each verifies projected anchors, coordinate round trips, the full end-turn hit polygon inside the viewport, board/gameplay camera alignment, mouse power hit/cancel, and hand expand/collapse. The captures use the live logical canvas, whose pixel dimensions may differ from the OS window. Fourteen rendered captures include opening, mulligan, coin, archer, damaged hero, used power, minion attack and all four sizes.
- The Android workflow's 41 focused CPU regressions pass locally with the pinned engine, including policy, camera, controller, touch, spell, hand, stats, coin, battlecry, mana and existing particle/cache regressions. CPU checks are not Android GPU/device tests.
- Production-main headless smoke and Python renderer/export-policy tests pass. Windows CI additionally checks the shared UI in the exported PCK without source fallback.

The rendered test injects mouse/key events into the real production handler while physical input is blocked. It is not a physical mouse/OS event-dispatch test. It changes match seed/seat and gameplay fixtures to reach deterministic states, not UI selection. It waits for actual transitions rather than treating a fixed delay as successful input.

## Privacy and evidence

The accepted run used `ci/run_windows_isolated.ps1` on a separate non-visible Windows desktop. Active desktop before/after remained `Default`; no desktop switch was requested. PrivacyTestGuard remained active and muted with a black root window. A SubViewport captures the live game world canvas, excluding the fixed overlay/cursor; a black root frame is never used as evidence of gameplay appearance. This checkpoint makes no screen-off claim.

Local raw evidence is under `build/desktop-ui/accepted/` plus `accepted.log`, `cpu-regressions-final.log`, and `source-main-smoke.log`. Build output is intentionally not committed. The committed `desktop-ui-sync-results.json` records the complete accepted assertion report and SHA256 hashes of the raw log/captures so those artifacts can be identified.

Reproduce the graphics check only with the isolated launcher and privacy guard:

```powershell
./ci/run_windows_isolated.ps1 -Base $PWD.Path -Exe <Godot-4.7.1-console.exe> `
  -Arguments '--path . --audio-driver Dummy --rendering-driver vulkan --rendering-method forward_plus --resolution 1920x1080 --windowed --single-window --script tests/desktop_ui_integration_test.gd -- --privacy-guard-test --ui-output=res://build/desktop-ui/accepted' `
  -Log build/desktop-ui/accepted.log -TimeoutSeconds 240
```

## Performance boundary

This is UI synchronization, not a performance optimization. Changing the camera, scene and actors invalidates a same-scene comparison with historical legacy desktop timings. `tests/windows_renderer_benchmark.gd` therefore requires explicit `--legacy-desktop-ui` for that historical fixture and records its limitation in output; it must not be advertised as the new default UI benchmark. Adapt that benchmark to the shared UI before resuming meaningful same-scene performance work.
