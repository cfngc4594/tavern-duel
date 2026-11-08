# Original targeting and actor eligibility source pack

Build: 37.0.0.255130.254477, static official-client evidence only. Historical5834 rules are not changed. No official client login/execution, no Mac/Windows installation, and no production project files were edited by this worker.

## Source bindings and interaction

- `assets/manifest.json`: 51 original objects for default target arrow/bullseye, links and damage indicator. All original roots were resolved by literal CIL GUID and verified catalog/install records, not inferred name similarity.
- `assets/data/all_targeting_source_provenance.json`: eight original containers match the official install MD5; recovered shader supplement includes 68 source objects. Localized font uses the separately retained exact-build FontTable/font source evidence.
- `assets/data/targeting_runtime.json`: constants, geometry formulas, phase, visibility, origin, static/remote, commit/cancel behavior and caller flags.
- `assets/data/targeting_math_oracle.json`: 18 independent geometry examples.
- `assets/data/material_render_bindings.json`: original properties, shader pass state, texture filtering/wrap/mips/ST; no unspecified shader fallback.
- `assets/data/mesh_color_channels.json`: original vertex attribute formats, including highlight plane and hero. Plane pPlane2 has UNorm8 COLOR and MUST divide raw0/255 by255.
- `targeting_all.cil.*`, `targeting_coroutines.cil.*`, `targeting_state.cil.*`, `targeting_card_text.cil.*`: original method bodies. Source2D reticle projection into current board remains engine compatibility.

Default arrow has15 allocated link meshes, spacing float32(1.2), parabola height1.5. The endpoint follows input-plane hit position rather than character-center snapping. A valid hovered entity enables only the bullseye renderer; it does not hide the tip. Invalid commit returns before destroying arrow/sending an option. Valid commit destroys with cancellation=false; cancellation destroys with cancellation=true and notifies the source card. No default red/green arrow recoloring was found. Phase persists across create/destroy.

## Original actor eligibility

- `assets/data/eligibility_bindings.json`: original hero/minion HighlightState components, all serialized state materials/offsets, original plane mesh and hierarchy,10-pass scalar schedule, exact selection gates and loader guidance.
- `assets/data/eligibility_surface_bindings.json`: current live minion surfaces, full hero surfaces, and19 attached status renderer routes. Only original nonempty material `Highlight` tags qualify, not name or side heuristics.
- `eligibility_card.cil.*`: Card.UpdateActorState/DoOptionHighlight/DoOptionTargetHighlight.
- `targeting_silhouette.cil.*`: complete HighlightRender.
- `shader_time_runtime.cil.*`: recovered original ShaderTime producer, reused from verified v31 evidence. Enabled time accumulates deltaTime/20;65535 single-wrap. Disabled value1. Do not use raw seconds for `_ShaderTime`.
- `highlight_resource_manifest.json`, `highlight_builtin_resources.json`, `highlight_shader_render_states.json` under assets/data plus decoded DXBC directories: all original mask/replacement shader resources.

Target mode is exclusive of normal option mode. Legal targets use26, or27 when hovered. Invalid targets fall through to ordinary hover2 or idle1; they do not regain ready6/7 while aiming. A selected attacker that cannot target itself is therefore ordinary hover/idle, not still green. In normal option mode valid ordinary playable actors use6/hover7. Source state0/1 and source hidden29 disable the plane. The current original planes have no FSM, so no invented fade.

The source dynamic mask includes enabled MeshRenderers under the entire actor root, per material/submesh tag, including attached frozen/taunt meshes. The main minion portrait/frame both qualify. Attack/health gems do not. Eligible attachments are Frozen_mesh GO8307728421905355948, Taunt_Shield_mesh GO2211766007062841913, and FrozenHeroShell GO5932701138785887379. Shader texture alpha is ignored by the constant replacement pass.

Hero source is original_endgame_v33 Card_Play_Hero root GO-2507336562026496370. Its main Mesh GO-5325575736001315186 uses mesh168593982122964233 and two eligible materials. Hero image alpha or a generated ellipse is not a source mask. Mapping this real source model to the existing legacy board hero image remains a separately declared layout/actor correspondence boundary.

## Adapter drafts

`adapter_draft/native_target_highlight.gd` is the CPU reference adapter, not a claim of real-time parity. The source actual base minion fixture was256x256 with17189 nonzero pixels, hollow center and max228; first mask took about1.5s. It caches stable masks, but must not be described as an efficient per-frame animated implementation.

`adapter_draft/native_target_highlight_gpu.gd` inherits the same API and replaces pixel loops with10 GPU targets. Four source-equation shaders are in `adapter_draft/shaders/`.

- `setup(game, source_assets, metadata_base)`
- `set_actor_state(id, actor, kind, state, attachments=[])`
- `hide(id)`, `hide_all()`, `advance(delta, shared_shader_time=-1)`, `snapshot()`
- `capture_gpu_passes(directory)` waits for frame_post_draw and saves raw targets without resize or gamma changes.

