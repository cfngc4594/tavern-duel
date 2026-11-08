# 原版法术音效强引用取证

## 范围与证据

- 30张限定卡的CardDef视觉法术根（20个有法术效果的卡牌）以及2个默认英雄技能。随从Play/Attack/Death VO由资源代理的direct_card_audio_events单独覆盖。
- 依据CardDef m_PlayEffectDef.m_SpellPath → Unity prefab → 强PPtr → FSM参数/SpellStateAudioSource → AudioSource / SoundDef → name:GUID；不以音名猜配。
- 产物：spell_audio_bindings.json（91个播放行、41个stop/fade/set-volume控制行）；spell_fsm_decoded.json保留所有状态、动作索引与转换；spell_prefab_closure.json保留完整原始组件数据。
- 59个音频GUID的请求表为spell_audio_clip_requests.json；音频下载/解码/zhCN变体由资源代理统一处理。

## 不可省略的运行条件

- runtime_eligible只说明在该原状态中可播放，不代表所有行同时触发。83行可播放，3行action_disabled，3行conditional_default_null，2行duplicate_state_shadowed。
- SpellCardIdAudioPlayAction无匹配且default null时立即Finish，不能回退播放附着SoundDef。变羊CFM_620、吸取生命/牺牲契约CFM_603分支在本卡池静默。奥爆GILA_900h2分支不匹配时选原m_DefaultSound。
- 现代英雄皮肤CardSpecificVO不属于默认吉安娜/古尔丹；这份法术映射不擅自加入这些语音。
- AudioPlayRandomClipAction.sound_options是一组权重单选，不是叠加。SoundDef.m_RandomClips也为单选。
- AudioPlayClipAction的m_Sound必须是SoundDef；未解析引用不能回退同物体SoundDef。m_TemplateSource为空时依SoundConfig默认template，不把parent物体音源当template。
- 同一音频文件可由不同阶段/源实例合法触发。不能按文件名去重；控制行以cab:path_id定位模板源，并由每次法术实例隔离。

## 状态与时间

- SpellStateType：0 None，1 Birth，2 Idle，3 Action，4 Cancel，5 Death。此Death是法术生命周期，尤其Impact子法术Death表示抵达，不是随从死亡。
- delay_sec为当前action进入状态后的局部延迟。当前91条字面值均0，不等于从出牌起同时播放。进入前可能等待动画、Wait、其他动作完成。
- PlayAction等待SoundManager.IsActive=false再Finish；PlaythroughAction和PlayClipAction只等自身delay，播放后即Finish，不等完整音长。
- targeted non-minion进入目标预瞄时，HandleUpdateWhileHoldingCard→ActivatePlaySpell→Birth；不是刚按下拾卡。无目标法术需按其Drop/Activate链处理。
- event是阶段路由提示，entry_events/entry_paths与spell_fsm_decoded才是状态依据。precast只标Start Birth；launch标Missile；hit标Impact/Area；release/cancel不可全塞cast。
- stops保留AudioStopAction、AudioVolumeFadeAction（FadeTime、TargetVolume、StopWhenDone）与AudioSetVolumeAction；不能在state change无条件停全局源。

## 核心CIL核对点

- Spell.CallStateFunction 0x06014972：枚举→状态；Spell.ChangeFsmStateNow 0x06014970：EnumUtils.GetString→PlayMaker.SendEvent。
- SpellStateAudioSource.Play 0x06014A79；Stop 0x06014A7A：enabled、!PlayGlobally、StopOnStateChange条件。
- AudioPlayClipAction.Play 0x06016AAF；AudioPlaythroughAction.Play 0x06016ACA；AudioPlayAction.Delay 0x06016AA5。
- SpellCardIdAudioPlayAction.Play 0x06016CA6与GetClipMatchingCardId 0x06016CA0：null直接结束、Trim后OrdinalIgnoreCase匹配。
- InputManager.HandleUpdateWhileHoldingCard 0x06005A13 → ActivatePlaySpell 0x06005A18：有效区域目标预瞄触发Birth。

## 最终时序与稳定身份

