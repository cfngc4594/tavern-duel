# Actual GPU ten-pass verification

This is an independent audit specification, not a GPU result. Do not reuse the earlier CPU pass agreement as evidence that the GPU path passed. The audit worker starts no GPU. QA supplies real viewport readbacks from the integrated application.

## Capture contract

For each test case, freeze actor transforms, source shader clock, Seed, selected geometry and attachments. Arm all ten passes for the same generation. After `RenderingServer.frame_post_draw`, export each viewport texture with `get_image().save_png()`, without resizing, color conversion, alpha premultiplication, image flipping, or display screenshots. Capture the source surface inventory and final board image separately. Keep one directory and manifest per actor/case/generation.

Manifest top-level keys:

- `capture_kind`: exactly `gpu_viewport_readback` for actual GPU evidence. Never label a CPU/synthetic fixture this way.
- `renderer`: object containing engine, version, backend and device. Record the actual running version; static source audit below is Godot 4.6.3-stable GLES3.
- `case_id`, `capture_frame`, `base_size: [width,height]`.
- `passes`: ten rows, in order below. Each row has `name`, `file`, `size`, `frame`, `format`, `transparent_bg`, `use_hdr_2d`, `msaa_2d`, `filter`, `wrap`.
- Each scalar row also has `main_size`, `blend_size` (null for blur), `main_texel_size`, `blur_offset`.

`frame` identifies the completed generation, not merely the arbitrary frame at which an old disabled target was read. Also record `generation`, scheduled frame, completed frame and readback frame if they differ. Record source mesh/material keys, active/visible flags, scene transforms, shader hashes, pipeline serial, selected surface count, target count before/after and update count in additional fields.

Use true `GL_RGBA8` storage with `transparent_bg=true`, `use_hdr_2d=false`, no MSAA, no mips, bilinear/clamp numeric samplers and `blend_disabled`. Disable viewport transform/vertex pixel snapping. Red-channel storage is the R8 equivalence under test; other channels are not asserted to reproduce a native R8 texture. The final highlight shader reads only red.

| Stage | Name | Main | Blend | Size factor | Blur offset | Replacement |
|---|---|---|---|---|---|---|
| 1 | dark | | | float32(.3) | | .25 |
| 2 | grey | | | float32(.3) | | .5 |
| 3 | blend1 | dark | grey | float32(.3) | -1.25 | |
| 4 | light1 | | | .5 | | .75 |
| 5 | blend2 | blend1 | light1 | .5 | -1.25 | |
| 6 | light2 | | | 1 | | .75 |
| 7 | blend3 | blend2 | light2 | 1 | -1 | |
| 8 | blur | blend3 | | 1 | -1.5 | |
| 9 | clip | | | float32(.92) | | 1 |
| 10 | silhouette | blur | clip | 1 | float32(-.8) | |

Stage dimensions are source float32 multiplication followed by truncation, not rounding. At base256²: 76²,76²,76²,128²,128²,256²,256²,256²,235²,256².

## Independent numeric check

Run:

```
python v34_work/source_targeting/highlight_oracle/compare_gpu_pass_captures.py CAPTURE_DIR \
  --manifest CAPTURE_DIR/capture_manifest.json \
  --out v34_work/source_targeting/highlight_oracle/GPU_CASE_audit.json \
  --addressing-evidence v34_work/source_targeting/highlight_oracle/source_addressing_evidence.json \
  --artifacts v34_work/source_targeting/highlight_oracle/GPU_CASE_diffs
```

The tool reads raw red bytes and uses each stage's **actual captured inputs** to isolate scalar arithmetic/sampling faults from upstream geometry faults. It reports ideal and nearest-fixed8 bilinear references, with both clamp and repeat. It never evaluates or promotes the earlier Godot CPU precision model. Expected images and 32× absolute-difference images are optional.

Canonical constant red codes are dark64, grey128, light191 and clip255, over a zero background. A grey127 tie is within the cited D3D FLOAT→UNORM conversion tolerance and is reported separately rather than automatically called a color bug. Unexpected intermediate levels warrant investigation of blending, antialiasing, internal target precision or readback.

