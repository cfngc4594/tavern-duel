# v31 原版普通随从召唤：静态代码证据与实现契约

## 结论

原流程是同一个 Card 父对象下的 **手牌 Actor / 在场 Actor 交接**，不是把卡牌矩形替换成一张椭圆纹理。旧 Actor 的离手动画与其 Spells 子层共同播放；新 Actor 先隐藏，Out 的完成回调同步显示并激活 In；In 完成后才恢复 Actor-ready/input。Card 父对象归槽与局部 Actor 动画是两条并行动作。

已交付 `runtime_routes.json`：10 条普通、非金色、非钻石、非传说共享路线的逐状态进入时刻、原 action 顺序、启用/禁用区别、clip 强引用、粒子启停目标和可验证的时长依据。`build_runtime_routes.py` 从本目录的原 FSM 与资产闭包重建该表。每条route显式列出unresolved_serialized_parameters；这些位置仍保留decoder占位，不能把表误认为已经完整实现所有PlayMaker action，也不能将占位当成默认值。这里的名义时间是静态连续时间重建，不是原客户端录像测量。帧调度、原生 Legacy AnimationClip.length 与 Unity 粒子求解器仍是明确边界。

本次没有运行、登录原客户端，没有修改 v30，没有操作用户 Mac，没有修改生产项目。源码报告写入本目录；资源和 Godot 实现由相应工作区独立完成。

## 版本与工具归因

- 客户端构建：37.0.0.255130.254477。
- Assembly-CSharp.dll SHA256：`7f81d2ab2277958dea4351c41812921a00ee263a6a7abf1a5cfb4eb0794f26e5`。
- Assembly MVID：`7ceffc8b-6ddc-428e-9839-55861bcfe292`。
- 实际运行隔离安装的 REA 6.8.0 CLI，无 MCP 注册/设置修改。
  - `inspect-managed-members Assembly-CSharp.dll --type HutongGames.PlayMaker.Actions.SpellFinishAction --detail summary`：生产者仍受 67,108,864 字节表示预算限制，扫描到 offset 9866240 为 partial/resource-limit。输出有类型摘要，但没有方法体；不能把未返回方法解释为不存在。保留 `rea_spell_finish.summary.json`、`rea_spell_finish_bundle` 和 stderr。
  - 对同构建 UnityEngine.ParticleSystemModule.dll 的 ShapeType/SimulationSpace/ScalingMode 精确类型查询成功，3 types、30 fields，producer coverage complete。保留 `rea_particle_enum.*`。
  - 对原 Blizzard.T5.iTween.dll 的 Defaults/EaseType 查询成功，2 types、51 fields、1 method、226 member refs，producer coverage complete。保留 `rea_itween_defaults.*`。
- 游戏主流程的完整 CIL 来自 dnfile + dncil 只读解码，不冒称为 REA 的完整反编译结果。`dump_cil.py` 保留 token、方法参数、规范化方法内 IL offset。原 v30 的声音/FSM 运行时代码证据直接复用，不重新下载主程序集。
- 为核实粒子枚举只取同构建一个 UnityEngine.ParticleSystemModule.dll 到本目录 `managed/`，160,768 bytes，SHA256 `e42be0a7f5c563a2a557b106e952352691a5c2bf1f477f36c7be56bbb37e7192`，MVID `791ebe36-31a7-4913-a697-9253fd3bb7c5`。CASC 来源证明与枚举 Constant 表在旁边。

## 调用链与生命周期

本节方法均在 Assembly-CSharp.dll，除特别注明。

