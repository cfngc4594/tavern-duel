# v32.1 ordinary damage UI source findings

Visual source: 37.0.0.255130.254477. Rules remain 5834. Static original CIL and serialized bundle data, without original client execution. The normalized machine-readable report is `damage_runtime_semantics.json`; each section names exact methods and source artifacts.

## Correct implementation contract

- `Card.OnMetaData` displays metadata, not a second damage operation. Ordinary text is ASCII `-N`; crit is metadata type23, not a numerical threshold. Healing uses `+N`.
- Reuse one type7 DamageSplat per Actor. Attach it to `Actor/Spells` while preserving its original local transform. It follows that Actor during attack return. Repeated damage on the same actor cancels/restarts the existing display; it does not create a permanently stacked world-space float.
- Root scale starts at0, yields to Update, refreshes card components via `OnSpellFinished`, scales0→1 with original iTween easeOutElastic over1 second. Normal display waits2 seconds, then fades linearly over1 second and disables at3.10000002384 seconds after the yield. No vertical drift is in this coroutine.
- Hero and minion use separate original prefab GUIDs. Both have the original UberText setup, but zhCN localization replaces serialized Belwe_Outline with GLEI00M_t_Outline and actual fontSize80 (80.5 truncated by `conv.i4`). Initial characterSize is0.0779 and is then shrunk by exact ResizeToFit bounds logic. This is not Belwe70 or the older Belwe65 card-text capture.
- This is direct text (`m_RenderToTexture=0`): RichText1 + Outline1 + no bold + zhCN9 selects original `Hidden/TextOutline_Unlit`, Shader29 in globalgamemanagers, with UV outline offset3.089999914 / atlas dimensions. Do not substitute the card RTT outline shader.
- Fatal minion presentation preserves the type7 instance. Ordinary type5 Death Birth waits on a .5-second iTween completion, then hides the actor body RootObject recursively; its sibling Spells is not hidden. Another3-second wait leads to None and Actor destruction. The1-second Death animation is started but its Playthrough action immediately finishes, so the release is nominal3.5 seconds, not4 seconds. See `death_release_timing.json`.

## Explicit boundaries

Original client death processing is driven by a Play-to-Graveyard event. Static source alone does not determine its timestamp relative to the simulator's damage/contact/return callbacks. Mapping existing 5834 death-wave events to this presentation Birth is a documented compatibility adapter, not a reason to change rules or RNG.

Unity dynamic glyph/atlas generation and exact bounds require the already authorized offline Unity font probe. Full minion fragment/material death effects and hero end-game death are not implied by this limited damage restoration. No generic red flash or new sine-wave screen shake should be invented and labeled original.
