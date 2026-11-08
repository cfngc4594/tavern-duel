# v31 source-driven generic summon migration

This build keeps the existing 1.0.0.5834 game rules and uses recovered 37.0.0.255130.254477 visual assets. It is a Godot compatibility implementation, not the original Unity player and not a claim of pixel-identical rendering.

## Production integration

- `scripts/native_summon_player.gd` selects original ordinary small (base cost 0–3), medium (4–6), opponent and generated-spawn routes. The source large route (7+) is retained for diagnostic boundary coverage; no current normal-pool minion costs 7 or more.
- `references/summon_v31/runtime_routes.json` retains the recovered ordered FSM actions, exact target object IDs, clip identities and timing evidence. Runtime visual scheduling reads that file. Disabled actions are not executed.
- `native_summon_curves.gd` samples original AnimationClip keys, slopes, weighted tangents and quaternion components. Original legacy clips have no measured client-runtime duration; their last keyed times reconstruct the animation duration. The misleading legacy `m_StopTime=1` default is not used.
- `native_summon_assets.gd` recreates source transform hierarchies, mesh positions/indices/UV0/UV1/colors, material values and animation properties. Full 64-bit IDs remain strings.
- `native_card_renderer.gd` uses original in-play portrait/frame/gem mesh surfaces, live original-font stat glyphs, and the exact source Yeti portrait. Hand release clones real original hand-card geometry rather than a card-face rectangle.
- `native_summon_particles.gd` implements the recovered enabled particle modules with an explicit compatibility solver and reports per-system support and limitations.
- Generic summon animation no longer uses the earlier hand-written 1.9-second release/landing Tween. `dual_class_rules.gd` is unchanged. Dedicated battlecry animation sequences have not been ported by this work.

## Timing and parentage

| Route | Out finished | In finished/ready | Residual cleanup |
|---|---:|---:|---:|
| Friendly small | 1.0 s | In + 0.5 s | In + 2.5 s |
| Friendly medium | 1.0 s | In + 0.3666667044 s | Ready + 2.5 s |
| Opponent, all costs | 0.8499999940 s | In + 0.4300000072 s | Ready + 2.0 s |
| Generated, both sides | No hand Out | 0.6833333373 s | FadeOut ends + 0.3499999940 s |

The original `SpellFinishAction` sends a callback without necessarily ending its FSM. Out callback, visible reveal, ready callback, and residual cleanup are separate events. Source audio is triggered at the actual route entry; character play audio begins with Out, or generated In. Existing v30 original audio definitions retain their source-specific sound delays.

Card-parent slot travel is separate from Actor local animation. The source ZonePlay defaults are 1.0 second and iTween `easeOutExpo`; this board uses that default with its own slot coordinates. Actual original-client transition overrides were not recovered. Opponent Hidden Actor additionally uses source local `(0,6,0)`, 0.4-second `easeOutQuad` motion.

Original Out/In effects are parented under the whole Actor, not RootObject. The medium ring and dust emitter alone detach with world position preserved at their source NONE-state action. Clip path `""` targets the whole Actor.

## Rendering and composition

Shader equations and render states are translated from the recovered original shader bytecode. The Godot color-conversion bridge is separate from the source equation. Unity-facing back-cull mesh surfaces use an explicit winding bridge; the portrait retains source Cull Back and depth writes.

The transparent board render target stores accumulated RGB and **destination coverage**, not Unity's numerical framebuffer alpha:

- SrcAlpha/OneMinusSrcAlpha: original RGB blend, coverage union.
- One/OneMinusSrcAlpha: original premultiplied RGB blend, coverage union.
- SrcAlpha/One additive: source RGB is multiplied by source alpha once, then accumulated with zero destination attenuation.
- One/Zero opaque geometry: coverage one.

The final canvas composite is `accumulated RGB + background * (1 - coverage)`. It does not multiply accumulated RGB by alpha again. Ordinary 2D draw commands are premultiplied once and retain their prior result; the spatial texture is explicitly tagged as already accumulated. Source framebuffer alpha is deliberately not substituted for coverage.

QA uses the actual production shaders and compositor, not a test-only equivalent: 64 one/two-layer samples and 128 combinations with two different background colors match the CPU source RGB/coverage oracle within 3/255. Numerical source alpha differs in cases where coverage has different semantics. No RGBA-identical claim is made.

## Known compatibility boundaries

