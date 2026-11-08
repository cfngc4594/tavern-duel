# v32.1 injury presentation correction

## Confirmed delivered-v32 problem

The delivered video did contain handmade injury UI. `game._damage` recorded a fixed screen point, and `_draw_effects(true)` drew a procedural16-point yellow star plus manually scaled/drifting text. At ordinary minion contact, `native_combat_player` first moved the attacker to contact, then the unchanged simultaneous rule function dealt damage to defender and attacker. The two popup points were therefore both near the defender. The video showed attacker counterdamage appearing over the other minion after the attacker returned.

Fresh instrumentation of delivered v32 records24 checks across both seats: the two combat calls have different recipient IDs and each corresponding HP changes once; Fireball hero and lethal-minion targets each lose6 once; Fireblast loses1 once; Arcane Missiles has its intended three1-point calls and presentation adds no rule calls; a new game before contact cancels all late damage. This is bounded evidence for these reproductions, not an exhaustive proof of every possible game state. See `delivered_v32_diagnosis.json` and `qa/v32_1/diagnostic/damage-events.json`.

## New source-driven injury presentation

`native_damage_splat.gd` instantiates the distinct original minion and hero Actor spell7 prefabs. Mesh, texture, hierarchy, local transforms, material inputs and renderer state come from the same build37 assets. It does not generate a replacement star polygon.

The minion instance is a child of its actual Actor/Spells with identity parent transform. The original prefab root local offset is preserved. Every recipient has one cached instance. A second hit to that recipient cancels/restarts the same presentation rather than stacking multiple stale popups. Source text uses ASCII '-' or '+'. The source coroutine resets scale to0, yields to its next loop phase, calls OnSpellFinished for the actor's stats, scales root to1 with the recovered iTween easeOutElastic30 over1s, waits until2s, then fades linearly over1s and disables renderers at3.100000023841858s.

The rule function remains synchronous and unchanged. Arcane's already existing presentation snapshot retains damage events with the correct step; playback never executes `_damage` again. A heal event explicitly identifies its side and amount, so the compatibility bridge can replace its old float without editing the rules file. New-match reset clears cached injury nodes, events and dying actors. Both source and independent transmission mirrors are hidden synchronously before freeing a node or replacing a text mesh.

## Chinese text

The source prefab font is Belwe_Outline70, but the original zhCN FontDefinition replaces it with GLEI00M_t_Outline and modifier1.149999976. Float32 product80.5 is truncated by CIL conv.i4 to80. Character size remains7.79×.01 and original fit reduces it by.95 when needed. Both prefabs use the same text settings.

The final sampled glyph atlas and CharacterInfo are from the selected original GLEI font bytes in Unity6000.3.10f1, size80. They are not a screenshot or atlas captured from the running original game. Original font hhea metrics900/-124/6/1024 give line height80.46875 and MiddleCenter baseline-30.078125. The line height matches the native measured renderer bound within4.1e-7 fontpixel. Metadata preserves the engine version, font hash, bounds and importer settings.

The direct-render path is original Hidden/TextOutline_Unlit, globalgamemanagers Shader29: nine samples, four diagonal taps at±.600000024×outline, four axial taps, and center. Alpha is saturate(sum)×vertexAlpha×materialAlpha. RGB is centerAlpha×(vertexRGB×materialRGB-outlineRGB)+outlineRGB. The reused arithmetic was independently checked against this newly extracted DXBC and copied to the separate `native_damage_text_outline.gdshader`. This is not a card-text RTT path.

## Fatal damage

Logical death/removal, deathrattles and original sound scheduling are unchanged. A separate presentation-only dying actor follows the recovered minion death gate: hide its RootObject body at.5s, preserve the sibling Actor/Spells injury UI, and release the Actor at3.5s. The historical simulator's existing death-wave event is used as the start of this visual gate. Exact original server power-history timing relative to impact/return is not reconstructed.

The old handmade portrait fragments and dust are no longer emitted. Their60 cosmetic RNG draws per death remain in the same place so rule/RNG order is not silently changed. Original death dissolve/material transition, independent fragments and particles are not migrated in this correction. Hero end-game death is not assigned the minion gate.

## Other verified video defect

A complete upside-down glyph atlas was visible in delivered frame258. The independent lifecycle investigation reproduced a transmission mirror surviving its source geometry/ViewportTexture for a render frame. Combat effect retirement now synchronously hides source and matching transmission mirrors before RT disposal. The old/before and new/after GPU evidence is maintained by the dedicated lifecycle test.

## Remaining compatibility boundaries

- The existing fixed board registration/camera is retained. The current hero is still2D, so its distinct original injury prefab is attached to a registered hero proxy, not a recovered complete hero Actor.
- Unity font rasterization is sampled in a standalone matching-engine probe, not original-client execution.
- Native engine scheduling/transform and source-loop-yield phases are a documented Godot adapter.
- Only body-hide and actor-release gates are recovered for death; this correction does not claim full original death FX.
- No original-client login or runtime was used, and v32/v31/v30 production files are preserved.

## Current verification

- Fresh delivered-v32 rule/recipient audit:24/24.
- v32.1 final headless damage ownership/replay/heal/reset/elastic and actual donor identity test:34/34.
- Historical rules file SHA256 remains1009abe3889ae442f77da20162fa34fabbcb5884c5a1722746b8bd20b320d864.
- Actual GPU injury binding, fade, fatal timing and reset/atlas acceptance are separate. Do not interpret the CPU tests as pixel proof.