Scalar sampling uses output centers `(x+.5)/output_width`, `(y+.5)/output_height`. The four offsets always use reciprocal **main** dimensions, including both textures in MaskBlend. No extra half-pixel or Y adjustment is allowed without evidence. Canonical quantization occurs after every stage, not only at the end. Source MaskBlend scales each sum before subtracting; its DXBC has a multiply then MAD, so shader reassociation/FMA rounding remains a backend boundary.

Numeric reports distinguish exact pixels, one-byte differences and errors larger than one byte. One byte is a diagnostic band, not a justified universal acceptance threshold. A zero image matching zero proves little. Review nonzero shape, geometry membership, depth clipping and actual final on-board alignment independently. No local test can establish original-client pixel identity without original-client captures.

## Required case coverage

1. Default source minion and default source hero. Include one asymmetric real mesh/attachment to expose accidental flips; do not invent replacement silhouettes.
2. Eligible states26 and27 and idle1/invalid-hover2. Verify state material and final plane visibility separately from mask values.
3. Frozen/sleep/shield combinations supported by the current task, with dynamic eligible attachments and removal. Compare recorded contributing source surface keys, not only output appearance.
4. At least two distinct consecutive geometry generations. Capture both to detect previous-frame dependency errors, stale targets and caches. All ten targets must belong to each completed generation.
5. Repeated enter/leave and actor destruction. Record total retained viewport/pipeline resources; hidden actors must not trigger continuous UPDATE_ALWAYS work.
6. Final composition over two different colored backgrounds. This is separate from scalar target validation and must not imply original source-alpha output-merger identity.

## Godot 4.6.3 static review

Official files are preserved with URL/SHA256 in `godot_source/index.json`.

- `drivers/gles3/storage/texture_storage.cpp`, `_update_render_target_color`, lines2277–2296: HDR uses RGBA16F; transparent non-HDR uses RGBA8; **opaque non-HDR uses RGB10_A2**, even though its readback Image format says RGBA8. Therefore the transparent flag is part of the numeric evidence.
- `servers/rendering/renderer_viewport.cpp`, `_sort_active_viewports`, lines91–128: children precede parents and siblings retain activation order. Shader sampler dependencies are not used for ordering. `draw_viewports` marks UPDATE_ONCE/ALWAYS eligible, renders in sorted order, then disables ONCE. The draft's pass10→9→…→1 nested hierarchy therefore orders1→…→10 before their main parent viewport in the same draw, provided all are armed together.
- `drivers/gles3/rasterizer_canvas_gles3.cpp`, lines324–334: ordinary viewport canvas Y scale is +2/height. Its readback row order is consistent with canvas/texture UV; `texture_2d_get` does not introduce an image flip. `canvas.glsl` builds rectangle vertices at0/1, interpolates UV and has no hidden half-pixel shift when snapping is disabled.
- `rasterizer_canvas_gles3.cpp`, `reset_canvas` and blend-mode dispatch: canvas disables depth test and culling; `blend_disabled` disables GL_BLEND. CPU signed-Z clipping followed by canvas raster is the explicit replacement for original ZClip, not a hidden depth test.
- `canvas.glsl`: custom fragment COLOR is written directly to `frag_color`; unshaded bypasses modulation/lighting and no gamma post-conversion is present. Numeric samplers have no source_color annotation. An RGBA8 scalar target therefore quantizes numeric red rather than an ALBEDO color bridge.

The CPU projection uses real source triangles and clips near/far, but float precision and GPU raster edge rules remain engine compatibility. Subsequent exact-API Unity6000.3.10f1 Metal/Gamma probes independently establish final-target ClampUVW/Bilinear and temporary-target ClampUV. `source_addressing_evidence.json` records that scoped provenance; it does not claim original WindowsD3D runtime observation, temporary managed fields, or temporaryW. Source `_GlobalMipBias` is immaterial here because these targets have one mip level and nonmip linear sampling.
