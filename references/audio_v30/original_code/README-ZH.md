# 原版卡牌音效：只读代码证据

## 来源与范围

源为用户当前工程同源资源 build **37.0.0.255130.254477** 的 Assembly-CSharp.dll，SHA-256 `7f81d2ab2277958dea4351c41812921a00ee263a6a7abf1a5cfb4eb0794f26e5`。使用可信 PyPI dnfile 0.18.0 / dncil 1.0.2 解码 PE/CLR/CIL，不执行被测 DLL，不登录客户端。本证据不是 2014 年 1.0.0.5834 二进制证明；玩法卡池可以取 2014 数值，但声音与路由来自上述现代原包。

30 张 CardDef（27 collectible + 硬币、镜像、绵羊）的精确引用入口已在 `card_binding_roots.json`。每行来自资源代理保存的 `../audio_assets_evidence/carddefs.json` 原 typetree，含 bundle/GUID/path ID；不会将多个同名 `Play.prefab` 误认为相同资产。逐层 AudioClip/本地化/解码证据由资源代理另交。

## 已证明的查找链

1. `DefLoader.GetCardDef(cardId)` **0x06013661**, IL_000b–0022：服务中的 IAliasedAssetResolver.GetCardDefAssetRefFromCardId → AssetLoader.GetOrInstantiateSharedPrefab。不是由卡名拼造文件路径。
2. `AliasedAssetResolver.GetCardDefAssetRefFromCardId` **0x06012AE1** 委托 AssetBundlesAliasedAssetResolver。资源侧 `cards_map.json` / `base_assets_catalog.json` 提供 cardID→assetRef→bundle。
3. `Card.InitCardDefAssets` **0x06012D63** 将 CardDef 的 m_PlayEffectDef / m_AttackEffectDef / m_DeathEffectDef 交给 InitEffect。对应字段 token **0x0400FBFA / FBFC / FBFD**。
4. `CardEffectDef` **0x020027E9**：m_SpellPath:string (**0x0400FC49**)，m_SoundSpellPaths:List<string> (**0x0400FC4A**)。
5. `CardEffect.GetSoundSpells` **0x06012FD4** 按索引逐一 LoadSoundSpell；后者 **0x06012FD3**, IL_0042–005f，使用列表中完整 assetRef→SpellManager.GetSpell→CardSoundSpell，并调用 SpellUtils.SetupSoundSpell 绑定 owner。soundSpells 列表是多个层，不是随机候选池。
6. `CardSoundSpell.m_CardSoundData` 是一个 CardSoundData，不是数组。CardSoundData 包含 AudioSource 与 DelaySec。Play/OnBirth → 该 source 上 SoundDef → RandomAudioClip（权重）或主 clip 字符串 GUID → SoundLoader 本地化加载。
7. 与之并行，m_SpellPath 的视觉/法术 prefab 自带 SpellStateAudioSource、动画事件或自定义代码声源。施法/弹道/命中必须继续沿真实 prefab 状态引用追踪，不能只读 m_SoundSpellPaths。

## 事件时间与状态