1. `Card.OnActorLoaded` 0x06012E10：保留 oldActor，把新 prefab Actor 赋给 m_actor，绑定 Entity/Card/CardDef 并更新组件，进入 FinishActorLoad。
2. `Actor.SetCard` 0x060127F5：Actor.transform 设到 Card.transform 下，并 identity Actor 以及其 RootObject 子节点。RootObject 是 Actor 内部另一层，不是整个 Actor 的同义词。
3. `Card.FinishActorLoad` 0x06012E11 → OnZoneChanged / OnActorChanged。实际 `Card.OnActorChanged` 0x06012E38 的 Hand→Play 分支在 IL06EF 激活 HandToPlay spells，IL0720 播放 character play effects，IL072B 隐藏新的在场 Actor。因此专属打出 VO 对齐 Out 开始，不是 reveal/落地。
4. `Card.ActivateActorSpells_HandToPlay` 0x06012E50：在 oldActor 取 Out，关闭输入，Spell.SetSource(Card GO)，登记 Out-finished 回调 0x06012E51 与 state-finished 清理回调 0x06012DCA，激活 Out。
5. `Card.OnSpellFinished_HandToPlay_SummonOut` 0x06012E51：触发名为 HandToPlaySummonOutStart 的静态事件（名字容易误导，实际发生在 Out 完成回调），Show 新 Actor，取 BestSummonSpell，登记 In-finished 回调并同步 Activate In。未找到在这两步之间新增等待。
6. `Card.OnSpellFinished_HandToPlay_SummonIn` 0x06012E53：重置新 Actor 的 RootObject 子层 localPosition/rotation/scale，Show Actor，m_actorReady=true，m_inputEnabled=true，恢复 state spells，RefreshActor 并派发相关 board 事件。
7. `Card.OnSpellStateFinished_DestroyActor` 0x06012DCA 只在 spell active state 为 None 时清理旧 Actor。Out 的逻辑完成与旧 Actor 最终销毁是不同锚点，旧 Actor 清理可晚于 In 开始。

`SpellFinishAction.OnEnter` 0x06016CDD 的 delay=0 直接调用 Spell.OnSpellFinished 后结束该 action，但不会替 FSM 换状态。`Spell.OnSpellFinished` 0x0601495F 触发 finished callbacks。`SpellStateAction.OnEnter` 0x06016D21 → `Spell.ChangeStateImpl` 0x0601496C，在 None 状态通过 `FinishIfNecessary` 0x06014971 补发完成，然后通知 state callbacks。这解释了某些 prefab 没有启用 SpellFinishAction 仍能完成。

## 对象、坐标和资源绑定

- `SpellInitActorVariables.OnEnter` 0x06016D0A 的 IL0017 取 Actor.gameObject 给 FSM 的 Actor 变量；RootObject 另取 Actor.GetRootObject。因此 AllyInHandDeath / AllyInPlaySpawn 的 path="" 绑定整个 Actor GO，不能错误绑定 RootObject 子层。
- `Actor.GetSpellParent` 0x06012987 创建 `ActorGO/Spells` 并保持局部 identity。`Actor.LoadSpell` 0x0601294C IL014F–0161 用 AttachAndPreserveLocalTransform 挂到该节点。因此 Out 光层跟随旧 whole Actor，In 光层跟随新 whole Actor。
- `SpellUtils.SetPositionFromLocation` 0x06014AB9 可按配置写世界位置；本次 Out/In m_Location=2、m_SetParentToLocation=0、m_Facing=0。location 2 经 `FindSourceAutoObjectForSpell` 0x06014AD0 取 source Card 的自动目标。不能因为看见 world-position setter 就丢掉父层关系。
- Medium In 在 NONE 分别把 Dust GO 和 Ring GO SetParent(null, worldPositionStays=true)，并非把整个 effect prefab 根移出。2.5 秒后 Reset 再分别归入 GameObjectContainer 并按原数据重置局部位置。
- `ZonePlay.UpdateLayout` 0x060065C2 在 **Card GO** 上并行 iTween ScaleTo/RotateTo/MoveTo，目标是槽位世界位置、zone 世界 Euler、zone localScale。使用 m_transitionTime 和 Card.GetTransitionDelay，随后清 delay；transition style 3 可直接 warp。`ZonePlay::.ctor` 0x060065C8 初始化 transition/baseTransition=1.0，但其他路径可覆盖，不能宣称全局恒为1秒。
- 原 iTween Defaults::.cctor 0x060000C7（Blizzard.T5.iTween.dll）默认 easeType=16=easeOutExpo、isLocal=false、delay=0。Card 归槽和 Actor 局部动画应并行，不在两阶段间额外再加1秒等待。
- Enemy Hidden Out 的 iTweenMoveTo space=1、vector=(0,6,0)、time=.400000006、easeType=1=easeOutQuad。CustomActions DLL `iTweenMoveTo.DoiTween` 0x06000176 IL0237–024A 明确写 hash["islocal"]=(space==1)，因此该目标是 Actor 相对 Card 父层的局部坐标。

