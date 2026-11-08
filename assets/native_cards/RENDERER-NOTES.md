# Native card renderer integration

Source geometry, hierarchy, UV, title curve mesh, single-race plate, zhCN GLEI00M_t_Outline title font, BlizzardGlobal body font and Belwe_Outline numbers originate from client 37.0.0.255130.254477. Original static catalog/font binding and class switcher GUID mapping are retained in evidence. Rules remain the existing build5834 prototype rules.

`NativeCardRenderer` creates 328x484 transparent card views and actual name RTT textures applied to original curved meshes. No per-character hand-drawn arc is used. Atlas replacement follows original Actor: minion front slot0 only; spell front slot0 and portrait-frame slot0, preserving portrait slot1. Race plate is enabled only when a single race string exists.

Godot font rasterization, outlines and fit-to-source text boxes remain explicit compatibility adaptations. Body text uses the existing gameplay description line breaks, preserving wording. Camera fitting uses calculated transformed source bounds with ~5% padding, not modified mesh coordinates. Original geometry Z is reflected consistently for engine handedness. Full UberText glyph-atlas/quad geometry, SH lighting, color space and pixel parity are not claimed.

Source gem shader uses its recovered opaque pass and MainTex alpha as scrolling mask (not opacity), with the original LightingBlend=0 material parameters. Deterministic source time is 0 for baked card views. A final SubViewport is frozen only after 3 frames and a rendered frame; dynamic cost changes re-render the affected view. Reduced/increased cost colors follow original desktop Actor green/red rules. Board-unit damage/stat rendering remains the existing gameplay overlay and is not baked into hand-card textures.

## Explicit Coin fallback
The original CardColorSwitcher neutral-spell GUID `583499402f221f24792040779fa00734` was not found in the admitted original global texture0/1/2/3 containers. `GAME_005` therefore retains the original generic spell prefab material (blue) as an explicit compatibility fallback, rather than claiming its color/frame is the exact neutral card. `get_audit().compatibility_fallbacks` records the card, requested frame, actual fallback and missing GUID; other missing class frames remain `unresolved_frames` errors. All collectible mage/warlock and neutral minion class atlases are exact GUID-matched original resources.

Frame transparency follows recovered `Custom/Card/UnlitTextureDualClass` original pass state (Opaque, Cull Off), not PNG alpha. This is essential: enabling alpha blending exposes the card-back mesh through class atlas mask channels and produces an incorrect gold/blue border. The original state dump is retained in `evidence/frame_shader_original_state.txt`; complete compiled shader equations are not claimed recovered.