## Direct text blend boundary

The new text is source RT0, rendered directly into the C/T scene. Its RGB recurrence is C'=S*a+C*(1-a); the independent transmission recurrence is T'=T*(1-a). The opaque-board composite C+T*B outputs alpha1. That final RGB and alpha correspond to the source SrcAlpha/OneMinusSrcAlpha draw on an opaque board. The intermediate C framebuffer alpha is Godot coverage alpha, not original source alpha a*a+A*(1-a); it is never read by the composite. This is not a claim of equivalent intermediate transparent RGBA. Were this text later captured by an original transparent RTT, it would need the existing independent source-alpha capture path.

Fade changes the original TextColor vertex alpha once. Material _Color alpha stays1, so there is no accidental squared fade. The alpha-equation distinction remains explicit and will be checked against actual rendered fade samples.

## First-GPU defect and correction

The first actual image proved entity binding and text placement, but the yellow source background contributed no pixels. An independent fixed-scene GPU isolation measured original star-only == off exactly. Switching only the test material's culling to Front or Disabled restored the same15249 pixels. Disabling depth with Back still produced0 pixels. Original/untoggled/restored controls were identical. Thus neither source size, source texture alpha nor depth was the cause.

The production correction is confined to source damage background meshes under the existing negative-determinant source-to-board projection. It compensates Godot's negative-transform front-face flip with a CullFront backend shader variant while preserving source CullBack in metadata. Vertices, triangles, normals, texture, transforms, scale and depth test remain unchanged. All uniforms, including texture/ST, are saved before a shader swap and restored afterwards. Shader variants are shared within the presenter. The direct glyph geometry does not receive this separate background-mesh correction.

Evidence: `qa/v32_1/damage-contribution/result.json` and its original/off/cull/depth screenshots. This explanation does not turn the first incomplete screenshot into a complete result; the corrected production candidate requires re-verification.

## Source text queue correction

Once the yellow source mesh was visible, an actual minion image exposed a second omitted input: the text was drawn behind that background. The original UberText `m_RenderQueue=10` has two separate effects. `UberTextRendering.SetRenderQueueIncrement` sets Renderer.sortingOrder to10, and `IncrementRenderQueueMaterialProperty.DoApplyToMaterial` adds10 to the cached original material renderQueue with Clamp1..5000. Shader29 has the original Transparent tag, so the text's source tuple is(10,3010); the splat mesh remains(10,3000). The first presenter only applied the renderer sorting order. The correction restores the missing material increment and adds3010 to the current finite tuple domain. It does not move geometry or add an arbitrary depth/priority bias. Reapplication is based on the original queue, not cumulative.

Exact CIL and source tag evidence are in `source_semantics/damage_text_queue_semantics.json` and `damage_text_queue_property.cil.*`. The corrected candidate is being checked separately from the earlier incomplete image.

## Actual fade checks

The actual hero image contains both the original yellow background and the '-6' glyphs. Independent GPU isolation compared the original9-tap formula per glyph quad at alpha1 and.5:660 interior samples agree within1.45/255; the yellow background's7765 contribution pixels agree with half-alpha composition within1.5/255. Text-only single-layer pixels agree within1/255. Eight initially discrepant pixels are overlapping glyph quads and follow successive source-alpha blends rather than a single-layer linear interpolation. One MSAA-edge sample remains separately identified rather than claiming every edge pixel is exact. Untoggled controls match exactly. This validates that the fade is applied once, but does not replace the minion combined-layer recheck or fatal/reset/replay acceptance.

Evidence: `qa/v32_1/damage-fade/pixel-result.json` and its fixed-age original/text/star/control captures.

The actual hero component has m_RenderQueue1, not10. Its correct tuple is(1,3001). The initial3010-only domain caused a reported runtime error in the first hero sample; that failed recording is retained. The corrected setup scans every original UberText component and registers each sortingOrder and Clamp(3000+increment) before creating any materials, covering both original prefabs rather than hardcoding the minion tuple. Glyph/font settings are shared, but renderer queues are not.

## Final scoped acceptance

The corrected production candidate completed the original four comparison cases:28/28 checks, 476 actual rendered frames, no orphan transmission frames, no reported engine errors, and unchanged production hashes across the recording. The separate remaining10-case acceptance completed72/72 checks and1096 actual rendered frames, no orphan transmission frames and no reported engine errors. This covered the requested injury correction rather than rerunning or claiming the entire earlier50-card suite. See `qa/v32_1/final-comparison-2/result.json` and `qa/v32_1/final-remaining/result.json`. The minion screenshot now shows both original yellow backgrounds and both correctly bound '-4'/'-3' glyphs after return.

After both GUI processes naturally exited, one audit-only expression was corrected: retaliation's event donor is the combat-pair entity other than the recipient, rather than always the original attacker. Exact before/after source hashes and the one-line diff are in `audit_donor_only.json` and `audit_donor_only.patch`. The source field is copied into the audit event but never read by rendering, rules or sound. Both seat directions were independently asserted; the final headless model test is34/34. No material, geometry, transform, timing, target, amount, HP or rule expression changed after the recorded GUI candidate.

The final original-asset closure contains130 objects, zero unresolved/error records and13 verified original container identities. The unique original minion/hero font queue domains were separately built and checked13/13 in `qa/v32_1/diagnostic/damage-queue-domain.json`. `candidate_sha256.json` identifies the final production scripts, shader and key asset inputs.