### Actor 和效果精确指针

- 手牌 Actor：`Card_Hand_Ally.prefab:d00eb0f79080e0749993fe4619e9143d`，root -2189759849338270441，Actor component -1220407657622958825。
- 在场 Actor：`Card_Play_Ally.prefab:23b7de16184fa8042bf6b734e7ca4d60`，root 7379369862269225637，Actor 7287244737665747621，Animation 3295927845469670053。
- Hand spell table：`Card_Hand_Ally_SpellTable.prefab:78c9e9fcc292c4a82b35e4b168fb5200`，table1477533857961769828。
- Play spell table：`Card_Play_Ally_SpellTable.prefab:81be4c58f5a9d454e815f1b0703d8179`，root4419985310648997347，table403896241657845219。
- Medium Out：`Card_Hand_Ally_SummonOut_Medium_PM.prefab:7106ac4b00cca44a6a998fd151491481`，CAB-865f43f611eb20762339650558784e7a，root-7917689932185229882，FSM8385085178671179206。
- Medium In：`Card_Play_Ally_SummonIn_Medium_PM.prefab:b66403dbb17e349b7a74ccac69286f92`，CAB-824a57d31e8915d6162164fd62a4305d，root5281707505601633298，FSM-6285828585279628270。
- Medium Out 3 个真实 mesh 层：ScryLines GO1259913617868694982，ScryingRays GO5370805469513885126，flashPlane GO-6423421601965955642。
- Medium In：Dust GO-8450156401545552878，ParticleSystem3033875876025097234；Ring GO-3351224058537157614，mesh-6044985309228213230；GameObjectContainer3122365760464313362。
- 两个普通 Actor 的 m_portraitMeshRTT / m_portraitMeshRTT_background 均为0。当前证据支持原 mesh/material 渲染，不支持声称存在一个已恢复的 RTT 矩形→椭圆 morph。

更多全部 route 的 prefab GUID、CAB/path 与 clip 指针见 `runtime_routes.json` 和资源 manifest，不凭名称猜测外部依赖。

## 选档

`Card.DetermineSummonOutSpell_HandToPlay` 0x06012E9D 与 `DetermineSummonInSpell_HandToPlay` 0x06012E9C 使用 **EntityDef 的基础费用**，不是本次支付费用、当前攻击力或稀有度：

- 友方 <4：Out1 / In2。
- 友方4–6：Out22 / In24。
- 友方>=7：Out23 / In25。
- 敌方 Out 始终1；In 分别42/68/69，但普通 Play spelltable 中这三项都指向相同 `Card_Play_Ally_SummonIn_Opponent.prefab:b68ecaea3f52740beac5429761699e02`。
- 金色、钻石、快速播放和自定义 spell 等分支存在，本表不假装覆盖。
- CS2_182 的 CardDef customSummon/customSpawn 为空、SpellTableOverrides为空、suppressPlaySoundsOnSummon=0，因此使用中档普通共享路线。顺带核对 EX1_301、CS2_033 同样无自定义覆盖。

## 时序锚点与效果差异

### CS2_182 友方 Medium

Out 初始通过 ELITE tag114=0 的 non-elite 分支（状态名 Dragon? 不代表按龙种族选档）。原状态序列1→6→5→7。

State7并行启动 ScryLines/Actor Death/GlowOn/RaysUp、音效、Wait.8、HighlightIntensity。HighlightIntensity 原曲线(0,1)→(1,0)，双端切线-1，末尾显式 FINISHED；它使1秒进入 state3，而不是等待音频或所有动画最长者。state3隐藏旧Actor/光层，立刻 SpellFinish0 开始 In；另外 Wait1 秒后才进 NONE 清理旧 Actor。