- `Spell.CallStateFunction` **0x06014972** 的 switch 明确：1=Birth，2=Idle，3=Action，4=Cancel，5=Death，其他（含0）=None。这是调用分派证据。
- 手牌落场：`Card.Check_HandToPlayOrHero` **0x06012E25**，IL_002d 激活 hand-to-play actor spell；检查 CardDef.m_SuppressPlaySoundsOnSummon / CARD_DOES_NOTHING 后在 IL_0060 调 ActivateCharacterPlayEffects。不要把 VO 延迟到伤害命中后。
- 普通生成随从：`Card.ActivateStandardSpawnMinionSpell` **0x06012DBB** 先激活 actor spawn spell，再在 IL_0044 启动出场声。自定义 spawn 路径则 `OnSpellFinished_CustomSpawnMinion` **0x06012DC2** IL_0023 播出场声，二者时机不完全相同。
- 攻击语音：玩家输入 `InputManager.HandleClickOnCardInBattlefield` **0x06005A2F**, IL_06B8 调 ActivateCharacterAttackEffects，位于选择角色进入攻击瞄准阶段、获取 actor attack spell 之前。不是物理接触声音。直接提交攻击/AI 路径需避免重复触发同一台词。
- `Card.ActivateCharacterPlayEffects / AttackEffects / DeathEffects` 分别 **0x06012D4F / 52 / 53**。Play 尊重 suppress 后清零；Death 尊重 suppressDeathEffects / hero override / suppressDeathSounds，随后关闭 lifetime effects。
- `CardSoundSpell.OnBirth` **0x06011D81**→Play；OnNone **0x06011D82**→Stop。Play **0x06011D88** 先停止自身旧声源与两段协程，再挑 source，source null 则结束状态；DelaySec>0 时等待后实际播放。Stop **0x06011D8A** 取消 DelayedPlay / WaitForSourceThenFinishState 两段协程并 SoundManager.Stop。重入不能让旧延迟声继续补播。
- `SpellStateAudioSource.Play` **0x06014A79** 仅 Enabled 时执行，StartDelay≈0 立即，否则协程延迟。Stop **0x06014A7A** 只在 Enabled、source存在、非PlayGlobally、StopOnStateChange=true 时停止。PlayGlobally 是独立复制声源，不能按本地 source 同样取消。
- 弹道命中：`SuperSpell.OnMissileTargetReached` **0x06014B28** 先 SpawnImpact，再链式/顺序后续弹道；`WaitAndSpawnImpact.MoveNext` **0x06014B8B** 先随机 SpawnDelay，再 targetIndex*SpawnOffset，按 GameDelay 推进 metadata tasks，然后克隆/激活 impact prefab。**这个通用方法本身不足以证明某张卡的毫秒时刻或“伤害/死亡必须先后”的全部顺序，仍须看该卡 prefab 与具体任务。**
- `AnimationEventSfxPlayer.PlaySFX/PlaySfx` **0x0600663A / 3B** 也可由动画事件对象引用播放 SoundDef 或 AudioClip，应保留这些分支，不把其声音强塞进通用cast。

## 死亡声音的批次抑制

`DeathSpellController.OnProcessTaskList` **0x0601164E** 先 PickDeathSoundCardIndex，循环中对其余目标 SuppressDeathSounds(true)，再各自 ActivateCharacterDeathEffects。抑制的是那张卡的整个 DeathEffect soundSpells，不只 VO category；视觉死亡仍进行。

`PickDeathSoundCardIndex` **0x06011651**：
- 一个目标：CanPlayDeathSound 才选索引0，否则−1。
- 恰好两个互杀目标：优先被攻击者；被攻击者不可播则直接选攻击者，**不再次检查攻击者 CanPlayDeathSound**。不能在此分支之前统一过滤 eligible；两个均被382/959排除时仍可能选攻击者。下游 ActivateCharacterDeathEffects/ActivateSoundSpell 没有再检查382/959，另有1075 CARD_DOES_NOTHING gate。
- 其余：`PickRandomDeathSoundCardIndex` **0x06011653** 在可播目标索引列表中均匀随机一个，无候选为−1。
- `CanPlayDeathSound` **0x06011654** 排除 DEATHRATTLE_RETURN_ZONE(382) 与 SUPPRESS_DEATH_SOUND(959)。
- `WasAttackedBy` **0x06011652** 检查攻击者 ATTACKING(38)、防守者 DEFENDING(36)、防守者 LAST_AFFECTED_BY(18)==攻击者 EntityId。

## 随机、实例限制与优先级

- `SoundUtils.GetRandomClipFromDef` **0x0601481D**：总权重 S，r=Unity.Random.Range(0,S)，累计前 N−1 项；r<=累计权重就返回，没命中返回最后一项。没有 shuffle 或 no-repeat 状态，没有过滤0权重。全0且N>1会选第一项；N=1选唯一项。负权重没有防护，源数据应原样记录而不要声称引擎自动修正。
- `SoundManager.LoadClipForPlayback` **0x0601475D**：随机列表的非null结果优先，其次 SoundDef.m_AudioClip，再次现有 AudioSource.clip。
- volume **0x06014767** = codeVolume × sourceVolume × 随机defVolume × categoryVolume × duckingVolume；pitch **0x0601476A** = codePitch × sourcePitch × 随机defPitch。Def随机volume/pitch为 Unity.Random.Range(min,max)。
- `SoundManager.PlayImpl` **0x06014791** 以 AudioSource.gameObject.name 作为 instance-limit key。max<1钳到1，duration<=0用clip.length。计数是从实际播放调用开始的时间窗，不是“仍播放”计数。
- `EnableInstanceLimitedSound.MoveNext` **0x060147E5** 每帧减deltaTime，时间窗结束计数−1。
- LimitMaxOutOption: 0=SKIP_NEWEST，1=STOP_OLDEST。0超限拒播；1调用 `FinishFirstGeneratedSourceByName` **0x0601479B**。**该函数实际从 generatedSources.Count−1 倒序找首个同名 source 并Destroy/RemoveAt即返回，不应仅凭枚举名假设FIFO。**
- 全局 clip 限制 `ProcessClipLimits` **0x0601477A** 来自 SoundConfig.m_PlaybackLimitDefs；只统计播放进度 time/length<=该clip ExclusivePlaybackThreshold 的活动source。达上限时，若有低于新声priority的可替换候选则停止该候选，否则拒播。源码候选筛选同时要求更低priority及更小播放进度，并非简单排序“最低优先级→最旧”。
- 已取得真实 SoundConfig：`SoundConfig.prefab:cd41c731c777d4f468b79ffa365a9f94`，Initialize协程 **0x060147F7** IL_002a引用。资源为 essential_base_global-prefab-0.unity3d / pathID -8607417786929617192，原 typetree见 `../audio_assets_evidence/SoundConfig_-8607417786929617192.json`。完整750组，按当前真实clip GUID匹配的子集见 `relevant_playback_limits.json`。已播放比例**超过** exclusive threshold 的source既不计数也不停止，可以和新source重叠。当前匹配组均priority0，组内窗口内达限就拒播，不是手工按文件去重。

