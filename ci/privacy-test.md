# Black-screen privacy test builds

Integration requirements:

- Register `PrivacyTestGuard="*res://scripts/privacy_test_guard.gd"` FIRST under
  `[autoload]`, before SoundManager. Do not defer its initialization.
- Add `privacy_test` only to the private test export's custom features. Normal
  production exports must not contain it. There is no runtime unmask command.
- Set `application/boot_splash/bg_color.privacy_test=Color(0, 0, 0, 1)`,
  `application/boot_splash/show_image.privacy_test=false`, and
  `rendering/environment/defaults/default_clear_color.privacy_test=Color(0, 0, 0, 1)`.
- Use `res://assets/privacy_test/black.png` (opaque 432 x 432 RGB black) for the
  private Android export launcher icon, adaptive foreground/background and
  themed icon where supported. The PNG contains no alpha channel.
  Black fills the complete adaptive icon safe area. It can also serve as the
  boot splash image, with a black splash background. Keep the regular icon.

The guard masks all Godot windows with a top-level opaque CanvasLayer, including
embedded popups. Resize coverage rounds outward. It mutes Master without ever
restoring game sound. Native input forwarding is replaced with a discard callback;
GUI input is disabled as a second barrier. This is not an OS-level input lock:
Android Home/Back/power/system UI remain under OS control. Engine Input polling,
injected input and scripts are not security-isolated; current game code does not
poll physical actions. Do not add polling-driven gameplay without reviewing this.

Production nodes remain visible and unpaused; this deliberately does not use
headless mode, hide the scene, or disable rendering. The mask adds GPU work and
can change culling/overdraw, so timings are privacy-mode timings, not identical
to a visible gameplay run. The guard reports actual RenderingServer renderer,
driver and device plus engine process/draw counters every five seconds. Startup
counts can be zero. Require increasing draw counters from a real Vulkan window
to claim continued rendering; headless evidence is not renderer verification.

Structural tests (after imports, when no other worker holds a timing window):

```
godot --headless --path . --script res://tests/privacy_test_guard_test.gd
godot --headless --path . --script res://tests/privacy_test_guard_test.gd -- --privacy-guard-test
```

The debug/headless opt-in only adds a mask; it cannot disable a privacy guard and
is ignored by graphical release builds. These tests check feature gating, opaque coverage, popup
registration, resize/visibility repair, muting and process progress. Separately
verify screenshots from cold launch, resize/rotation, popup, background/resume
and recents, and inspect physical touch/key behavior with a protected build.
Check actual runtime `renderer=forward_plus` and `driver=vulkan`, with increasing
frame counts; never infer these from project settings alone.

On a cloud graphical display, run the debug engine with
`--path . --script res://tests/privacy_test_guard_pixels.gd -- --privacy-guard-test`.
It verifies every root viewport pixel is opaque black with the production scene
visible/processing, then adds a red embedded popup and resizes. It also requires
draw-count progress and rendered objects. This does not measure hidden game GPU
work or prove Android native splash/recents protection. Software Vulkan results
are coverage evidence only, never device performance evidence.

Limits: Godot cannot mask Android's native launch splash before engine startup,
system bars/dialogs, lock screen, task thumbnail policy or OS screenshots. Black
export icons/splash configuration reduce exposure but need device validation.
Do not launch an unverified build on the user's phone. A script parse/import or
engine initialization failure precedes autoload protection; packaging must reject
such failures and verify the guard is present/first. Arbitrary game code that
deletes the guard, draws at its reserved layer or changes OS callbacks can defeat
it; this is a test-build safeguard, not a hostile-code security boundary.
Screen-off execution is not guaranteed: Android may suspend/throttle rendering.
Validate that separately only after black-screen protection is confirmed.