Use a NativeCombatAssets loader with original_summon_v31 base for the plane and all current minion/hero2/6/7/26/27 material dependencies. Merge the supplied mesh-color metadata before loading the plane. Metadata base is original_targeting_v34. Hero actor itself uses original_endgame_v33. Status attachments are current instance dictionaries with `.renderers`; their actual world transforms are normalized to the owning source actor root.

GPU pipeline design:

1. Five constant source-triangle rasters use source orthographic view/near/far. CPU does only vertex transformation and signed-Z triangle clipping; GPU canvas rasterizes. There is no generated ellipse, texture-alpha mask or CPU pixel filter.
2. Five source postprocess passes run exact diagonal sampling/max/mask equations. Last MaskBlend preserves multiply/subtract ordering and documents GPU FMA precision.
3. Every viewport has transparent_bg=true, use_hdr_2d=false, MSAA disabled, no mips. This matters: official Godot GLES3 chooses GL_RGBA8 only for the transparent target; opaque uses RGB10_A2. Red is numeric UNorm8, substituting source R8. Auxiliary RGBA alpha0-clear/1-draw differs from implicit R8 alpha1, but no mask consumer reads it.
4. Viewports form a nested chain10→9→…→1. Official Godot children-before-parent sorting yields1→10 before the main scene in the same frame; sampler references alone would not guarantee this.
5. All targets arm UPDATE_ONCE together on source geometry/visibility/transform changes, then stop while static. Pipelines are retained per actor and freed after actor destruction.
6. QA can read `gpu_pipelines[id].textures` with dark/grey/blend1/light1/blend2/light2/blend3/blur/clip/silhouette, `.passes` viewports/material/spec, `.source_shape` matrices/geometry, and completed_generation/completed_frame.

This worker performed headless GDScript parsing only and did not launch a renderer. Production integration and serialized GPU QA belong to their assigned workers; supplied actual capture results are summarized below.

## Independent audit

`highlight_oracle/` is the independent auditor's evidence:
-6144 source-DXBC numeric cases and1800 sampler cases passed.
-Actual CPU postprocess captures match the independently modeled Godot CPU precision byte-for-byte for all five outputs. Ideal double reference can differ by1UNorm8 code.
-Source default minion/hero eligibility, matrices, UV orientation, signed-Z clipping and current positive-uniform scale boundary were checked.
-Godot official source confirms RGBA8 selection, numeric R8 sampling, canvas output and viewport ordering.

Remaining native boundaries: GPU triangle top-left coverage, CPU64→Vector2f projection precision, source RT wrap across unmeasured backends (same-constructor Unity6000.3.10f1 Metal/Gamma probes verify final Clamp U/V/W and temporary U/V; temporary W is unmeasured and unused in this2D path), backend float/FMA/UNorm8 quantization, hero correspondence to the legacy image, live attached-state refresh and retained-pipeline lifecycle. The actual postprocess comparison is summarized below; final board compositing and lifecycle remain distinct QA gates.

## Archer text

`assets/data/target_damage_text_zhcn.json` contains the full original UberText, transform inheritance, exact global/localized FontTable definition, font hash, runtime configuration and one-time native probe request. The only nonempty default target-arrow text in the current27-card pool is CS2_189 `造成1点伤害。`.

Runtime font is GLEI00M_t_Outline, NOT BlizzardGlobal35: serialized Belwe_Outline resolves through exact zhCN FontDefinition;35×1.149999976 truncates to40. Character size is0.02449999935925007 after serialized2.450000047683716×font modifier1×float32(.01), without resize/grow. Normal style, MiddleCenter anchor4, Center alignment1, lineSpacing1, wordWraptrue, width1.1799999475,height.1700000018, direct TextMesh, outline2.70000004768 black, shadowfalse, renderer order1/material queue3001. Native glyph sampling and integration QA are tracked separately; this source manifest alone does not establish font raster pixel equivalence.

## Cancellation and fixed error audio

`audio/runtime_manifest.json` is schema1 with two original cues, two SoundDefs, two unmodified decoded clips, verified source object identities and official cached bundle hashes. `audio/verification.json` verifies both WAV hashes, frame counts and formats. Original FSBs are retained.

- `targeting/cancel`: original `CancelTargetMode` enqueues `CancelAttack` before `DestroyFriendlyTargetArrow(true)` and returning any held battlecry card. It is shared by ordinary attack/spell/battlecry cancel. The source guard requires target mode or prior pending-choice mode; current-pool inputs do not hit its LettuceAbility suppression. It is not inside arrow cleanup and must not play on valid commit, invalid attempt or every `clear()`. Gain1, pitch randomized [.800000011920929,1], FX1, 48kHz mono, .4651666667s. No authored delay, no instance limit, no arrow-owned stop; original asynchronous asset load is not a fixed timing interval.
- `targeting/display_error`: exact `GameplayErrorManager.DisplayMessage` cue `UI_no_can_do` prefab GUID7b1a22774f818544387c0f2ca4fea02c, SoundDef cab69:-4755436395352159483, clip GUID9c034c03dde8fd8458679423cb554253. AudioSource gain1 times SoundDef fixed .699999988079071, pitch1, FX1, 44.1kHz mono, .4325623583s, no authored delay, no instance limit. Original enqueue follows `GameplayErrorCloud.ShowMessage`. Use alongside current local nonempty error toast only as a disclosed compatible trigger, replacing the synthetic beep. It does not restore source error selection, original toast UI or hero VO.