## 现代英雄皮肤条件音不能当作基础法术音

Fireball/Frostbolt等 CardDef 的 m_SoundSpellPaths 包含现代英雄皮肤触发 VO。资源中例子是 CardSpecificVoSpell，其 base m_CardSoundData.AudioSource 为 null。

`CardSpecificVoSpell.DetermineBestAudioSource` **0x06011DB2**→GetBestVoiceData **0x06011DB3**，按 list 顺序找首个 SearchForCard 成功的候选。`IsCardInZones` **0x06011DB5** 要求非0 RequireTag 的 GetTag==TagValue，非空 CardId 要求完全相等，两条件 AND。全部失败回 base source；null 即不播。GAME_TAG 2839=EMOTECHARACTER。例 Fireball Gnome层要求 EMOTECHARACTER=513。m_SideToSearch=3 是施法源同侧（SpellUtils.ConvertSpellSideToPlayerSide **0x06014AB3**），不是固定屏幕左侧。基础Jaina/Guldan不能无条件借用这些皮肤语音。

## 文件使用与核验边界

- `final_core.cil.json/txt`：标准化 IL 分支标签的 Card、Spell、SoundManager、SoundUtils、DefLoader 主体。
- `closure.cil.json/txt`：CardEffect、weighted clip字段、impact/限流协程。
- `deeper.cil.json/txt`：DeathSpellController、SpellUtils、SpellManager。
- `conditions.cil.json/txt`：条件 VO 子类、动画事件、AliasedAssetResolver。
- `event_callers.txt` + `callers_*.json`：从 DLL token 字节定位候选后再次解析 CIL 验证的真实调用点，不是字符串相似匹配。
- `metadata_closure.json`：枚举常量与相关继承关系。
- `core/binding` 为早期原始导出，分支 operand 数字含method header，勿当method-relative IL标签；call-site偏移与token无误。

本目录不修改游戏脚本。原型实现应明确保留自身混音预算、简化动画/规则时序等差异，不以几段通用音宣称完整原客户端复刻。
## 补充闭包：预瞄、PlayMaker、标准actor与英雄技能

### Start Birth不等于所有卡刚拾起

`InputManager.UpdateTargetingArrow` **0x060059D2**, IL_00fc–010b 使用 UniversalInputManager.InputHitAnyObject(camera, layer12) 的布尔值调用 HandleUpdateWhileHoldingCard。后者 **0x06005A13** 在有目标、非随从、尚未目标箭头等检查后，NotifyOpponentOfTargetModeBegin → CreateFriendlyTargetArrow → ActivatePowerUpSpell → IL_00f1 ActivatePlaySpell。`ActivatePlaySpell` **0x06005A18** 仅当前play spell状态None时激活Birth。

无目标法术的 `DropHeldSpellLikeCard` **0x06005A26** 在 HasResponse、DoNetworkResponse、AddLocalZoneChange、PredictSpentMana 之后 IL_013f 激活同一 Birth。故有目标法术从进入预瞄时开始Start子spell；无目标法术从commit开始。`SuperSpell.CheckAndWaitForStartPrefabThenDoAction` **0x06014B16** 还支持执行时缺少Start的fallback，不能因无玩家预瞄漏音。见 `callers_06005a18.json`、`callers_06005a13.json`。

