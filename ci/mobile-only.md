# Android-only product scope

The only supported distributable is the ARM64 Android APK. Windows release CI,
Windows packaging/staging helpers, Windows benchmark exports and the legacy
camera selection have been removed. The phone source camera is used in the
editor as well, with no product switch back to the desktop layout.

Preserved:
- Phone board, cards, heroes/powers, mana, decks, opening, targeting and rope.
- Fixed UI CanvasLayer, name banners and card details. World-only diagnostic
  captures are not proof that the full UI was rendered.
- Touch input, privacy-test safeguards, Android raw assets and APK verification.
- Phone/tablet aspect handling, shared logic/effect tests and editor mouse input.
- Shared particle/math diagnostics. Old reports in ci are historical
  measurements, not claims about the new phone-only product. Windows-only
  prepared-scene and source-image experiments have been removed.

`tests/mobile_ui_editor_integration_test.gd` is an optional rendered editor
smoke test, not desktop release support. The old desktop_ui_integration_test.gd
path is a tiny compatibility wrapper for existing local recording scripts.
Both paths are excluded from APKs. A graphical run needs the privacy preflight
in privacy-test.md; headless tests are not visual or Android-device verification.

## Checks

Use the pinned Godot 4.7.1 engine and existing Android SDK/export templates.
Run Python checks `ci/renderer_policy.py`, `ci/test_renderer_policy.py`,
`ci/test_configure_export.py`, and `ci/test_mobile_only.py`, then import the
project and run the focused GDScript list in `.github/workflows/android.yml`.
Build with the sole `Android Playtest` preset and verify the resulting APK with
`ci/verify_apk.py`. Follow the workflow's raw-asset repair, alignment and signing
steps when preparing an installable artifact. No device install or launch is
part of a source/configuration regression pass.

## Verified on 2026-11-11

- Godot 4.7.1: 50 focused headless regression scripts passed, including phone
  touch/hand/spells, actors, mana, battlecry, particles, projection and source
  board lifecycle. Separate rope and 96-case opening-rule checks passed.
- 15 Python configuration/policy tests passed. Normal and enabled privacy-guard
  structure checks passed. Import completed without script errors.
- Android ARM64 debug export passed. Raw-asset hashes, archive CRC, no QA entries
  and 16 KiB ZIP alignment are checked locally. This local APK is unsigned.
- Existing missing project-icon diagnostic uses Godot's fallback icon; no new
  icon was chosen as part of this code cleanup.
- No phone installation, physical touch, GPU visual/performance validation or
  Android background/resume validation was performed.