- 主91行、41控制以及共享16行均已给primary_timing；只消费该主路径，不把timing_paths备选路径重复播放。shared的16行中13行有声音，另3个generic空SoundDef保持静默。
- PlayMaker Fsm.GetState和InitData按states数组找第一个同名状态，不能用最后写入覆盖。state_index+action_index+row_id是稳定身份；FrostNova后面的同名状态不可达。
- 显式事件先于隐式全动作FINISHED。中/大落地BIRTH中PlayAnimation发Action直接前进，不等旁边glow/shake动作；FINISHED备选标superseded_by_explicit_event。
- RandomWaitAction每个状态实例只抽一次，使用shared_draw_id复用到同状态各层。其原完成判断为elapsed > wait，帧量化不能伪称精确墙钟。
- Fireball/默认火冲的release中Death3是.5秒曲线之后；Frostbolt的release是Death2即时。Flamestrike对方区域结束层是显式AnimateFloat的.7秒，而非并行相机动作2.15秒。
- Corruption Impact先Wait .25；弓箭手Missile Birth先RandomWait .15–.45；恐惧地狱火每目标Impact先RandomWait .05–.35。
- Coin的ActionFadeOut读取同状态AnimateFloat变量曲线，非序列化占位常量1。控制行primary_timing.runtime_event为阶段，control_operation保留stop/fade/set_volume。
- AudioVolumeFadeAction/AudioSetVolumeAction控制SoundManager.m_codeVolume乘数，乘在base AudioSource音量上。普通fade线性；FadeTime<=epsilon只Finish，不额外强设目标。
- 普通落地AnimationPlaythroughAction启动后立即Finish，不等动画，所以友方声音只等后续.5秒，对方.43秒。SpellInitActorVariables也立即Finish。
- 仅两类路径涉及legacy动画静态重建：弓箭手Take001曲线末key为.6333333254秒；中/大落地AllyInPlaySpawn_Med为.3666667044秒。m_MuscleClipSize=0时默认StopTime=1不可用。这是legacy_curve_bounds_reconstruction，不是原Unity AnimationClip.length实测；以实际对应动画完成回调为优先。
- 以上时序相对各子法术状态进入，不含父SuperSpell spawn/path/target次数。父字段原样保存在spell_stage_schedule.json。
- 奥术飞弹下一发由前一弹到达触发；SpawnImpact协程不阻塞下一发。Impact.GameDelay用于元数据完成协程，不能串加到下一发发射间隔或当成音效延迟。

## 父法术实例基数（必须同时消费）

- spell_stage_cardinality.json按row_id给132个声音/控制行的实例基数与条件；每卡包含原enabled且Prefab非空的Area可用性，不以有没有声音反推。
- FriendlyAreaEffectInfo与OpponentAreaEffectInfo是按施法者控制方二选一的表现配置，不是同时播放的两个受伤区域。DetermineAreaEffectInfo(0x06014B33)优先选施法者对应候选；无匹配时fallback有效Friendly再Opponent。DoActionNow(0x06014B18)只SpawnAreaEffect一次。
- FrostNova、Flamestrike、Hellfire存在两个互斥候选；Intellect、Explosion、Infernal、Coin只有Friendly有效，敌方施法也fallback Friendly。Area每施法总计至多一次，与伤害目标数无关。
- Missile和Impact依有效visual-target iteration分别实例化；无Missile时SpawnAllImpacts(0x06014B2B)遍历有效目标，有Missile则在到达时SpawnImpact。ArcaneMissiles顺序发射不能合并同帧。
- WaitAndSpawnMissile(0x06014B91)对非顺序弹或顺序首弹始终yield WaitForSeconds(SpawnDelay)，即0也yield。SpawnAllMissiles随后立即DoStartSpellAction，故Fireball cast先，launch至少协程后续帧；不能以group343正确限流掩盖同帧起点。另有动态CompleteTasksUntilMetaData门禁。Godot下一process帧只是调度适配，不冒称原Unity帧时间。
- Impact(0x06014B8B)与选中Area(0x06014B7F)也始终yield SpawnDelay，0也不取消yield。音效旁路应保持该门禁以及impact→对应死亡声音次序，不能把hit异步后death即时。
- Start是同一次施法跨Birth/Action/Death/Cancel共享源实例。root也是一次根状态事件，DrainLife/Pact的root Death不能在每个伤害目标上重复播。

## 共享战斗声音