### PlayMaker动作不是同一种源生命周期

`Spell.BuildFsmStateMap` **0x0601496A** 解析global transition的EventName到SpellStateType；`ChangeFsmStateNow` **0x06014970** IL_003c–0048把状态枚举名转字符串并 PlayMakerFSM.SendEvent。资源中Birth/Action/Death确有此代码入口，内部FINISHED链必须继续追状态图。

- `AudioPlayAction.Play` **0x06016AA0**：m_GameObject上的AudioSource；无OneShotSound则直接SoundManager.Play该source；有SoundDef则PlayClip(args,true,null)生成副本。其Delay协程 **0x06016AA5** 先等delay，再等待source inactive才发FinishedEvent/Finish。
- `AudioPlaythroughAction.Play` **0x06016ACA** 类似上条选源，但调用后立即FinishedEvent/Finish，不等待整段音频播放。Delay协程 **0x06016AD0** 只等delay后调用Play。
- `AudioPlayClipAction.Play` **0x06016AAF** m_Sound只接受SoundDef；template可空，args接受volume/pitch/spatialBlend/category等显式覆盖，PlayClip(args,true,options)后立即Finish。
- `SoundManager.PlayClip` **0x06014735** 的第二参数true明确调用 GenerateAudioSource(template,def)，是新的generated source。不能把CardSoundSpell重入Stop规则套到所有FSM层；已有source、generated source、父对象销毁/显式AudioStop分别处理。
- `SpellCardIdAudioAction.GetClipMatchingCardId` **0x06016CA0**：按Which取card，不存在返回null；cardID在m_CardIds无匹配则m_DefaultSound，否则m_Sounds同index。`SpellAction.GetIndexMatchingCardId` **0x06016C8E** Trim列表项后OrdinalIgnoreCase比较，首项匹配优先。
- `SpellCardIdAudioPlayAction.Play` **0x06016CA6**：source缺失或selected SoundDef null直接Finish返回，**绝不fallback source原SoundDef**；有selected def才PlayOneShot(source,def,volumeScale)。因此特殊cardID不匹配且default null的分支是静默，不可误播替代卡声音。

对应 `fsm_actor.cil.*`、`fsm_delays.cil.*`、`fsm_choices.cil.*`、`input_audio_edges.cil.*`。

### 动作层随机与SoundDef层随机不同

`AudioPlayRandomClipAction.ChooseClip` **0x06016ABB** m_Weights为null/空时直接第0项；非空调用外部 `HutongGames.PlayMaker.ActionHelpers.GetRandomWeightedIndex`。AssemblyRef精确指向 **Blizzard.T5.PlayMaker.Runtime**，不是仅凭名字找到的PlayMaker.dll。

同build `Blizzard.T5.PlayMaker.Runtime.dll` 已原CASC验证恢复，旁有provenance。其helper **0x06000054**：S=sum(weights)，r=Unity.Random.Range(0,S)；依序若r<weight（严格小于）选该项，否则r-=weight；遍历完返回−1。全0返回−1，负权重无修正。caller只检查index>=sounds.length而无负index防护，异常数据可能抛索引错误；原型如采用安全静默须标为兼容边界，不能声称原版全0取第一。**不要与SoundUtils的<=累计权重/最后项fallback合并。**

ChooseVolume **0x06016ABC** / ChoosePitch **0x06016ABD** 各min/max缺值默认1，Mathf.Approximately则取min，否则各自Unity.Random.Range。动作先选SoundDef，再由SoundDef独立选clip及volume/pitch。证据 `playmaker_helpers.cil.*`。

### FINISHED与动画/计时

下列tokens属于 Runtime.dll：
- AnimateFloat.OnEnter **0x060000BC** endTime=curve最后key.time，looping取postWrapMode；OnUpdate **0x060000BD** currentTime>=endTime时，非looping先Finish，再有finishEvent则Fsm.Event。**显式FINISHED可以在其他并行动作未完成前转状态，不是并行动作最长时间。**
- Wait.OnEnter **0x06000D9D** time<=0立即Event+Finish；OnUpdate **0x06000D9E** timer>=time Finish再发送非null finishEvent。realTime=true用RealtimeSinceStartup差，否则累计deltaTime。
- PlayAnimation.OnUpdate **0x0600014D** 在AnimationState disabled，或wrapMode8且time>length时发finishEvent并Finish；length必须沿引用AnimationClip读取，不能凭Take001命名猜。
见 `fsm_timing_runtime.cil.*`。