In state1 播 whole Actor `AllyInPlaySpawn_Med`（clip8227446253133355781，末key .366666704416275），ring `AllyInPlay_SummonGlow_Med`；在 .3499999940395355 延迟 Invoke CameraShaker.StartShake。Actor clip发 Action 进入state3音效，再到NONE。在NONE触发 In-finished/readiness，同时启动Dust、显示Dust/Ring并分别脱离父层保持世界位置，2.5秒后Reset。

因此连续时间重建：Out1.0；In约.3666667044；总ready约1.3666667044；shake约1.3499999940；尾迹从In完成另计2.5秒。旧actor清理2秒的等待不得串进ready时间。

### 小费友方

Out普通 state5同时播放Scry/Actor Death，并 ParticlePlay GO6538087048048279305。1秒 state3仅隐藏 RootObject/Highlight，并SpellFinish0；不是medium那种递归隐藏整个effect。2秒NONE才关闭分支根。

In t0启动Actor `AllyInPlaySpawn`（clip-8105555823431109035，末key.4833333790）及 ParticlePlay GO-18238306004689792。不是等待该clip结束，而是state4 Wait.5。t.5进入KillDustPlaySound，依次Play GO-6620779850417365888、SpellFinish0、Stop GO-18238306004689792、Play GO9016756839510580352，includeChildren都false，再留2秒尾迹。不能把三个粒子一起在落地时启动。

### 大费友方

Out State7的 RaysUp 是 PlayAnimation 且 finishEvent=FINISHED，clip-7396112192722396626 的末key .9166666865348816，早于 HighlightIntensity 的1秒事件。进入Sub_Birth2隐藏后立即NONE补发finished，没有中档的额外1秒清理Wait。因此不能机械套用medium1秒。名义gate取先发生的显式FINISHED。

In仍用AllyInPlaySpawn_Med，但Dust在Birth便开始，ring/颜色等资产不同。NONE含Wait3.5（没有显式finishEvent）与RemoveAfterDelayAction waitTime3.5999999并行。其OnEnter0x06016C15/WaitAndRemove.MoveNext0x06016C1A从不调用FsmStateAction.Finish，而是独立GO coroutine使用WaitForSecondsRealtime后Destroy列表。SetMaterialColor everyFrame=true也持续。最终从现有raw FSM6855863801349825029的fsmArrayParams[0]及arrayVariables[list]核实gameObjectList，依次为SummonGlow_Lrg -8388383993393487355、SummonRingCracks_Lrg2652619807472771589、FX_Dust1_Lrg-3028280032139320827。三者在NONE后Realtime3.5999999秒Destroy，不能宣称3.5秒必进入TurnOffLeftovers；证据见large_cleanup_array_evidence.json。完整enabled/disabled及父层操作保留在runtime_routes；in_finished不受此尾迹边界影响。

### 敌方

Hidden Out Birth中Actor局部上移.4秒，GlowOn+Wait.5；随后隐藏Actor、ParticlePlay GO5201848174202404731、GlowOut+Wait.349999994；t.849999994的state4执行SpellFinish0，另Wait1.25清理。该Out无音频 action，不能杜撰敌方离手声音。

共享Enemy In t0启动Actor AllyInPlaySpawn和ParticlePlay GO5594884208522736127；t.4300000071525574，Play GO-2807441509357669889、SpellFinish0、Stop5594884208522736127、Play141865491118141951，留2秒尾迹。名义总ready1.2800000012秒。

### 生成随从 / token

`Card.ActivateStandardSpawnMinionSpell` 0x06012DBB：友方26、敌方31，没有手牌Out。随后立即ActivateCharacterPlayEffects。对应prefab GUID分别fd6035c3a26bd4d69817ff4f21436fe9 / ff1a0c7b2b7534ea883711094aa170e5。