- The original gameplay camera, complete scene SH/main-light globals, Unity native particle random stream and native solver are unavailable. The fixed-board 15-degree projection, documented light inputs, deterministic Godot random stream and fixed-step particle integration are compatibility choices.
- Original GlowTransparent extra-pass equations are recovered, but scene target/routing/postprocessing are not. The selected ordinary materials have static `_GlowIntensity=0`, with no relevant recovered animation of that value, so the recovered extra-pass output is zero under those inputs. Other runtime overrides have not been exhaustively excluded; a visible difference from the missing scene routing has not been demonstrated.
- Missing mesh COLOR streams use a white compatibility default. This is recorded separately from preserved source vertex colors.
- Ordinary runtime branches are used. Golden, Diamond, elite/dragon-specific variants and card-specific battlecry effects are not claimed as covered.
- Existing board UI, BGM, v30 audio assets and rules remain the prior implementations. The old hand-written airborne shadow is suppressed while the source actor is active; board shadows and non-summon status indicators remain compatibility presentation.

## Verification artifacts

- `qa/v31/oracle/curve-result.json`: 2,714 independent raw-key samples.
- `qa/v31/oracle/route-stage-result.json`: 1,340 checks over both seats, cost boundaries and generated routes, at 30/60/144 Hz and large time steps.
- `qa/v31/gpu-blend/raw-shader-result.json`: actual GPU blend and final-background probes.
- `qa/v31/fixture/`: labeled synthetic Yeti fixtures, distinct from natural-match evidence.

See the final QA report for the frozen build's complete rule, input, GPU lifecycle and asset checks. Earlier failed fixture captures are retained as diagnostics rather than presented as successful results.

## Final ordinary-state bindings

The original NoDragon FSM action uses the default small outline texture for small Out, but replaces the medium Out material's texture with `AllyInHandSummon_Lrg`. Runtime binds that exact texture and its Repeat wrap mode; it does not retain the prefab's small Clamp texture.

Original HighlightState Setup starts disabled. The current accepted legal friendly-board drop explicitly carries the proven state8 `HighlightBlueOverBoard` condition into Out. Other entry points without an interaction state keep the highlight disabled rather than inheriting the prefab's green placeholder. The restored highlight uses the original mesh, static ordinary-card silhouette, original Flare texture and shader equation, queue 3050, source one-second intensity decline, one stable per-instance visual random seed, and the recovered global ShaderTime accumulator `deltaTime / 20`. The source supports other hand states; no claim is made that every possible original input/frame sequence selects state8.

Generated minion appearance uses an independent presentation flag. It does not alter the old game's synchronous token `ready`, `frozen`, `animating`, `hidden` or movement rules. Polymorph is explicitly separate: a same-entity Play→Play card-key replacement cancels the old visual owner and immediately displays the new Actor; it does not invoke standard Spawn26/31. Dedicated original Polymorph spell effects are not migrated, so the existing spell-impact presentation remains labeled compatibility. This also prevents an old summon tail from changing a replacement Actor.

Final focused particle checks cover 51 assertions and all ten actual ordinary ParticlePlay targets, with no unimplemented enabled source module in those targets. Unity-native solver/RNG and exact billboard rasterization remain the explicit compatibility boundaries. See `tests/v31_source_particles_notes.md` and `tests/v31_source_particles_result.json`.

The GPU blend suite now covers eight production transparent shader families: 64 source RGB/coverage cases and 128 final-background compositions. The original portrait shader has 32 additional GPU cases. Actual visible material use is captured per instance as `observed_materials`; the larger extracted asset inventory is not a count of migrated visible shaders.

The explicit enabled-action coverage inventory is `action_coverage.json`. It distinguishes direct source handlers, equivalent terminal cleanup, bounded ordinary branches, and any remaining reviewed compatibility gaps instead of equating parsed action fields with implemented behavior.

## Hidden Out continuation and crossfade

The hidden old Actor body hides at source 0.5 seconds while its spell remains visible (`ignoreSpells=true`). At 0.849999994 seconds only the finished callback starts the new In Actor. Old RedRays continue their simulation and rendering until their own particle lifetime or original old-Actor NONE cleanup at 2.099999994 seconds. The player records `out_actor_destroy` separately from `out_finished`.

Both hidden glow AnimationPlaythrough actions call original Animation.CrossFade with 0.30000001 seconds. Their original float curves and start times are preserved. The compatibility mixer linearly blends outgoing/incoming material values, uses the captured source pose for an unbound first clip, and thresholds renderer visibility at 0.5. Unity native normalization and unbound-property/reference-pose behavior are not recovered and are not claimed identical.

## Retained taunt indicator registration

The prior compatibility taunt shield remains a separate indicator; original taunt asset migration is not claimed. v31 replaces the flat legacy portrait with an inclined native Actor, so the old shield depth `.070` intersected its upper portrait. Revision 4 retains the old shield XY geometry, texture and visibility rules while registering its frontmost depth behind the recovered Actor’s conservatively transformed mesh bounds, with a `.001` numeric depth margin. No source mesh, source clip or gameplay rule is changed. Both seats, Voidwalker, Mirror Image, Senjin and a non-taunt control pass 97 independent GUI/depth checks (`qa/v31/taunt-final/result.json`).
