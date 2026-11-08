# Verified backend state gaps

Project uses gl_compatibility. Godot 4.6 official source:
https://raw.githubusercontent.com/godotengine/godot/4.6/drivers/gles3/rasterizer_scene_gles3.cpp

Lines2950–2955: transparent-bg blend_mix RGB uses SRC_ALPHA/ONE_MINUS_SRC_ALPHA; alpha uses ONE/ONE_MINUS_SRC_ALPHA. Original Unity text pass uses SRC_ALPHA/ONE_MINUS_SRC_ALPHA for alpha too. Thus original alpha_out=a*a+dst_alpha*(1-a), Godot alpha_out=a+dst_alpha*(1-a). Squaring shader ALPHA alone is wrong: RGB weight and destination factor would change.

Exact next implementation needs independently configurable blend state: custom RenderingDevice pipeline (different backend), dedicated GLES render-backend blend mode, or explicit per-pass destination-aware compositing. This is a concrete unimplemented rendering step, not a missing screenshot issue. Current shader algebra ports do not establish blend-state parity.

Lines2988–3003: per-instance mirror reverses cull direction. Current root z=-1 yields negative model determinant. Independent GUI fixture demonstrates source indices+cull_back loses both front titles while showing backs. Test v25_cull_probe.gd isolates only title meshes and duplicates shader/geometry at runtime; no production file edits. Reversed index winding is the next validated variant.

Resolved cull gap: runtime swapped name triangle indices1/2 + cull_back exactly preserves front coverage and alpha sum for both cards, while back coverage becomes0. Production applies this conversion ONLY to imported name meshes and AA shader; other card meshes unaffected. Probe result/comparison and pre-change fixture archived here. Exact running-version Godot4.6.3-stable source also archived; same blend state verified at lines2647/3268.