- shared_audio_bindings.json：普通/中/大落地、友敌spawn、通用death、summon-out，以及按攻击力分档的4种实体命中。
- 攻击命中由AttackSpellController.prefab:12acecc85ac575e43b87ec141b89269a强引用，按攻击者ATK：0–2小，3–5默认，6–7大，8–9999超大；不是随机，也不把大攻击当暴击。
- 共有3个额外generic源SoundDef为空且delay=.1，合法无声，不找近似文件填充。
- 本卡池无武器规则，软泥怪毁武器法术源已保留，不能因此擅自新增武器规则。精灵弓箭手和恐惧地狱火战吼已按原CardDef法术闭包覆盖。
- 恶魔卫士EX1_301的CardDef仅Play/Attack/Death音效引用，Play视觉法术为空，Additional/Trigger/SubSpell/Overrides均为空；不能据音名编造卡专属毁水晶声音。

## 最后两条本卡池必要共享链

- hand_audio_bindings.json：手牌Actor的1/22/23原表分别选择普通/大/中移出效果，不可和场上summon-out表混用。共5行，普通源的Regular/Premium/State2三路互斥；当前非传奇普通卡ELITE114=0走noDragon，PREMIUM12=0走isRegular，因此保留3个表变体各1行，其余2行静默。Dragon?是传奇外框分支，不是龙种族。
- hand_fsm_decoded.json保留完整CustomType40嵌套ValueRangeEvent范围，whichEntity5取spellActor实体，无actor才fallback source。三个有效行前置变量/可见性/材质/条件动作立即Finish，无固定等待；仍受状态帧调度。后续同状态动画不是播放前门禁。
- 恶魔卫士EX1_301的卡专属视觉法术为空，但现已闭合本池必要通用毁水晶链：Player.DestroyManaCrystal只友方调用ManaCrystalMgr→ManaCrystal.Destroy/WaitThenDestroy→默认ManaCrystal.gemDestroy强引用。mana_destroy_audio_bindings.json只有1行，Action→iTweenShakePosition显式FINISHED .5秒→State3播放mana_crystal_expend.wav:56dc0c11d98cdae4795ea38a39f3150c。
- 上述毁水晶声音来自默认晶体资源，不是按文件名猜配。敌方Player.DestroyManaCrystal直接return，不可双边一律播放。并行ManaGemDestroy动画没有finishEvent，不能再把其时长相加。
- 精确链与边界见mana_crystal_asset_search.json、mana_destroy_prefab_closure.json及audio_code_evidence/mana_crystal_events.cil.json。felguard_spell_binding_audit.json保留卡专属缺绑定与通用补链两个独立结论。

## 每卡已解析的有效阶段

### CS2_022
- root/m_StartInfo.m_Prefab / state[1] BirthState / AudioPlayClipAction / precast+0s: Shared_Arcane_Start_1.wav
- root/m_StartInfo.m_Prefab / state[1] BirthState / AudioPlaythroughAction / precast+0s: Shared_Arcane_PreCast_1.wav
- root/m_StartInfo.m_Prefab / state[3] CancelState / AudioPlayClipAction / cancel+0s: Shared_Arcane_Fizzle_1.wav
- root/m_ImpactInfo.m_Prefab / state[1] DeathState / AudioPlayClipAction / hit+0s: Shared_PolymorphHex_Impact.wav

### CS2_023
- root/m_FriendlyAreaEffectInfo.m_Prefab / state[2] Action / AudioPlaythroughAction / hit+0s: Mage_ArcaneIntellect_Cast_1.wav

### CS2_024
- root/m_StartInfo.m_Prefab / state[6] State 2 / AudioPlayClipAction / precast+0s: Shared_Frost_Start_1.wav
- root/m_StartInfo.m_Prefab / state[6] State 2 / AudioPlayAction / precast+0s: Shared_Frost_PreCast_1.wav
- root/m_StartInfo.m_Prefab / state[7] Kill Ice / AudioPlaythroughAction / cancel+0s: Shared_Frost_Fizzle_1.wav
- root/m_StartInfo.m_Prefab / state[9] Death 2 / AudioPlaythroughAction / release+0s: Shared_Frost_Fizzle_1.wav
- root/m_MissileInfo.m_Prefab / state[2] ActionState / AudioPlayAction / launch+0s: Shared_Frost_Cast_1.wav
- root/m_ImpactInfo.m_Prefab / state[2] Death 1 / AudioPlaythroughAction / hit+0s: Shared_Frost_Impact_1.wav