Birth只启动glow FadeIn和AudioPlayAction，没有ParticlePlay。FadeIn clip2585133873067500320末key .6833333373069763；进入BirthSubState的SpellFinish0回调 `Card.OnSpellFinished_StandardSpawnCharacter` 0x06012DC1，回调内才Show Actor和设ready/inputEnabled，随后glow FadeOut（clip-3179693561874771139，末key .3499999940395355）。

不能把所有AudioPlayAction都当playthrough：它的Delay协程0x06016AA5等template AudioSource不活跃。但本两prefab template的clip=null/playOnAwake=false；指定oneShot SoundDef-1309217977194182999经 `AudioPlayAction.Play`0x06016AA0 → `SoundManager.PlayClip`0x06014735(createNewSource=true) → `GenerateAudioSource`0x06014797建新source，音效不会激活被等待的原template。因此fresh普通token名义ready由FadeIn约.6833333373决定，glow总约1.0333333313秒。泛化时应保留“FadeIn完成且template不活跃”的条件。

### 战吼

`<ActivateActorBattlecrySpell>d__379.MoveNext` 0x06012ED9 单独处理type33，要求ZonePlay且InputManager的battlecry source就是该Card，等待.01并再次检查。定向战吼箭头来自 `InputManager.DropHeldMinionLikeCard`0x06005A25 的目标流程。不能给所有普通随从或Yeti无条件叠加一个“战吼脉冲”。

## 曲线、粒子和相机精度

- Legacy transform/float曲线的key、inSlope、outSlope、weightedMode及阶梯Infinity都已在原Animation JSON。实现应按Hermite/原有step曲线采样，不把全部曲线改成统一ease，也不只取首尾做Tween。属性包含renderer.m_Enabled、material颜色/alpha、scale等，不能只驱动位置。
- `AnimationPlaythroughAction.OnEnter`0x06016A80 启动播放后立即Finish；`PlayAnimation.OnUpdate`0x0600014D（PlayMaker runtime）看AnimationState disabled或ClampForever/time>length才完成/发event。`m_MuscleClipSize=0`时附带的默认m_StopTime=1不能当真实legacy时长。所列时长标记为legacy_curve_bounds_reconstruction；未执行Unity原生length getter。
- 粒子枚举同构建元数据：Shape10=Circle；SimulationSpace0=Local、1=World、2=Custom；ScalingMode1=Local。原序列化 `moveWithTransform=1` **不是“跟随Transform=true”**，它映射SimulationSpace枚举，因此当前尘是World模拟；这是已给实现修正的重点。
- Unity官方编辑器源码把m_SimulationSpace绑定到serialized property `moveWithTransform`，选择项Local/World/Custom： https://raw.githubusercontent.com/Unity-Technologies/UnityCsReference/master/Modules/ParticleSystemEditor/ParticleSystemModules/InitialModuleUI.cs 。官方枚举对应： https://raw.githubusercontent.com/Unity-Technologies/UnityCsReference/master/Modules/ParticleSystem/Managed/ParticleSystemEnums.cs 。枚举数字又由同构建DLL独立核对，见particle_enums.json。
- 原CPU/native粒子求解器与随机状态未恢复。Godot固定步长/PCG是明确的兼容实现，不可称为Unity原随机序列或逐像素一致。
- Medium原CameraShaker amount xyz均.10000000149，曲线(0,1)→(.25,0)斜率-4，hold=false/override=false。StartShake0x0601508C取Camera.main，CameraShakeMgr.Shake0x06015081受option110控制；UpdateShake0x06015088每帧对xyz各自Random.Range[-amount*intensity,+amount*intensity]，写initial worldPosition+offset，终止恢复位置。不是正弦、旋转或自编屏幕弹跳。
- 缓存37个Camera经原资源核对，没有一个强引用证实为普通GameplayCamera。唯一非silhouette候选FOV36.5沿父链属于Choice_Dragon_FX_Reveal，已排除。项目15°投影仍必须标为Godot兼容映射，不能称已恢复原Gameplay相机。

## 交付文件索引