### 标准随从actor与物理接触

`Actor.m_spellTablePrefab` **0x0400F755** 是字符串。AssignSpells **0x06012986** 优先local child SpellTable，否则完整assetRef→SpellManager.GetSpellTable。LoadSpell **0x0601294C** 优先Card override、CardDef override、CardSet DBF override，最后shared table。

标准minion actor实际引用 `Card_Play_Ally_SpellTable.prefab:81be4c58f5a9d454e815f1b0703d8179`；原表见 `standard_minion_actor.json` / `standard_minion_spelltable.json`。GetActorAttackSpellForInput **0x06012DAF** type17；生成随从type26友方/31对方；death type5。HandToPlayIn **0x06012E9C** 非gold/non-special按EntityDef基础cost：<4友2敌42，4–6友24敌68，>=7友25敌69；Out **0x06012E9D** 友1/22/23，同档对方统一1。

物理contact不是type17的挥击音：`PowerProcessor.CreateAttackSpellController` **0x06006004** IL_0000 确切加载 `AttackSpellController.prefab:12acecc85ac575e43b87ec141b89269a`，可被GameEntity.GetAttackSpellControllerOverride替换。`AttackSpellController.DetermineImpactSpellPrefab` **0x06011620** 按攻击方GetATK选择m_ImpactDefHandles；普通构筑不是critical，WasAttackCriticalHit **0x06011621** 只涉及Lettuce职业克制。选择结果空/路径空则m_DefaultImpactSpellPrefabHandle。

`SpellUtils.GetAppropriateElementAccordingToRanges` **0x06014AE0** 按数组顺序首个min<=ATK<=max；超全部max选max最大项，低全部min选min最小项，内部gap返回null。此为数值分档，不是随机挑impact。见 `attack_contact.cil.*` / `callers_7008fb01.json`；精确prefab闭包由资源报告补充。

### 基础英雄技能新旧ID

Constant表证明 GAME_TAG.HERO_POWER=380。资源侧原DBF：HERO_08 dbfid637 tag380=807；HERO_07 dbfid893 tag380=300；CARD表将807/300映射为HERO_08bp/HERO_07bp。应按稳定DBFID/英雄关联追实际CardDef，不可擅自把CS2_034_H1或CS2_056_H1当基础英雄。各H变体的SpellPath确有差异。参照资源侧DBF/carddef证据。

## 最后核验与容易误读的边界

