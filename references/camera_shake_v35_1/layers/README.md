# Original camera and board-UI layer evidence

Limited source-only export for V35 death screen-shake diagnosis. MOP board recovery remains paused.

- board_cameras_source.json: complete original BoardCameras prefab hierarchy, all components, script metadata, PPtrs, source identities and SHA-256. Three GameObjects; one Camera; root transform is identity with no parent.
- SUMMARY.json: camera mask and named layer mapping, exact object keys, selected mana/opponent hidden hand/deck/end-turn subtree layer summaries and renderer paths. Every serialized layer in these selected groups is included in Main Camera culling mask.
- hand_mana_layer_source.json and hand_deck_endturn_layer_source.json: original GameObject hierarchy and selected component fields from the already cached official essential bundle.
- existing_hero_shake_sources.json: pointers into the existing V33 original manifest for hero-death and endgame shake FSM actions.

Main Camera cullingMask is 16367875 / 0xf9c103. CameraShakeMgr is on Main Camera. ScreenEffectsRender refers to that same Camera. URP camera stack is empty in this prefab. These serialized facts do not establish that the entire game has no separate GUI camera, nor prove absence of runtime layer overrides. Combine with managed-call evidence.

All work was offline local reading/export from existing client bundles. No MOP missing references were downloaded, no GPU or game execution was used, and no production v35 files were changed.

## Additional death-shake UI evidence

ADDITIONAL_UI_SUMMARY.json covers history, turn-start banner and actual desktop player name banner. History prefabs use layers 0/8/14/19, all in Main Camera mask; TurnIndicator GUID eb380f78748e2b9479aae6aff3d09d5f has seven nodes all on layer 14. Desktop NameBanner GUID f579c831653574d4da0437a5fcf0d58f is different: its source-rendering GameObjects are on BackgroundUI layer 13, excluded from Main Camera mask. NameBanner.UpdateAnchor runtime uses OverlayUI according to the separate CIL investigation. Card title NameBanner_mesh and friends-list PlayerNameText were excluded as unrelated identities.
