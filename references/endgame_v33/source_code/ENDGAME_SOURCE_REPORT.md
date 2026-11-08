# v33 hero death and terminal presentation source evidence

Scope: static inspection of original visual build 37.0.0.255130.254477, not execution of the original client. Rules build5834 is unchanged. Assembly-CSharp.dll SHA256 7f81d2ab2277958dea4351c41812921a00ee263a6a7abf1a5cfb4eb0794f26e5. dnfile/dncil fallback was used; this is not a claim that REA decompiled the complete assembly. Official same-build Blizzard.T5.Core.dll was additionally fetched through the existing content/encoding archive chain; its local provenance accompanies managed/Blizzard.T5.Core.dll.

## Deliverables

- runtime_routes.json: six original FSM routes, full original parameters, GUID-resolved target/clip keys, event schedules and timing qualifications. Includes the three actual terminal hero spells, both screen FSMs, and type5 as evidence only.
- action_coverage_ledger.json: all131 enabled actions in these six FSMs, structural reachability, references and excluded branches. Seven reward/account closure FSMs are excluded explicitly. This is NOT a claim of full production implementation or Mono/render coverage.
- two_scoop_animate_all.json:18 exact C#-driven iTweens (six defeat/tie,12victory), source token and IL. The at field already includes the coroutine .25s and tween delay; params also preserve original delay, so do not add twice.
- itween_ease_enum.json: original enum read directly from Blizzard.T5.iTween.dll. In particular24=easeOutBounce,27=easeOutBack,30=easeOutElastic,16=easeOutExpo,21=linear.
- hero_endgame_initial/full/dispatch/entrypoints.cil.*: original UI classes, full GameEntity, coroutines and entrypoints.
- endgame_actions.cil.*: portrait assignment, state markers, tag-range action, pet query.
- endgame_custom_actions.cil.*: RandomWaitAction and SetTimeScaleAction.
- endgame_playmaker_time.cil.* and endgame_timescale_manager.cil.*: timeScale semantics.
- endgame_death_finish.cil.* and callers_06012d54_06014961_06012d53.json: exact deathVO entry and finish semantics.
- endgame_power_order.cil.* and callers_06005621_04004365_0400365b.json: terminal tag dispatch and task queue.

## Actual terminal dispatch, not generic hero type5

GameState.PreprocessTagChange0600561c handles Player PLAYSTATE17; GameUtils.IsGameOverTag selects the terminal result and calls GameState.OnGameOver06005621. This sets game-over state, calls GameEntity.NotifyOfGameOver06005489, fires the event, then records LastGameData.GameResult. Client presentation never applies new damage.

NotifyOfGameOver saves Gameplay's original game time scale, starts playlist107, then:

|Result|Jingle|Requested hero spell|Actual base Jaina/Guldan route|
|---|---|---|---|
|4 win|option22 victory|opponent37|opponent37|
|5 lose|option21 defeat|friendly38|friendly38|
|6 tie|option21 defeat|opponent39 then friendly39|opponent39 and friendly38|

The final column is important: ActivateSpellForDestroyedHero060054f3 rewrites friendly39 to38; premium opponent39 can become37. Current base hero paths have neither premium actor skin nor custom VictoryStrike275/276, nor tag2722 death overrides. All such branches remain distinct from the current route.

Actor SpellTable c7908ae61ab34412aa7f5a9bf3c89cf2 maps37→12c1c3108fb2a478abd40c616511bd47;38→09e8a0b21e7104bda9f1bee63f16ebd2;39→c15ab723121e148839e6dde4cd592586. Type5 d6bdb33b8a4a84b78a6b43aa989cfaf4 exists but is not the base terminal route. Card.Check_HeroToGraveyard06012e28 does DoCardDeathVisuals, not minion-style death-spell activation.

BlowUpHero060054f2 first asks existing Actor spells to enter Death, then activates the chosen terminal spell and starts HideOtherElements. Its coroutine06005568 waits .5scaled seconds, hides that controller's hero power and weapon cards, armor, health and attack gems, and forces hero/power/weapon idle. It does not itself destroy the hero or blanket-hide its portrait root.

## Clock and finish gates