- 当前实际使用类别已由资源侧 `used_sound_categories.json` 核到仅FX=1与VO=3。39角色槽中36为VO，镜像3槽为FX。原枚举AMBIENCE=6、MUSIC=2（SPECIAL_MUSIC=7、HERO_MUSIC=9）；不要把角色自动改VO。普通VO只duck环境6，不duck音乐2或FX1。本原型若只有music且无ambience，普通台词不会导致BGM降低。完整算法/用户音量映射与边界见 `ducking_category_report.md`，原配置副本见 `ducking_config.json`。
- `GenerateAudioSource` **0x06014797** 将GO命名为 `Audio Object - {Path.GetFileNameWithoutExtension(SoundDef.m_AudioClip)}`；def null才用CreatedSound。不是FSM宿主/模板GO名，也不是随机选中的clip名。生成source在本函数先Add进generatedSources，然后PlayImpl再检查instance limit，所以STOP_OLDEST逆序查找可能删新source自身；任何安全化处理必须标为兼容差异。
- AudioPlayClipAction明确的m_TemplateSource=null时，GenerateAudioSource只使用SoundConfig.m_PlayClipTemplate，绝不能继承附近/同GO另一AudioSource的Loop。硬币Start音和同prefab循环音必须分开。
- `SelfAnimUtils.PlayDefaultSound` **0x06015511** 无参，TryGetComponent取得自身GO AudioSource再SoundManager.Play，不读取AnimationEvent.objectReference。标准AttackLaunch的time0动画事件由该实际附着source定位。
- `Spell.Activate` **0x06014939** → GuessNextStateType **0x06014959**。None初态按首个usable Birth→Idle→Action→Death→Cancel选择，不是最短entry路径；OnStateFinished后Birth仅试Idle、Idle仅试Action、Action仅试Death，无可用则None，不在后续全序跳跃。仅Death有内容的impact可以初次直接Death。Game.dll SpellBase对应方法是abstract，实际override在Assembly-CSharp。
- `SuperSpell.OnMissileTargetReached` **0x06014B28** 调SpawnImpact（仅StartCoroutine，不await），随后立刻SpawnMissileInSequence。因此奥术飞弹下一发spawn在前一发arrival时开始，不等待前一impact的GameDelay完成；各自delay/path仍独立。
- PlayMaker.dll `Fsm.GetState` **0x060004BD** 从states index0起按Name精确比较，首匹配返回。InitData **0x06000488** 用同GetState解析local/global transition的ToFsmState。冰霜新星有重复state name，必须保留state_index并指向首项，不能把同名状态的动作合并为多层。
- 精确 `RandomWaitAction` 位于 **Blizzard.T5.PlayMakerCustomActions.Runtime.dll**，不是Runtime.RandomWait。OnEnter **0x060000F7** 只有min<=0且max<=0时立即Finish+Event，否则随机等待；OnUpdate **0x060000F8** updateTime>waitTime（严格大于）才完成。两类均有独立CIL文件，不能名称近似代替。
- Runtime `EaseFsmAction.UpdatePercentage` **0x060000FE** speed IsNone时runningTime+=dt，否则+=dt*speed，percentage=runningTime/time。delay IsNone=0；起跑存在按帧推进，EaseColor **0x060000F3** 在base finishAction后下一帧发finishEvent。因此用time1重建名义1秒应保留帧量化边界。
- `AudioVolumeFadeAction` **0x06016AFC/FD** 读SoundManager.GetVolume **0x06014725** 的ext.m_codeVolume，Mathf.Lerp到target，再SetVolume **0x06014726**写codeVolume；不是绝对AudioSource.volume。AudioSetVolumeAction **0x06016AE8**也同样写乘数，变量IsNone不改。FadeTime<=Epsilon直接Finish，不强设target；结束按StopWhenDone停止。m_RealTime=true分支原代码有absolute/relative时间混用，不以推测修正。
- `AnimationPlaythroughAction.OnEnter` **0x06016A80** StartAnimation后立即Finish，不等待clip长度；SpellInitActorVariables **0x06016D0A**赋引用后立即Finish。它们与Runtime.PlayAnimation等待完成不同。
- Legacy AnimationClip的m_MuscleClipSize=0时，MuscleStopTime=1可能为空结构默认，不能当实长。按强引用legacy曲线末key重建是可审计依据，但原Unity native length算法未在managed DLL中恢复，不能标成原运行时实测。官方公开C#源同样只暴露native getter：[AnimationClip.bindings.cs](https://github.com/Unity-Technologies/UnityCsReference/blob/master/Modules/Animation/ScriptBindings/AnimationClip.bindings.cs)。实现按曲线边界使用时须标 `legacy_curve_bounds_reconstruction`。

上述新增证据分别在 `playmaker_fsm_core.cil.*`、`playmaker_transitions.cil.*`、`custom_action_timing.cil.*`、`ease_runtime.cil.*`、`ease_base_runtime.cil.*`、`fsm_volume_actions.cil.*`、`actor_animation_timing.cil.*`、`selfanim_sfx.cil.*`、`animation_enums.json`、`audio_constants.json`。

## 最终增补索引

`late_closure_report.md` 汇总限定本卡池的最后核验：恶魔卫士本地友方RESOURCES下降→默认晶体gemDestroy的真实声源；Fireball零延迟仍跨协程帧；Area单实例；手牌Out完成后才In；友敌attack与hidden手牌的独立actor绑定。新增CIL与caller文件同目录，逐方法token在报告中。资源侧最后行见 `../audio_assets_evidence/mana_destroy_audio_bindings_resolved.json`，其中声源在Action→State2→FINISHED→State3后播放，前置显式FINISHED计时0.5秒，不是战吼一开始即响。

普通未揭示敌手牌路径由ActorNames.GetZoneActor **0x060129E6**（HAND分支IL020C–023F）证明：controller.IsRevealed或forceRevealed为false时选Card_Hidden.prefab:1a94649d257bc284ca6e2962f634a8b9；其out type1应取隐藏actor表，不能自动复用友方Card_Hand_Ally表的type1。

隐藏敌方Out的最终闭包已完成：原HiddenSummonOut根无音频，CardBackSummon **0x06001B73** 仅更新m_HiddenCardEchoTexture贴图，没有补充加载/播放路径。见 `hidden_cardback_summon.cil.*` 和 `late_closure_report.md`；不要复用友方Out音。
