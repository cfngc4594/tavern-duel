# v35 ordinary minion death source recovery

Fixed official client build **37.0.0.255130.254477**, current historic-5834 Mage/Warlock pool. Read-only original-client inspection; no original client execution/login and no user-computer access. Production files were not edited by this recovery worker.

## Ready to consume

- `assets/manifest.json`: **208 original objects**, zero unresolved exported PPtr references and zero export errors. Shared body death, independent DeathSplat, 13 character death-sound prefabs, 13 dynamic card portraits, 11 particle systems, 5 meshes, 8 materials, 10 shaders, 21 textures and the original actor death AnimationClip.
- `runtime_routes.json`: two source-owned FSM routes, including every action, enabled flag, variable, resolved reference and frame-quantized event-entry schedule. All object IDs here are strings. FsmTexture type33 is decoded from the original `fsmObjectParams`, not guessed from a placeholder.
- `actor_spell_bindings.json`: actual Actor → SpellTable → type5/type10 entries and raw-object hashes.
- `card_pool_bindings.json`: all30 exact CardDefs. The13 minion entities are11 collectibles plus Sheep and Mirror Image. Every normal custom-death path and every DeathEffectDef visual path is empty; all13 minions use the common body death. Their portrait and character-death audio differ.
- `particle_inventory.json`: all source particle fields, enabled modules, renderer initial flags, exact hierarchy/transforms, material references and auxiliary components.
- `material_bindings.json`, `mesh_color_channels.json`: exact source material/shader binding and original vertex-color channel metadata. All5 included meshes have no original vertex-color channel.
- `audio/event_bindings.json`: independent shared-body and per-character sound events with exact source objects. `audio/clips_provenance.json` describes19 complete decoded clips and the19 retained original FSB payloads. All19 WAV hashes match the already-used v34 original-audio files, so this recovery requires no duplicate playback.
- `assets/data/source_bundle_provenance.json`, `binding_source_provenance.json`, `audio/source_bundle_provenance.json`: exact-build install MD5, actual MD5 and SHA256 source checks.
- `recovery_validation.json`: reference/file/mesh/texture/audio verification. `DELIVERABLE_HASHES.json` hashes the deliverables.

## Original body sequence

Card_Play_Ally’s SpellTable type5 names GUID `0d12844e0f5834ae084290dc98ded3af`. Ordinary death begins at the card’s play-to-graveyard presentation, not automatically at the arithmetic transition to0 health.

1. Birth State initializes Actor/RootObject/RootObjectMesh, obtains the current static card portrait, assigns original `GenFX_Card_InPlay-AllyPortrait_Death` to material slot0 and assigns the portrait to `_MainTex`. The baked placeholder texture is not the runtime card image.
2. Birth Animate starts original1-second `AllyInPlay_Death` material curves, shared death audio, and0.5-second X/Z shake. AnimationPlaythroughAction and AudioPlaythroughAction finish immediately; **the shake gates this state at0.5 seconds**, not the clip/audio duration.
3. At0.5 seconds, hide only RootObject renderers, recursively show the active fragment subtree, and play its particles including children. Four debris mesh systems, gas, a rock emitter and their subemitters are retained.
4. The move target is **FX_CollisionPlaneLocation1**, not the particle root or a synthetic rigid fragment group. It waits1.5 seconds from this state, then moves localY0→−1 over1.5 seconds with source ease21. Therefore the plane starts moving at total2.0 seconds. Preserve collisions and the real particle lifecycle; do not replace this with direct uniform sinking of all fragments.
5. A3-second Wait exits at total3.5 seconds, disables the death-container ProjectedShadow, and enters None. Original release callbacks destroy the Actor after the source state change.

The state clock is scaled game time and zero-time actions/transitions are quantized by engine updates. Current simulator death-wave timing remains an explicit adapter to original server presentation, not proof of identical network-event timing. Full managed-method proof is owned by sibling `source_death_flow/`; previous exact timing evidence is `v32_work/source_code/death_release_timing.json`.

## Important component details

- Shared body material uses **Custom/Card/UnlitDesat**, not an invented dissolve/cutout. Its original `_Transistion` spelling, `_ValueRange`, `_Color` values and actor material curves are preserved. Original compiled shader equation recovery/adapters are in sibling `source_death_shaders/`.
- Normal non-premium debris uses `GenFX_Card_InPlay-AllyFrameDebris`. The gold material is merely a serialized PremiumMaterialSwitcher dependency. Current non-premium semantics retain the renderer’s original material array.
- Four debris CollisionModules reference the same plane Transform. SubEmitter type2 is **Death**, not Collision. Collision killing a particle may indirectly trigger its death emitter; these are different events. The exact engine enums are in `source_death_flow/particle_enums.json`.
- The body fragment systems serialize `moveWithTransform=0`; use this original serialization with the managed/native bridge evidence rather than assuming that field is directly the public SimulationSpace enum. Culling is AlwaysSimulate3 except gas PauseAndCatchup1. All11 `playOnAwake` values are false.
- FX_RockEmitter’s renderer initially has `m_Enabled=false`, but its GameObject and ancestors are active. At0.5 seconds SetVisibilityRecursiveAction(true) unconditionally sets all active-descendant renderers enabled, including that renderer; `resetOnExit=false`. Its Default-Particle shader is genuinely reachable.
- The Default-Particle texture has **7 original mip levels**. `assets/mips/Default-Particle__5681093337556782924.rgba8-mips` retains every original RGBA32 level, vertically flipped once to match decoded PNG orientation. No regenerated mips. The old loader’s hardcoded material-CAB key differs from this prefab-CAB copy; consume `files.rgba8_mips` or add the exact death texture key.
- Death root and its collision plane have identity local transforms. Standard type5 activation does not assign Spell.Source; SOURCE_AUTO placement therefore retains the original prefab local transform. Custom-death source assignment is a separate out-of-scope branch.
- Source ProjectedShadow parameters are preserved, but texture capture and Unity-native shadow rendering are separate compatibility work. This asset export is not evidence of visual parity for shadows.

## Audio and separate effects

Common death-body sound selects one of six equally weighted Minion_Death clips, random pitch approximately0.9–1.1 and volume1. This event is separate from each card’s character-death sound. There are13 character death files: **5 resolved through the zhCN voice catalog** (CS2_179, CS2_189, CS2_200, CS2_065, EX1_301) and **8 global effects/vocalizations**, including Yeti, Sheep and Mirror Image. They must not all be called Chinese spoken voice. Original categories and zero CardSoundSpell delay are in the event binding file.

DeathSplat type10 is an independent skull indicator with its own Idle state, source mesh/texture/material and sorting-order component. Exporting this referenced root does not mean ordinary body death should automatically enable it. Use the actual Card caller condition from the flow audit. Likewise, normal Polymorph reuses its Actor and clears keywords through their own transitions; do not activate the ordinary death body or death audio for a transform.

## Scope and remaining boundaries

Asset and serialized-action recovery is complete for these selected roots and current CardDefs. Script ancestry/global configurations are intentionally not recursively exported; exact relevant managed methods are recovered separately. Referenced shaders are retained as original binary-program data, not executable Godot code. Native Unity particle RNG, collision/integration, sub-emission, culling and projected-shadow rendering remain compatibility boundaries unless the implementation and QA explicitly close them. No original-client pixel comparison or GPU test was performed by this asset-recovery worker.

Two verified same-build MaterialService assemblies were downloaded only for static managed-code inspection into `managed/`; both Mac and Windows install provenance accompanies them. They were not executed.
