# Actual GPU readback audit

Input: eight actual capture manifests and80 raw PNG targets supplied by QA under `v34_work/TavernDuel/qa/v34/gold-second-capture`. Engine: Godot4.6.3-stable, gl_compatibility, Mesa25.0.7 llvmpipe with LLVM19.1.7. No renderer was launched by this audit worker.

## Established

- All8 manifests pass the dimension, uniform, generation and numeric target contract. All40 constant replacement targets contain exactly zero plus their canonical source level64/128/191/191/255; none is blank.
- Comparing the40 scalar targets against their actual captured input targets: blend1 is byte-exact against the ideal source-equation reference. Later stages mostly differ by one byte. Ideal blur has1–2 two-byte pixels per case; final silhouette is within one byte for every pixel in every case. These initial diagnostic values are preserved in `summary.json` and individual case reports.
- The two-byte discrepancies are explained by the actual backend's texture filtering. Official Mesa25.0.7 source uses8.8 fixed-point sample coordinates and rounds UNorm8 interpolation at each axis. An independent model of that sampler, shader float32 arithmetic and Mesa output conversion reproduces all32 blend1/blend2/blend3/blur captures **byte for byte**.
- For final MaskBlend, retaining source-left-associated sums leaves70–107 one-byte differences per65280-pixel capture. A balanced sum `(a+b)+(c+d)` for this shader reproduces all8 final targets byte for byte. This is evidence consistent with compiler addition reassociation, not a claim that generated shader IR was captured. The original real-valued equation and explicit separate .3 products are unchanged. No production shader was tuned to hide driver differences.
- Thus the recorded backend model (`uv_mode=divide`, `sum_order=mask_balanced`, `mask_fma=false`) reproduces all40 scalar output images exactly. This is a **backend compatibility result**, not original Unity/D3D instruction-level or official-client pixel identity.

## Generations

Both heroes and unit9 keep generation1 and identical10-pass pixels across the two cases, matching their unchanged geometry. Unit10 advances generation10→18 with attachments1→2 and changes all10 targets; final silhouette changes23190pixels, with maximum difference228. This demonstrates that the captured frozen attachment affects the generated silhouette rather than only changing a final material. Exact eligibility and gameplay behavior remain owned by the integration/QA surface inventory.

## Measured addressing and final-consumer correction

The current GPU path demonstrably implements clamp. Hero and frozen-attachment masks touch the texture edge, so repeat is materially different: individual stage discrepancies reach96/255 and final discrepancies reach92/255 for the hero. The earlier CPU fixture's all-black-border equivalence no longer applies.

`../source_rt_construction.json` records the exact final RenderTexture constructor and six-argument CommandBuffer.GetTemporaryRT overload for that measurement. Apply its measured temporary addressing to the scalar oracle and separately account for final-target addressing in the final highlight shader. A Mac backend observation must retain its platform scope.

Independent review of the parent's Unity6000.3.10f1/Metal/Gamma probes confirms final-target Clamp U/V/W and Bilinear, and directly sampled temporary-target **U and V Clamp**. All edge PNGs have red bytes51,51,204,204 at coordinates-.25,.25,.75,1.25, with the orthogonal coordinate held at.5. The exact source overloads were used without wrap assignments. Temporary W is unmeasured and unused for these2D textures; no temporary managed properties are inferred. See `../unity_rt_probe_audit.json` and `../unity_rt_v_probe_audit.json` for hashes and19 independent checks. `../source_addressing_evidence.json` is the selected oracle provenance.

This exposed and fixed a concrete final-consumer mismatch: the shared `native_summon_highlight.gdshader` declares `_MainTex` repeat_enable. The integration owner added a **dynamic-RT-only** clamp variant, leaving `_FlareTex` repeat and old baked-texture routes unchanged. Independent textual comparison confirms the only noncomment shader change is `_MainTex` addressing (`../dynamic_final_sampler_review.json`). Even UVs within0..1 can differ in the half-texel border region. Final on-board composition is still a separate QA check, not established by the internal mask targets.

All8 actual capture cases were rerun through the oracle with the measured addressing evidence explicitly attached. `measured_wrap_conclusion.json` confirms all final ideal-reference pixels remain within one byte under the now-evidence-backed clamp choice. `*_measured_wrap.json` preserves full input/evidence hashes and both reference sampling precisions.

## Reproducibility

- `../compare_gpu_pass_captures.py`: source-equation comparison and input contract checks.
- `../diagnose_llvmpipe_precision.py`: independently implemented Mesa sampler/rounding diagnostic. It does not launch GPU.
- `../mesa_source/index.json`: official exact-version source URLs and SHA256 hashes. Relevant functions: `lp_build_sample_image_linear`, `lp_build_lerp_simple`, `lp_build_lerp_2d`, `lp_build_unsigned_norm_to_float`, `lp_build_clamped_float_to_unsigned_norm`.
- `mesa_precision_conclusion.json`: concise40-stage exactness result for the backend model.
- `mesa_precision_summary.json` and individual `*_mesa_precision.json`: all tested precision variants, including the differences instead of hiding them.
- `generation_comparison.json`: all per-stage before/after differences.

Source geometry raster edges, final blending/alpha, hidden/invalid states and resource lifecycle are separate checks. No scalar result here proves those independent properties.
