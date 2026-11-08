# v35 普通随从死亡：原事件链与落地边界

范围：原 build **37.0.0.255130.254477**，当前两副法术/术士牌及 token 共 30 个实体身份中的 13 个普通随从。只读程序集与同 build 原资产，不执行原 DLL，不启动原客户端，不操作 Mac，不修改规则或生产代码。

## 可以直接采用的结论

1. **角色死亡声在本体死亡之前激活，不等声音播完。** DeathSpellController 先选一张卡播角色声，再完成任务回调，之后才应用 zone 并启动各卡的 type5 本体。13 个原 CardSoundSpell 均 delay=0、blockServer=0、blockOnEnterDeath=0。删除旧的统一 hit-delay / defer-one-frame 派发，改到可见死亡交接：先所选 VO，再各 Actor Birth。每个 SoundDef 自身的原延迟、音量、变调继续保留。
2. **本体 t0、关键词 t+.3、破碎 t+.5、旧 Actor 释放 t+3.5。** t0 是原 zone 变更触发旧 Actor Death 的时刻；Godot atomic simulator 没有 server packet 历史，必须注明把现有可见死亡 wave 映射到这个 origin。不能把伤害提示完整结束当死亡门闩。
3. **3.5 秒释放的是旧视觉 Actor，不是延迟判死。** 游戏逻辑已处理 zone->graveyard，Card/Entity 并非在这个回调才判死或必须从模型销毁。保留原规则结算与死亡顺序，只让旧 Actor/Spells 延寿到动画结束。
4. **原 type10 DeathSplat 骷髅不是“每次消灭”的自动死亡提示。** 已证直接调用为 InputManager 的致命攻击预览和 HistoryItem 历史覆盖层。普通 Card.OnMetaData 用 type7。不能因资产名含 Death 给腐蚀/消灭/所有死亡额外叠骷髅。
5. **羊变形不是死亡。** 当前普通 Actor 内更新不走 type5 本体或角色死亡声；移除的 frozen/taunt tag 可各自运行 keyword Death。英雄 frozen 的 Death 则来自 ZoneHero->Graveyard，当场触发，没有普通随从 .3 秒偏移。

## 证据入口

- `source_provenance.json`：程序集 SHA-256、字节数、各 CIL 日志的程序集归属。
- `METHOD_LOG.md`：每条方法的 assembly-scoped token、RVA、CIL code size。所有完整指令在同名 `.cil.txt/.json` 中，分支偏移是方法内 IL 偏移。
- `death_flow_semantics.json`：机器可读语义与明确边界。
- `voice_root_components.json`：13 个原 CardSoundSpell 根组件的完整数据；没有凭音频文件名推断。
- `particle_enums.json`：同 build ParticleSystemModule 枚举定义。
- `static_validation.json`：13 个声音根的 zero-delay/nonblocking、所有 CIL dump 无解析错误验证。
- 同级 `../source_death_assets/`：原 SpellTable、13 CardDef DeathEffect 绑定、材质/纹理/mesh/11PS/FSM/音频 closure。本文不重复资产导出。

## 原链与方法日志定位