### CS2_025
- root/m_FriendlyAreaEffectInfo.m_Prefab / state[2] Action 1 / SpellCardIdAudioPlayClipAction / hit+0s: Mage_ArcaneExplosion_AE_1.wav

### CS2_026
- root/m_FriendlyAreaEffectInfo.m_Prefab / state[3] ActionState1 / AudioPlayClipAction / hit+0s: Mage_FrostNovaCast_New.wav
- root/m_OpponentAreaEffectInfo.m_Prefab / state[3] Action 1 / AudioPlayClipAction / hit+0s: Mage_FrostNovaCast_New.wav

### CS2_027
- root / state[None] Action / SpellStateAudioSource / cast+0s: mirror_entity_cast.wav

### CS2_029
- root/m_StartInfo.m_Prefab / state[2] ActionState / AudioPlaythroughAction / cast+0s: Shared_Fire_Cast_1.wav
- root/m_StartInfo.m_Prefab / state[8] State 2 / AudioPlayClipAction / precast+0s: Shared_Fire_Start_1.wav
- root/m_StartInfo.m_Prefab / state[8] State 2 / AudioPlayAction / precast+0s: Shared_Fire_Precast_1.wav
- root/m_StartInfo.m_Prefab / state[9] Kill Fireball / AudioPlaythroughAction / cancel+0s: Shared_Fire_Fizzle_1.wav
- root/m_StartInfo.m_Prefab / state[12] Death 3 / AudioPlayAction / release+0.5s: Shared_Fire_Fizzle_1.wav
- root/m_MissileInfo.m_Prefab / state[2] ActionState / AudioPlayAction / launch+0s: Shared_Fire_Cast_1.wav
- root/m_ImpactInfo.m_Prefab / state[2] Death 1 / AudioPlayClipAction / hit+0s: Shared_Fire_Impact.wav

### CS2_032
- root/m_FriendlyAreaEffectInfo.m_Prefab / state[3] ActionState / AudioPlayClipAction / hit+0s: Shared_FireAE_Impact_1.wav
- root/m_OpponentAreaEffectInfo.m_Prefab / state[3] ActionState / AudioPlayRandomClipAction / hit+0s: AE_Fire_Start_02.wav（权重单选）
- root/m_OpponentAreaEffectInfo.m_Prefab / state[5] State 2 / AudioPlayRandomClipAction / hit+0.7s: AE_Fire_End_02.wav（权重单选）

### CS2_034
- root/m_StartInfo.m_Prefab / state[2] ActionState / AudioPlaythroughAction / cast+0s: Shared_Fire_Cast_1.wav
- root/m_StartInfo.m_Prefab / state[7] Finish / AudioPlayAction / cancel+0.5s: Shared_Fire_Fizzle_1.wav
- root/m_StartInfo.m_Prefab / state[8] State 2 / AudioPlayClipAction / precast+0s: Shared_Fire_Start_1.wav
- root/m_StartInfo.m_Prefab / state[8] State 2 / AudioPlayAction / precast+0s: Shared_Fire_Precast_1.wav
- root/m_StartInfo.m_Prefab / state[12] Death 3 / AudioPlayAction / release+0.5s: Shared_Fire_Fizzle_1.wav
- root/m_MissileInfo.m_Prefab / state[2] ActionState / AudioPlayAction / launch+0s: Shared_Fire_Cast_1.wav
- root/m_ImpactInfo.m_Prefab / state[2] Death 1 / AudioPlaythroughAction / hit+0s: Shared_Fire_Impact_Small.wav

### CS2_056
- root/m_ImpactInfo.m_Prefab / state[0] Play FX / AudioPlayClipAction / hit+0s: ReuseFX_HealImpact_Void_Small_Sound.wav

### CS2_057
- root/m_StartInfo.m_Prefab / state[1] State1 / AudioPlaythroughAction / precast+0s: Shared_Shadow_Start_1.wav
- root/m_StartInfo.m_Prefab / state[1] State1 / AudioPlaythroughAction / precast+0s: Shared_Shadow_PreCast_2.wav
- root/m_StartInfo.m_Prefab / state[3] Cancel / AudioPlayClipAction / cancel+0s: Shared_Shadow_Fizzle_1.wav
- root/m_MissileInfo.m_Prefab / state[2] Action State / AudioPlaythroughAction / launch+0s: Warlock_ShadowBolt_Cast_1.wav
- root/m_ImpactInfo.m_Prefab / state[2] Death 1 / AudioPlayClipAction / hit+0s: Warlock_ShadowBolt_Impact_1.wav