`assets/data/invalid_target_presentation_boundary.json` records the bounded source chain and20 relevant conditional source cases. `DoNetworkOptionTarget` reads `SubOption.GetErrorForTarget` and nullable `GetErrorParamForTarget` from matching `TargetOption.PlayErrorInfo`; absent ID returns INVALID(-1)/null. Those methods do not recalculate rules. The selected network option's upstream packet deserializer was outside this bounded trace.

`DisplayPlayError` can trigger a hero EmoteEntry, then resolves original text and calls DisplayMessage only if text is nonempty. Error15 returns before all of that. Taunt has a separate conditional hero-voice gate and `ShowEnemyTauntCharacters`. Actual hero ERROR_* EmoteEntry/voice closure is not exported in this task, nor is original GameplayErrorCloud/font/effect closure. Current local booleans and Chinese reason strings do not provide modern errorParam, exact enum priority or hero voice selection. No historical5834 rule changes or guessed modern enum mapping were introduced.

## Native RT sampling probe update

The parent supplied a real Unity6000.3.10f1 / Apple M3 / Metal / Gamma probe using the source final RenderTexture constructor and six-argument CommandBuffer temporary-target overload, with no wrap setter. The independent auditor verified its scripts, managed properties and raw edge samples in `highlight_oracle/unity_rt_probe_audit.json` and `highlight_oracle/unity_rt_v_probe_audit.json`: final texture is Clamp U/V/W, Bilinear R8_UNorm, sRGBfalse, AA1, no mips; temporary U and V edge samples also clamp. Temporary W is unmeasured and unused for these2D textures, and no temporary managed properties are inferred. This closes those sampler defaults for the measured Unity/Metal environment, not original Windows D3D pixel identity.

The adapter now uses a dedicated `native_target_dynamic_highlight.gdshader` for the final dynamic silhouette: only `_MainTex` is clamp; authored `_FlareTex` remains Repeat, formulas unchanged. The base script preserves every loaded original material uniform when swapping this route. It does not alter static baked-mask summon shaders. GPU draft includes diagnostic source_key/surface_index and a generation guard so inactive pipelines do not inherit another actor's completed-frame number. The ten-pass formulas and geometry are unchanged.

Independent actual GPU capture status: `highlight_oracle/gold-second-capture/RESULT.md` audits8 supplied manifests/80 targets.40 constant rasters have exact canonical scalar levels; final source-equation ideal comparison is within one UNorm8 byte across every pixel. Independently modeling Mesa25.0.7 llvmpipe fixed-point filtering/rounding reproduces all40 scalar outputs byte-for-byte, with MaskBlend balanced addition consistent with compiler reassociation (generated shader IR was not captured). No production formula was tuned to hide differences. Attachment generation changes demonstrate live silhouette change. These are Godot/Mesa compatibility results; they do not establish original Unity/D3D pixels, source raster edge rules or final board compositing.

## Final local transform registration

`adapter_draft/native_target_highlight.gd` and `native_target_highlight_gpu.gd` now match the final reviewed production hashes below. `adapter_draft/native_highlight.gd` is the integration wrapper copy, included to make attachment registration explicit. `assets/data/local_transform_bridge.json` records the narrow semantic review and exact hashes.

Mask snapshots now compose source local transforms up to their common ancestor, instead of `inverse(actor.global_transform) * mesh.global_transform`. The latter introduced float32 presentation-scale roundtrip noise and could flip an otherwise stable square texture between256×255/255×256/256×256 before the unchanged source integer truncation. The new method removes common presentation transforms directly; no source bounds, aspect ratio, integer truncation or ten-pass equation was adjusted.

Minion effects explicitly register their projection to the live actor root each frame; their local mesh-to-projection chain therefore maps to actor space with an identity bridge. Hero effects register before the hero source root's authored1.11 local scale; the bridge is the inverse hero root local transform. Both hero branches share the same screen-to-world position plus shake and15-degree0.78×0.9 basis. Original effect-root and child animation transforms remain included. Only attachments carrying explicit anchor metadata use this bridge; ordinary attachments retain common-ancestor mapping. Status synchronization must run before highlight synchronization, as it does in the reviewed game update order.

This review applies to the current ordinary Node3D source hierarchy, not future top_level renderers or disconnected/special transform hierarchies. The source worker did not run Godot for this patch; actual final candidate QA is separately recorded.