- runtime_routes.json / build_runtime_routes.py：可直接读取的10条状态调度与clip指针。
- Card_*.prefab.fsm.json：原启用action、参数与transition；不要忽略enabled=false。
- card_actor_spell.cil.*：Actor/Card/Spell/SpellUtils等完整CIL。
- key_methods.cil.txt：核心调用链摘录。
- spatial_runtime.cil.*：TransformUtil、CameraShakeMgr、SpellFinishAction、SpellStateAction。
- zone_input.cil.* / zone_defaults.cil.*：拖放/战吼/归槽与默认值。
- itween_move_action.cil.*：敌方本地坐标的明确hash参数。
- remove_after_delay.cil.*：大型尾迹清理动作。
- particle_enums.json、managed/*：同构建枚举及来源。
- rea_*.summary.json / *_bundle：真实REA结果和coverage边界。
- 复用v30：audio_code_evidence/fsm_timing_runtime.cil.*、fsm_actor.cil.*、fsm_delays.cil.*、core.cil.*；audio_assets_evidence/legacy_clip_durations.json、shared_effect_prefabs.json、hand_effect_prefabs.json、standard_hand_actor_spelltable.json。

## Godot事件接口建议

`out_start`：保留旧hand actor、隐藏new actor、关闭交互、启动原Out动作与打出VO；Card父归槽同时进行。

`out_finished`：严格由原SpellFinish或None补发条件触发，立刻开始`in_start`；不得等待旧actorcleanup。

`in_start`：显示new actor并从t0采样其原clip，按route调度粒子、材质、parent与camera动作。

`camera_shake`：原配置延迟触发，实际camera投影仍是兼容层。

`in_finished`：恢复ready/input、重置原RootObject子层，剩余glow/粒子尾迹独立运行，不阻塞玩家。

`tail_reset`/`tail_cleanup`：按route独立清理，不把medium的2.5秒套给small、large、enemy或token。

## 粒子实施交接补证

针对粒子运行语义补查现有缓存，没有新增下载或更改生产：

- `Blizzard.T5.PlayMakerCustomActions.Runtime.dll` 中 ParticlePlayAction.OnEnter 0x060000EE 调用 ParticleSystem.Play(withChildren) 然后立即 Finish；不会写 Emission.enabled，也不等待粒子结束。ParticleStopAction.OnEnter 0x060000F4 调用 Stop(withChildren) 然后立即 Finish。见particle_actions.cil.*。
- 同构建 UnityEngine.ParticleSystemModule.dll 的 Stop(bool) 0x0600005C 明确调用 Stop(bool,1)，1=StopEmitting，保留已发射粒子，不能用清空代替。Play/Stop最终进入Unity native注入接口，内部solver没有恢复。见particle_native_wrappers.cil.*。
- 已缓存模块的全部ParticleSystem枚举Constant扩展到particle_enums_extended.json，生成脚本dump_particle_enums_extended.py。MeshShape Vertex0/Edge1/Triangle2；UV Mode Grid0/Sprites1，TimeMode Lifetime0/Speed1/FPS2，AnimationType WholeSheet0/SingleRow1，RowMode Custom0/Random1/MeshIndex2。
- 当前Small/Enemy EdgeLandMotes原EmissionModule.enabled=false，虽然序列化数据里存在100+100的burst；不能由于看到burst就发射，ParticlePlayAction也不会自动开启该模块。
- 敌方Hidden Out FX_RedRays原renderer是Stretch1，LengthScale16.3199997，不是Billboard0或Horizontal2。须实现或明确列不支持，不能静默替换。
- 现旧solver的active曾由当前帧无vertices决定，这是实现缺陷；延迟发射/loop源应按未来发射或现有存活粒子保持活跃。任何粒子积分、dampen公式、RNG仅可声明兼容模型，不能冒称已经恢复Unity native公式。

## 普通手牌 Highlight 最终输入

原资源确认原Hand HighlightState组件1340673025259703575，RenderPlane GO-5364447331335434985，静态mask强引用`cab-cfdc5301ac0b17c5a76ad477fba38b57:-3103092934676384505`。新增精确CIL在highlight_runtime.cil.*：

- `HighlightState.RenderSilouette`0x06015297优先m_StaticSilouetteOverride，空则m_StaticSilouetteTexture。存在任一静态图时，调用GetBestSilouette0x06015296选择，然后IL00B5写Material.mainTexture。只有静态图均空才进入HighlightRender.CreateSilhouetteTexture的动态RT路径。
- 普通neutral非elite、无banner/rune/multiclass/quest的Yeti使用default静态mask。不能把prefab black32占位当最终_MainTex，也不需要为该路径发明RTT重绘。
- 同方法IL00BB–00C7明确renderQueue=m_RenderQueueOffset+m_RenderQueue。本组件是3000+50=3050。
- `HighlightState.Setup`0x0601528C设置currentState=1、renderer.enabled=false，用ShaderUtils.FindShader("Custom/Selection/Highlight")新建运行时Material；`ChangeState`0x06015293根据stateType匹配m_HighlightStates，CopyPropertiesFromMaterial后写_Seed并调用RenderSilouette。原prefab默认绿色材质本身不能证明提交时最终颜色。
- `_Seed`由Setup的UnityEngine.Random.value一次采样保存m_seed，ChangeState重复写同seed。
- `Card.DoOptionHighlight`0x06012DD2 IL0159–01B2：合法可打option且m_overPlayfield=true、m_overOpposingPlayfield=false的普通友方落场前分支调用SetActorState(8)。原Hand HighlightStates[8]对应`cab-3563ba8b89db13ca6eb196aa111591f1:4797490737768935072`（HighlightBlueOverBoard）。未越过board时普通可打state6为绿色，state7为悬停绿色。因此应保留交接前实际状态，不能给所有提交方式硬编码默认绿或无条件宣称都是8。HandToPlay方法本身没有重新选择Highlight材质。

### _ShaderTime 的真实producer

`shader_time_runtime.cil.*`中的`ShaderTime.UpdateShaderAnimationTime`0x06015547：

- enabled时，每Update执行m_time += UnityEngine.Time.deltaTime /20.0。
- 若m_time>m_maxTime则减一次m_maxTime；结果<=0时改为.0001。
- 最后Shader.SetGlobalFloat("_ShaderTime",m_time)。ctor0x06015549设maxTime65535、enabled=true，time默认0。
- disabled时每帧令time=1；Shutdown0x06015545写全局0。

这不是每次召唤的局部elapsed，也不是仅凭相似命名假设Unity内置_Time.x。迁移可实现全局累积delta/20服务时钟，并明确与原客户端绝对随机相位没有实测同步。

## UV辅助文档与当前活跃粒子范围

Unity官方当前编辑器[UVModuleUI.cs](https://raw.githubusercontent.com/Unity-Technologies/UnityCsReference/master/Modules/ParticleSystemEditor/ParticleSystemModules/UVModuleUI.cs)的114–120行将serialized startFrame与frameOverTime都以tilesX（SingleRow）或tilesX*tilesY（WholeSheet）重映射到UI帧数；它们的原序列化数值不能直接误读为整数帧索引。源码说明WholeSheet按左至右、上至下排列。该来源是官方非同构建编辑器辅助证据，同构建枚举已另取DLL验证，不能据此宣称native积分完全恢复。

当前普通路径实际使用：Small Out的Regular/FX_BlueRays PS6590410617251757833；Hidden Out RedRays8634348910119305083；Small In三个PS -7682783091912139648/7435642337723423872/-2728181926760604544；Medium In3033875876025097234；Enemy In -7228019221702331905/4501453343058080255/8078353505935208959。这些原组件playOnAwake均false，FSM显式Play驱动；Medium Out/token无粒子。Shape17 FX_CausticSoft属于未激活的Diamond分支，Evolution/Evaporate不在本普通路线prefab后代集合，不应因manifest里存在就自动发射。

状态选择边界：Card.DeactivateHandStateSpells0x06012D8A未直接重置Highlight，委托TagVisualConfiguration.DeactivateHandStateSpells0x06014BAB按标签配置执行动作，不是一个固定切绿操作。未实测所有输入方式与帧先后，因此state8是明确“普通合法卡最后处于友方board上”的分支证据，不是对全部提交方式无条件断言。补充摘录highlight_state_selection.cil.txt、highlight_handoff.cil.*。


## 本卡池补核：变形术不是普通 token 生成

结论：同一在场实体被 CS2_022 变为 CS2_tk1，不能因为卡 key 改变就套 StandardSpawn26/31。`polymorph_actor_handoff.cil.txt` 是原完整方法摘录，`polymorph_actor_handoff.json` 给出精确条件、分支与资产指针。

- `Card.OnActorChanged` **0x06012E38** 在普通非 Mercenary 的 Play→Play、oldActor!=m_actor 情况下，不命中初次生成分支；落到 IL1169–11D7：销毁旧 Actor，按已显示/zone 状态刷新 state spells，m_actorReady=true，再按 m_shown 调用 ShowImpl/HideImpl。没有调用 `ActivateMinionSpawnEffects` 或 `ActivateStandardSpawnMinionSpell`。若 Actor 实例相同，则 IL1057–10F3 的通常路径只恢复 ready（换边时可刷新 state spells），同样不是 token。
- `Card.ActivateStandardSpawnMinionSpell` **0x06012DBB** 才按阵营选26/31、绑 StandardSpawnCharacter callback，并调用 ActivateCharacterPlayEffects。OnActorChanged 中无旧 Actor/无 previous zone 的新实体生成，以及 Mercenary 特例不能套到普通绵羊变形。
- 原 CS2_022 CardDef `b6160ac6598452b48aa9f26501e0c5e9`，pathID -5679841957793983008，其 m_PlayEffectDef.m_SpellPath 明确是 `ReuseFX_TransformImpact_Minion_Arcane_Super.prefab:440eed6d453960b49bad9e13d81151f4`。这是变形术自己的效果入口，不是 Spawn26/31。原 CS2_tk1 的卡定义和声音存在，不能仅此推断 OnActorChanged 会触发普通生成声音。
- 迁移应分开“新实体 token”与“同实体变形”，后者保留 unit id/原槽位，明确为当前专属兼容交接。本次没有恢复该 TransformImpact 的完整原视觉/时序图，不能把 token glow/.6833秒说成原变形覆盖。全部为已有同构建 dnfile/dncil CIL 与已缓存 CardDef 的只读补核，未运行原客户端，也未再次冒称 REA 执行。


## Hidden Out 最后运行覆盖补核：CrossFade 与旧演员尾迹

`hidden_crossfade_lifecycle.json`及`.cil.txt`保存当前同构建证据。Hidden两次 AnimationPlaythroughAction 分别播放 Card_Hidden_GlowOn / 原拼字 Card_Hiddon_GlowOut，m_CrossFadeSec=.3000000119、m_PlayMode=4。StartAnimation **0x06016A81** IL0037–0057仅按 crossfadeSec>Mathf.Epsilon 选择 Animation.CrossFade，否则 Play；PlayMode只是透传参数。瞬切不等价，但该managed方法未恢复Unity native首次播放的参考pose、权重归一化及混合数学，Godot blend仍需标兼容。

Hidden .5秒 ActorSetVisibility(ignoreSpells=true)→Actor.HideImpl **0x06012842** 跳过HideSpellTable，只关闭RootObject等演员可视层。约.85秒 SpellFinish→**0x0601495F**只解锁/发finished callback；Out callback **0x06012E51**显示新演员并启动In，不销毁/隐藏旧Out。再等1.25到约2.1秒None，`OnSpellStateFinished_DestroyActor` **0x06012DCA**在GetActiveState==0时才调用Actor.Destroy，后者释放spell并Unity.Object.Destroy(go)。这些是名义scaled Wait时序，非原客户端帧测。

RedRays PS8634348910119305083在.5秒burst200，原life范围.8000000715–3秒，nonloop、rate0、delay0。因此.85时粒龄仅.35，早于最短life，此时一起隐藏Out会截断活粒子。应保留其模拟与可视性直到自然结束或原None清理；这不是声称每粒必须可见/存活到2.1秒。