| 阶段 | 原证据 | 语义 |
|---|---|---|
| 判定死亡任务 | GameUtils.IsCharacterDeathTagChange **0x06014cf9**，DeathSpellController.AddDeadCardsToTargetList **0x0601164f** | character 的 tag49 ZONE 变成4 GRAVEYARD，剔除 suppressDeathEffects；不是直接由视觉读血量0触发 |
| 控制器入口 | PowerProcessor.DoTaskListWithSpellController **0x06005ff9**；CreateDeathSpellController **0x0600600c** | BLOCK_DEATH 类型6创建控制器 |
| 加载/Actor门闩 | SpellController.IsCardBusy **0x060149d6**；WaitForCardsThenDoTaskList iterator **0x060149e7** | 等加载、Actor ready 等；没有等 DamageSplat 或声音完成 |
| 选择与激活 VO | DeathSpellController.OnProcessTaskList **0x0601164e** | 先 PickDeathSoundCardIndex，抑制其他卡，再逐卡 ActivateCharacterDeathEffects；最后 IL003c 才调用 base |
| 多死选择 | PickDeathSoundCardIndex **0x06011651**，CanPlayDeathSound **0x06011654** | 1张直接按资格；2张互相攻击优先被攻击者，失败转另一个；其他随机候选。复用既有已验证算法，不把表现随机数混入规则 RNG |
| 角色声入口 | Card.ActivateCharacterDeathEffects **0x06012d53**、ForceActivateDeathSoundSpells **0x06012d54** | 从 DeathEffect/emote 绑定激活声音，不启动标准本体type5 |
| 无强制一帧 | CardSoundSpell.DelayedPlay iterator **0x06011d90** | delay<=0 分支直接 PlayNow；>0 才 WaitForSeconds；当前13全部0 |
| 唯一额外布尔门闩 | Card.ActivateSoundSpell **0x06012d5b**，WaitThenActivateSoundSpell iterator **0x06012f93** | 游戏 option39 为true时一直 yield null，直到变false；不是“一帧延迟”、伤害门闩或VO结束回调 |
| 应用逻辑任务 | SpellController.OnProcessTaskList **0x060149ce**，PowerProcessor.OnSpellControllerFinishedTaskList **0x06006002** | 角色声已发出，完成控制器回调，接着 DoCurrentTaskList 与 zone 变化 |
| 本体死亡 | Card.Check_VariousZonesToGraveyard **0x06012e29**，HandlePlayActorDeath **0x06012e79**，ActivateDeathSpell **0x06012db1** | 旧战场 Actor 留作死亡表现；当前 Card 的 graveyard Actor 与旧 Actor 分开 |
| 类型选择 | Card.GetBestDeathSpell **0x06012d4e** | custom override > 未沉默 custom death > Actor.GetSpell(5)，不能所有对象强制用普通type5 |
| 关键词尾部 | WaitAndPrepareForDeathAnimation iterator **0x06012f7b**，PrepareForDeathAnimation **0x06012e77**，Actor.DoCardDeathVisuals **0x06012966** | 默认 .3000000119s后切关键词Death；跳过127/5/35/150/7，故本体与伤害提示不被这步提前取消 |
| Actor销毁 | Spell.ChangeStateImpl **0x0601496c**，Card.OnSpellStateFinished_DestroyActor **0x06012dca** | 本体 FSM 结束进入 None 时才销毁旧 Actor；OnSpellFinished_Death **0x06012dc9** 主要复位计数/关键词delay，不是旧Actor销毁钩子 |
| 释放 owned spells | Actor.Destroy **0x060127ef** -> ReleaseSpells **0x060127f0** -> SpellManager.ReleaseSpell **0x06014a03** | 释放不能额外合成新的 keyword Death/声音；正常尾部在此前已处理 |

## 本体 FSM 时间线

原入口：Card_Play_Ally_SpellTable 的 type5 -> `Card_Play_Ally_Death.prefab:0d12844e0f5834ae084290dc98ded3af`。root pathID `5210564580019615545`、FSM `8211937404196173625`，来自 `CAB-69c88b234dfa427e02d1fcee9337ae34`。

- t0 Birth 初始化变量与材质，启动 1 秒的 AllyInPlay_Death 动画、原通用死亡声音。动画/音频 action 自己立即 Finish，**.5 秒的 iTweenShakePosition 才是 Birth 到碎裂子态的阻塞 action**，不是等1秒动画结束。
- t+.3：旧 Actor 活跃 frozen/taunt/sleep 等进入各自 Death；保留原 FSM 尾部。
- t+.5：隐藏 RootObject renderers，启用碎片子树 renderers，启动子粒子；碰撞平面 iTweenMoveTo 配置 delay1.5、time1.5，另有 Wait3。
- t+2.0 至3.5：移动的是 **FX_CollisionPlaneLocation1**，不是把所有碎片整体下沉。粒子通过 Collision/Death sub-emitter 处理，不可用全组tween代替。
- t+3.5：DisableShadow，FSM None，完成回调释放旧 Actor 与其 owned spells。

伤害提示在 Actor/Spells，普通本体在 RootObject，属于同一个旧 Actor 下不同分支。t+.5 只隐藏 RootObject 时，不能一并隐藏损伤数字或关键词尾部；最终旧 Actor release 才统一释放。普通 DamageSplat 自身可覆盖至约3.1秒，源代码没有因此延后本体。

## 根、材质与纹理

- 标准 type5 的 Card.ActivateDeathSpell **不调用 SetSource**。它从 Actor.LoadSpell **0x0601294c** 挂到 Actor.GetSpellParent **0x06012987**；m_Location=2 但 m_source=null 时 SOURCE_AUTO 无对象，SetPositionFromLocation不改位置。应保留原 Spells parent 和 prefab local transform，不能仅见 Location2 就重设到卡中心。
- SpellInitActorVariables.GetActor **0x06016d08** 优先找祖先 Actor，避免误拿 Card 已更新后的 graveyard Actor。OnEnter **0x06016d0a** 将 RootObjectMesh 绑定到 Actor.GetMeshRenderer(true)。
- GetCardPortraitTextureAction **0x06016b77** -> Actor.GetStaticPortraitTexture **0x06012892**。当前 nonpremium0 使用原静态 portrait；action不做裁切、缩放或UV处理，也不是整张卡截图。材质和 mesh 本身决定UV。
- CustomActions SetMaterial **0x06000059**，SetMaterialTexture **0x0600006c** 经同 build MaterialService RendererExtension 使用 renderer.material（index0）；不能共享一份可变材质让多张同时死亡的 portrait互相污染。native getter具体分配内部行为不由managed CIL证明。
- PremiumMaterialSwitcher **0x06015335** 在 premium<1且没有已缓存OrgMaterials时保留序列化默认材质，不应套gold材质。