Win37: Action→CheckSide→State2(.40000000596)→State3(.80000001192)→State4(immediate)→State5(1.2999999523)→Check for Pet(no pet)→None. Nominal total2.4999999702 scaled seconds.

Lose38: Action→CheckSide→State2(.5)→State3(.80000001192)→State4(1.2999999523)→None. Total2.5999999642 scaled seconds.

DrawOpponent39: Action→State5(RandomWait .10000000149..30000001192)→State2(.5)→State3(1)→State4(immediate)→State6(1.2999999523)→None. Total random+2.7999999523 scaled seconds.

These are NOT wall-clock seconds. Every AnimateFloatV2 uses realTime=false and calculation1, normalized curve sampling Evaluate(currentTime / time * lastKey.time), original Hermite slopes retained. AnimateFloatV2060000c2 signals FINISHED one update after finishAction is set; zero-duration PlayMaker transitions are also frame quantized. Do not substitute a fixed1/60extra delay.

Win's first ScaleTime06000d9a writes Unity Time.timeScale directly and fixedDeltaTime=.01999999955*timeScale. The remaining SetTimeScaleAction0600011c calls TimeScaleMgr.SetGameTimeScale. Core06000093/96 stores gameTimeScale and writes Unity timeScale=gameTimeScale*timeScaleMultiplier (both initialized1). Gameplay06005840/41 saves/restores the manager value. For a normal offline presentation multiplier1 is an explicit bridge assumption. In a tie both FSMs write the same global scale; their per-frame Unity update ordering is a runtime input not proven by serialized creation order. Preserve concurrent shared clock and disclose scheduler compatibility, rather than claiming a unique exact wall-clock trajectory.

RandomWaitAction060000f7 uses UnityEngine.Random.Range(float,float) once;060000f8 accumulates deltaTime and finishes when elapsed>chosen wait. Use presentation-only randomness, never the existing rules RNG.

None's SpellStateAction06016d21/22→Spell.OnFsmStateStarted06014961→ChangeStateImpl0601496c→FinishIfNecessary06014971→OnSpellFinished0601495f. No earlier SpellFinishAction exists in37/38/39. GameEntity06005500/501/502 waits every applicable enemy/friendly spell IsFinished, restores original scale and calls EndGameScreen.Show. It does NOT wait sound duration. AudioPlaythroughAction06016aca queues audio and immediately finishes its action.

None is not a release/free gate. Spell.OnEnteredNoneState0601498b only removes blocking and calls ActivateObjectContainer(false).06014937 returns immediately for null object-container; all three original terminal prefabs have null. GameEntity's finished callback does not destroy Actor/spell. Win fireworks can persist beyond screen appearance. End of the presentation session/scene owns cleanup; never free at the nominal finish time merely because the results screen appears.

## Hero death VO is a separate metadata chain

There is no AudioPlayActorDeathVOAction in the three current terminal FSMs and the restored HeroCrack/HeroExplode/LightBurst clips have empty animation events. Their InvokeMethod calls only assign portrait textures.

PowerProcessor's type6 death block chooses DeathSpellController. OnProcessTaskList0601164e first PickDeathSoundCardIndex06011651, then suppresses every other target's death sound and calls Card.ActivateCharacterDeathEffects06012d53. GameUtils.IsCharacterDeathTagChange06014cf9 requires ZONE49→GRAVEYARD4 and IsCharacter; EntityBase0601392f is hero OR minion. CanPlayDeathSound06011654 excludes tags382/959. If exactly two targets attacked one another, the attacked eligible defender is preferred; otherwise06011653 selects one eligible character using Unity random. This is not necessarily one hero: simultaneous minions belong to the original death-wave pool.

Card.ForceActivateDeathSoundSpells06012d54 prefers emote type29 if provided; otherwise activates m_DeathEffect sound paths. Both current heroes'43 emotes lack29, so fallback is exact:
- HERO_08: Death.prefab:abbcdd89616bf4540968b285d9df0753.
- HERO_07: Death.prefab:ef972edca76e6c84a9e68adcdd6072ec.