### CS2_061
- root / state[2] Death / AudioPlaythroughAction / hit+0s: Warlock_SiphonSoul_CasterImpact_1.wav
- root/m_StartInfo.m_Prefab / state[1] State1 / AudioPlaythroughAction / precast+0s: Shared_Shadow_Start_1.wav
- root/m_StartInfo.m_Prefab / state[1] State1 / AudioPlaythroughAction / precast+0s: Shared_Shadow_PreCast_2.wav
- root/m_StartInfo.m_Prefab / state[3] Cancel / AudioPlayClipAction / cancel+0s: Shared_Shadow_Fizzle_1.wav
- root/m_MissileInfo.m_Prefab / state[2] Action State / AudioPlayClipAction / launch+0s: Warlock_DrainLife_Cast_1.wav
- root/m_ImpactInfo.m_Prefab / state[3] State 2 / AudioPlayClipAction / hit+0s: Shared_WarlockBaneOfDoom_Impact_1.wav

### CS2_062
- root/m_FriendlyAreaEffectInfo.m_Prefab / state[3] Action 1 / AudioPlayRandomClipAction / hit+0s: Warlock_Hellfire_Cast_1.wav（权重单选）
- root/m_OpponentAreaEffectInfo.m_Prefab / state[3] Action 1 / AudioPlayRandomClipAction / hit+0s: Warlock_Hellfire_Cast_1.wav（权重单选）

### CS2_063
- root/m_StartInfo.m_Prefab / state[1] State1 / AudioPlaythroughAction / precast+0s: Shared_Shadow_Start_1.wav
- root/m_StartInfo.m_Prefab / state[1] State1 / AudioPlaythroughAction / precast+0s: Shared_Shadow_PreCast_2.wav
- root/m_StartInfo.m_Prefab / state[3] Cancel / AudioPlayClipAction / cancel+0s: Shared_Shadow_Fizzle_1.wav
- root/m_MissileInfo.m_Prefab / state[1] Birth State / AudioPlaythroughAction / launch+0s: Shared_Shadow_Cast_1.wav
- root/m_ImpactInfo.m_Prefab / state[3] State 2 / AudioPlayClipAction / hit+0.25s: Warlock_Corruption_Impact_1.wav

### CS2_064
- root/m_ImpactInfo.m_Prefab / state[1] DeathState / AudioPlayRandomClipAction / hit+0.05–0.35s: AE_FEL_Impact_01.wav（权重单选）
- root/m_FriendlyAreaEffectInfo.m_Prefab / state[3] ActionState1 / AudioPlayRandomClipAction / hit+0s: AE_FEL_Cast_01.wav（权重单选）

### CS2_189
- root/m_MissileInfo.m_Prefab / state[3] ActionState / AudioPlaythroughAction / launch+0.15–0.45s: Arrow_Targeted_Fire_01.wav, Arrow_Targeted_Fire_02.wav, Arrow_Targeted_Fire_03.wav
- root/m_ImpactInfo.m_Prefab / state[1] DeathState / AudioPlayRandomClipAction / hit+0s: Arrow_Targeted_Impact_01.wav, Arrow_Targeted_Impact_02.wav, Arrow_Targeted_Impact_03.wav（权重单选）
- root/m_ImpactInfo.m_Prefab / state[1] DeathState / AudioPlayRandomClipAction / hit+0s: Arrow_Targeted_Build_01.wav, Arrow_Targeted_Build_02.wav, Arrow_Targeted_Build_03.wav（权重单选）
- root/m_ImpactInfo.m_Prefab / state[3] DeathState 2 / AudioPlayRandomClipAction / hit+0.6833–0.7833s: Arrow_Targeted_Explode_01.wav, Arrow_Targeted_Explode_02.wav, Arrow_Targeted_Explode_03.wav（权重单选）
- root/m_ImpactInfo.m_Prefab / state[5] WaitState / AudioPlayRandomClipAction / hit+0.6333s: Arrow_Targeted_Build_01.wav, Arrow_Targeted_Build_02.wav, Arrow_Targeted_Build_03.wav（权重单选）

