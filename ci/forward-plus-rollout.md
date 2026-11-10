# Shared Forward+ rollout

The desktop default and mobile override both select `forward_plus`. Automatic
OpenGL/Compatibility fallback is disabled. Devices without a compatible rendering
backend fail to start rather than silently using a different renderer. Windows
may use Vulkan or Direct3D 12; the Android target requires compatible Vulkan
1.1+ hardware and drivers. This does not enable the experimental compute path
or remove existing platform-specific optimizations.

## Build checks

- `ci/renderer_policy.py` rejects conflicting source renderer overrides and
  enabled OpenGL fallback. Its unit tests include malformed packed data and
  legacy mobile settings.
- Android verification reads the actual ECFG `assets/project.binary`, in addition
  to exporter metadata. Godot 4.7.1 omits the desktop renderer when it equals the
  engine's Forward+ default; the report explicitly records that default case.
  Mobile Forward+ and disabled OpenGL fallback must remain explicitly packed.
- Windows production staging accepts only the reviewed raw-asset exporter,
  removes benchmark main-scene overrides, and verifies Forward+ export metadata.
  Raw-file hashes, compiled scripts and production entry-point checks remain.
- Normal Android and private Android packages have separate application IDs.
  The optional `privacy_test` workflow input changes only the disposable test
  build. It uses black launch assets and the first autoload's opaque mask, mutes
  game sound, and blocks game input. Existing CI21 and its data are untouched.

## Local validation, 2026-11-10

Godot 4.7.1 (`a13da4feb`) was used. Source policy, nine packed-policy unit tests,
repeatable normal/private export-configuration checks, and a real Godot-saved
ECFG file passed. Both normal and active privacy-guard structural tests passed
without engine errors; the graphical pixel test parsed successfully.

These headless tests produce zero rendered frames even when renderer/driver
labels say `forward_plus`/`vulkan`. They do **not** prove Vulkan GPU execution,
black pixels, Android lifecycle privacy, frame rate, temperature or battery use.
The cloud environment has no graphical display or Xvfb; graphical validation is
still pending. No phone game was launched or screen state changed for these
checks. Do not launch the private APK on a sensitive screen until its visual
protection has been verified in a suitable environment.

Privacy-mask timing is not equivalent to ordinary visible gameplay: extra
compositing and occlusion/overdraw changes can alter GPU work. Physical panel-off
behavior and sustained real-device rendering require separate evidence. See
[privacy test precautions](privacy-test.md).