The terminal tag and death-wave VO are separate source events; no fixed relative timestamp can be established without a corresponding original PowerHistory. The offline bridge should consume its actual death wave once and must not replay one VO per dead hero at explosion. Simultaneous hero/minion pool selection and any missing source history must be disclosed, not inferred from HP alone. Concession and HP death are not the same VO permission/event.

## Portrait, actor visibility and particle controls

AssignActorPortraitToChildren.Start06015063 searches this GO/parents for Actor. AssignPortraitToAllChildren06015065 requires Actor/Card/portraitMesh. Preferred portrait0 calls GetPortraitTexture(0,false,false); preferred1 uses GetPortraitMaterial(1).mainTexture. It traverses GetComponentsInChildren<Renderer>() (default active objects), gets runtime materials and replaces mainTexture only when material.name.Contains("portrait") (case sensitive). No replacement shader, transform, color or UV is specified. State3 calls it before HeroExplode playback.

Win/Lose State3 hide dynamic RootObject from SpellInitActorVariables (the Actor.m_rootObject, not the effect prefab). DrawOpponent39 contains neither that init nor hide action. Do not invent the missing action. Lose State3's fragment-show and crack-hide have resetOnExit=true; preserve restoration at State3 exit. Win/Draw equivalents use false. Three SetProperty actions point to actual ParticleSystem components and set playbackSpeed=.5.

## Result screen and text

GameEntity.InitStringOptions06005442:
- option17 VictoryTwoScoop.prefab:b31e3c6c1e80ced4183c3e231c567669.
- option18 DefeatTwoScoop.prefab:6535dd92d63fce1478220e9bc50e926b, shared by lose and tie.
- option22 victory_jingle.prefab:23f19dd07c7a5114abe5f525099cbac4.
- option21 defeat_jingle.prefab:0744a10f38e92f1438a02349c29a7b76.

ShowStandardFlowIfReady06004d6f waits original account/rank/reward readiness; ShowTwoScoopWhenReady06004d75 waits score screen absence, loaded portrait and optional hero reward readiness. Offline assets-ready/no-account-reward is an explicit bridge, not a reconstructed server timing.

DefeatTwoScoop.ShowImpl06004cb2 chooses GAMEPLAY_END_OF_GAME_TIE when LastGameData.GameResult6, otherwise DEFEAT. Victory selects VICTORY. Official zhCN values are 胜利 / 败北 / 平局！. EndGameScreen.Awake06004cc6 selects GLOBAL_CLICK_TO_CONTINUE or GLOBAL_CLICK_TO_CONTINUE_TOUCH (bothzhCN点击继续). Do not relabel tie defeat merely because it shares a prefab/jingle.

EndGameTwoScoop.OnHeroActorLoaded06004d9e parents a separately loaded Hero Actor to TwoScoop and copies m_heroBone localposition/localrotation/localscale, disables collider and health GO, applies premium and updates components. This is not reparenting the dead board actor.

ShowImpl/PlayShowAnimations send FSM Action at show time; screen audio starts there, not terminal time. Root FadeTo alpha1/.25s; root scale .01→2.5/.5s. Defeat ease24=easeOutBounce; Victory leaves ease unspecified (iTween default16=easeOutExpo). PunchEndGameTwoScoop06004d9b at scale completion clears existing blockingAnim and scales to2.2999999523/.15000000596. Source base drift and all other part transforms are in hero_endgame_initial.cil.*; AnimateAll18tweens are normalized separately.

Banner RenderToTexture0, outline1, shadow1: shadow is serialized but inactive in this direct-text route. UberText.RenderText0600009b IL00c3 requires RenderToTexture before SetupRenderToTexture060000b3, whose render-plane branch alone calls SetupShadow060000c4. Do NOT add TextShadow simply from shadow1. Direct outline is Hidden/TextOutline_Unlit. Font/localization exact resources and size40 banner /51continue belong to source_endgame_assets/data/result_text_zhcn.json.

## Input and close

ContinueDefaultEvents06004cde blocks if playingBlockingAnim or inputBlocker>0 and requires haveShownTwoScoop. EndGameScreen ctor06004d2f does not set blockingAnim (defaultfalse, not serialized). Base ShowTwoScoop/ShowImpl does not set it true. Score/reward variants do; ShowScoreScreen06004ce9 sets true and clears after.65, but CanShowScoreScreen0600560d requires score labels absent in the current ordinary offline duel. Therefore .5root scale is not proof of a mandatory .5input lock. Punch merely clears an existing block.