### EX1_066
- root/m_MissileInfo.m_Prefab / state[1] Action State / SpellCardIdAudioPlayAction / launch+0s: AcidicSwampOoze_AcidGlobThrow_Cast_1.wav
- root/m_ImpactInfo.m_Prefab / state[1] DeathState / AudioPlaythroughAction / hit+0s: AcidicSwampOoze_AcidGlobThrow_Impact_1.wav

### EX1_277
- root/m_StartInfo.m_Prefab / state[1] BirthState / AudioPlayClipAction / precast+0s: Shared_Arcane_Start_1.wav
- root/m_StartInfo.m_Prefab / state[1] BirthState / AudioPlaythroughAction / precast+0s: Shared_Arcane_PreCast_1.wav
- root/m_StartInfo.m_Prefab / state[3] CancelState / AudioPlayClipAction / cancel+0s: Shared_Arcane_Fizzle_1.wav
- root/m_MissileInfo.m_Prefab / state[2] ActionState / AudioPlayRandomClipAction / launch+0s: Shared_Shadow_Cast_1.wav（权重单选）
- root/m_ImpactInfo.m_Prefab / state[2] DeathState 2 / AudioPlayRandomClipAction / hit+0s: Mage_ArcaneMissiles_Impact_1.wav, Mage_ArcaneMissiles_Impact_2.wav, Mage_ArcaneMissiles_Impact_3.wav（权重单选）

### EX1_302
- root/m_StartInfo.m_Prefab / state[1] State1 / AudioPlaythroughAction / precast+0s: Shared_Shadow_Start_1.wav
- root/m_StartInfo.m_Prefab / state[1] State1 / AudioPlaythroughAction / precast+0s: Shared_Shadow_PreCast_2.wav
- root/m_StartInfo.m_Prefab / state[3] Cancel / AudioPlayClipAction / cancel+0s: Shared_Shadow_Fizzle_1.wav
- root/m_MissileInfo.m_Prefab / state[2] Action State / AudioPlaythroughAction / launch+0s: Shared_WarlockMissile01Green_Cast_1.wav
- root/m_ImpactInfo.m_Prefab / state[2] Death 1 / AudioPlaythroughAction / hit+0s: Shared_FireblastImpactGreen_1.wav

### EX1_308
- root/m_StartInfo.m_Prefab / state[1] State1 / AudioPlaythroughAction / precast+0s: Shared_Shadow_Start_1.wav
- root/m_StartInfo.m_Prefab / state[1] State1 / AudioPlaythroughAction / precast+0s: Shared_Shadow_PreCast_2.wav
- root/m_StartInfo.m_Prefab / state[3] Cancel / AudioPlayClipAction / cancel+0s: Shared_Shadow_Fizzle_1.wav
- root/m_MissileInfo.m_Prefab / state[2] ActionState / AudioPlayAction / launch+0s: Shared_Fire_Cast_1.wav
- root/m_ImpactInfo.m_Prefab / state[2] Death 1 / AudioPlayClipAction / hit+0s: Shared_Fire_Impact.wav

### GAME_005
- root/m_FriendlyAreaEffectInfo.m_Prefab / state[1] ActionState1 / AudioPlayClipAction / hit+0s: Holy_Targeted_Start_01.wav
- root/m_FriendlyAreaEffectInfo.m_Prefab / state[4] ActionState2 / AudioPlayAction / hit+0s: Holy_Targeted_Loop_01.wav

### NEW1_003
- root / state[2] Death / AudioPlaythroughAction / hit+0s: Warlock_SiphonSoul_CasterImpact_1.wav
- root/m_StartInfo.m_Prefab / state[1] State1 / AudioPlaythroughAction / precast+0s: Shared_Shadow_Start_1.wav
- root/m_StartInfo.m_Prefab / state[1] State1 / AudioPlaythroughAction / precast+0s: Shared_Shadow_PreCast_2.wav
- root/m_StartInfo.m_Prefab / state[3] Cancel / AudioPlayClipAction / cancel+0s: Shared_Shadow_Fizzle_1.wav
- root/m_MissileInfo.m_Prefab / state[1] Birth State / AudioPlaythroughAction / launch+0s: Shared_Shadow_Cast_1.wav
- root/m_ImpactInfo.m_Prefab / state[3] State 2 / AudioPlayClipAction / hit+0s: Shared_WarlockBaneOfDoom_Impact_1.wav

