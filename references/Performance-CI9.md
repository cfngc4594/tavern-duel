# CI9: remaining CPU overhead and mobile-source boundaries

## What was actually measured

Windows i9-13900HX / RTX 4060 Laptop, Godot 4.7.1 OpenGL compatibility,
1600x900 phone-layout practice scene with 7 hand cards and 4 minions.
No Android device was attached. These numbers are not phone FPS guarantees.

A temporary instrumented full-frame probe found the CI8 RGB-transmission
**script synchronization** took ~7.8 ms/frame in this scene, versus ~6.3 ms for
the environmental board update. This is distinct from the GPU transmission pass
(~0.65 ms in one earlier desktop measurement).

The transmission compositor itself remains intact. CI9:
- caches the source geometry list until SceneTree hierarchy changes;
- skips property/material synchronization for hidden geometry, resyncing on reveal;
- compares shader-uniform values and avoids repeated identical setters;
- preserves live camera, transforms, visibility, materials and animation values.

Same-process, alternating old/new sync calls (160 samples each after warmup):
**6.937 -> 3.441 ms mean**; P95 **7.445 -> 3.877 ms**.
All visible geometry, transforms, shader variants and uniform values matched.
This is about 50% less CPU for this subsystem, not 50% faster total gameplay.

A separate full-frame desktop probe measured P50 frame interval 23.847 ->
19.114 ms, with median draw calls still 351. Sequential single runs are noisier
than the isolated alternating benchmark; do not extrapolate to phones.

Particle draw work also reuses per-seek renderer/matrix constants and quad
indices, without changing sampling, timestep or count. Exact CI8-source A/B:
**11.515 -> 11.087 ms** (~3.7%, a small gain). Tests verify exact mesh arrays,
RNG/count/state, moving cameras/emitters, world/local space, render modes,
rewind and stopped tails.

## Reproduction

Save the old transmission script from commit a562918 into an ignored build file:

    git show a562918:scripts/native_combat_transmission.gd > build/transmission-before.gd
    godot --path . --script tests/transmission_cpu_benchmark.gd

The rendering benchmark requires a graphical backend, not --headless. A custom
reference can be supplied after `-- --reference=res://...`.

Correctness tests (headless):

    godot --headless --path . --script tests/transmission_sync_cache_test.gd
    godot --headless --path . --script tests/phone_particle_draw_snapshot_test.gd

The transmission regression covers uniform resets/texture changes, shader object
and same-object code edits, next-pass changes, hierarchy changes, reparenting,
nested viewport exclusions, hidden ancestors, root replacement and signal cleanup.

## Original mobile adaptation: evidence, not an excuse

The project does use recovered mobile-specific data:
- `original_board/assets/phone/scene_phone.json` and `interaction_profile.json`;
- `original_board/references/phone_camera.json`, phone hand bounds/fields/bones;
- `native_card_renderer.gd`: HeroPower Used/Restore `_phone` clips;
- `native_opening_presentation.gd`: `_iPhone` opening/mulligan clips.

This does not establish that every battle animation has a distinct phone version.
It also does not reproduce Unity's native animation/particle engine or Android
render-driver behavior. The current compatible implementation has measurable
script overhead that must be optimized, rather than blamed on the user's phone.

The environment profile currently chooses **Medium** from the recovered managed
default; it does not detect the actual Android device's original quality preference.
The recovered Low branch disables 4 decorative dust emitters but keeps 4 water
emitters (`source_particles.gd`, `phone_environment_particles_test.gd`). Other
quality-sensitive branches include render-texture scale and minion shake. These
are real quality tradeoffs and have NOT been enabled or reduced by this change.
No visual-quality reduction should be disguised as an equivalent optimization.

Remaining work requires actual-device CPU/GPU/thermal measurements. More invasive
native/GPU rewrites may help, but there is no measured phone speedup or FPS ceiling
for those proposals yet.