## Particle / iTween / 阴影边界

- ParticlePlayAction（CustomActions **0x060000ee**）：target自己有PS则只调用该PS.Play(includeChildren)；没有PS且includeChildren=true时，GetComponentsInChildren并对每项调用Play(true)。wrapper没有排除sub-emitter代码。Unity对重复Play、sub-emitter系统是否自主emit、原生culling和碰撞的内部细节不能由这个wrapper证明，不应据此强加额外dust burst。
- SubEmitterType2 精确是 **Death**；Collision是1。原 minKillSpeed 导致粒子死亡可间接引发Death子发射，但不能把该事件直接改名为Collision。
- CullingMode：Automatic0、PauseAndCatchup1、Pause2、AlwaysSimulate3。public SimulationSpace：Local0、World1、Custom2；**旧序列化moveWithTransform=0不等于已经证明Local0**，该映射保留未核验边界。
- SetVisibilityRecursiveAction **0x06000112** 对返回的全部 renderer 无条件设置enabled。includeChildren=true 默认不含inactive GO，但active GO上原本disabled的rock renderer会在t+.5被启用，故Default-Particle shader可达；不能永久按初始disabled过滤。
- iTween.ApplyShakePositionTargets **0x06000054**：每轴独立 Random.Range[-amount*(1-p),+amount*(1-p)]，加到cached起点，不累计，不是sine。该wrapper未指定isLocal，Defaults=false；space0按世界坐标再映射棋盘。
- MoveTo ease21 对应linear **0x0600009b** / Mathf.Lerp；末端snap。保留目标是collision plane。
- ProjectedShadow.Start **0x0601533c**依赖graphics realtime-shadow策略/board高度；RenderToShadowTexture **0x06015351**以CommandBuffer画enabled renderer剪影到RT，再两次Multisample Blit；CreateProjector **0x06015352**加载Resources/Prefabs/ShadowProjector与DecalProjector。材质包括Custom/ContactShadow、Selection/HighlightMultiSample、Unlit/Color/White及DarkGrey。这不是一个简单本地透明椭圆；原3.5秒disable时机已闭合，完整投影后端仍是明确的兼容边界。

## 英雄与变形

Card.Check_HeroToGraveyard **0x06012e28**明确检查 prior ZoneHero -> ZoneGraveyard，IL001b立即调用旧Actor.DoCardDeathVisuals，IL0021停custom关键词。没有随从.3秒延迟。GameEntity.ActivateSpellForDestroyedHero **0x060054f3**是另一个终局body入口，方法本身不调用DoCardDeathVisuals。不能将game_over布尔量直接当全部关键词立即消失，也不能声称已恢复服务器PLAYSTATE与ZONE事件间的时间差。

当前13种普通随从变羊保留同一个普通 Actor。参考v34的 `polymorph_actor_semantics.json`：changed tag走各自关键词Death，未改变的Sleep等保留原实例。hidden/show不是死亡重生，release只释放，不凭名字额外播死亡声。

## 对 Godot 集成的验收建议

1. 单只伤害致死：数字、VO与Birth/原通用声可重叠；不得等3.1s数字结束；碎裂.5、旧Actor释放3.5。
2. 多只同时死亡：角色声按原控制器只选一张，每Actor通用type5音效各一次；portrait实例互不污染，视觉随机不影响牌局RNG。
3. 腐蚀/直接消灭：type5流程成立但不凭death名添加type10骷髅或虚构伤害数字。
4. 冰冻+嘲讽随从死亡：.3进入各自Death，.5本体隐藏不截断关键词尾部；3.5统一释放无重播。
5. 变羊：无角色死亡VO/本体type5；按源tag差异处理状态，Sleep不凭整卡替换重生。
6. 英雄终局冻结：在映射后的hero graveyard可见交接立即进入Frozen Death，不套.3；如果尚未桥接，明确记录，不把原缺失掩成v35完成。
7. GPU观测必须写明原生粒子solver、旧serialized空间映射、ProjectedShadow以及source-packet绝对时间尚非像素等价。上述边界不阻挡给出源绑定正确的首个可见样例。

## Type10 另支归档

`skull_branch_semantics.json`保存ShowSkull完整内部判定、DisableSkull及HistoryItem方法语义，规范CIL在`death_skull_preview.cil.*`。ShowSkull检查实时可伤害与攻击致死/剧毒预览条件，非剧毒分支才激活type10；history只在覆盖层Actor上激活并淡出。它们不是本轮实际死亡主链的完成项。扫描限直接constant10近邻spell调用，不把未命中夸大成不存在任何间接路径。