No-reward ContinueEvents06004cdb calls HideTwoScoop then sends the TwoScoop FSM Death and returns to previous mode. HideAll06004d9c disables ScreenEffects, FadeTo0/.25 and ScaleTo.01/.25 defaultease; OnAllHidden06004d9d forcesFade0, deactivatesGO, resetspositions. Root hide starts immediately; audio Death has its own fade1s and shrink sound, not a .25hard-stop. Original loading/account/rewards/menu operations are out of scope and must not run; use the project's already authorized local exit/restart flow.

## Exact remaining boundaries

1. Original Unity frame/update ordering, concurrent tie time-scale setter order, runtime random state and source PowerHistory are unavailable. No fixed unique wall-clock claim is justified.
2. Three byte-size1 FsmFloat fields remain undecoded only in Lose/ReScaleCracks' premium-only SetScale; all base current route parameters are decoded. Source raw bytes are retained. No premium path is authorized/current.
3. Native Unity rendering/particle/font implementation compatibility remains separate from verified CIL/asset chains; source action coverage cannot establish pixel identity.
4. Source base account-ready, no-pet, no-score, no-premium context is the deliberate current-route boundary. Do not activate7reward FSMs merely because their resources are in the closure.
5. This research does not change rules, reapply damage, or define an extra game-over result event.

## Final PC transform and direct-text queue closure

ScreenCategory.PC is constant4 (field0x04011e76, exact Constant table bytes04000000); Phone1, MiniTablet2, Tablet3. See screen_category_enum.json. PlatformSettings.GetBestScreenMatch06014eb0 chooses the smallest nonnegative category-current difference, default index0. Both screen roots have categories[4,1], so current PC uses index0.

TransformOverride.Awake0600e8c7 calls UpdateObject0600e8ca only when Application.IsPlaying(this). UpdateObject assigns its own GameObject localPosition/localScale/localRotation from the selected arrays. There is no Update/LateUpdate in this component. Current Victory and Defeat PC root overrides both explicitly set position(0,0,0), scale(1,1,1), identity rotation. Defeat's authoring position(0,-1.5,.60000002384) is its Phone override, not the correct PC position. m_transformOverride does not directly modify TwoScoop's separately copied heroBone. Apply relevant current branch PC overrides before programmatic Show/ResetPositions; preserve source child overrides including continue text. The full15-record list is screen_transform_overrides.json, with reward-only records retained for evidence, not activated. CIL is endgame_transform_override.cil.* and endgame_screen_category.cil.*. Thus the exact PC zero root is established without assuming IAssetLoader generically zeroes prefab positions.

Direct UberText queue increment q changes BOTH Renderer.sortingOrder=q and queried material.renderQueue=Clamp(originalQueue+q,1,5000), not only sorting order. SetRenderQueueIncrement060001f1 passes WithIncrementRenderQueue(q); IncrementRenderQueueMaterialProperty06000159 caches the original queue once before applying the increment. For the restored direct outline shader queue3000, source stable tuple is(q,3000+q). Repeated property updates do not add q cumulatively. These methods were recovered in the v32.1 damage-text closure and apply to current result text unchanged.

The separately loaded result Hero Actor must also run the source default stat presentation, not retain every prefab-active gem. Actor.UpdateAllComponents0601285e calls UpdateTextComponents0601289e, which prefers m_entityDef when present, then0601289f→UpdateAttackTextMesh060128a9. That method uses m_attackTextOverride or tag47; if IsHero and attack==0, IL00db..00fd disables m_attackObject, IL0102..010d clears text and returns. Nonzero attack re-enables it. The live Entity branch060128c8 also treats hero GetATK==0 as hidden text/gem via UpdateNumberText('',true,true). Current base hero definitions have zero attack. This is a source initialization condition, not an artistic crop. Exact unchanged CIL extracted to result_hero_zero_attack.cil.txt from the already recovered same-build Actor methods.
