from pathlib import Path
import json,hashlib,datetime
root=Path('v30_work/audio_code_evidence');src=Path('v30_work/original_code/Assembly-CSharp.dll')
sha=hashlib.sha256(src.read_bytes()).hexdigest()
prov={'source':'Assembly-CSharp.dll','build':'37.0.0.255130.254477','bytes':src.stat().st_size,'sha256':sha,'source_provenance':'../original_code/download_provenance.json','mode':'Read-only PE/CLR metadata and CIL decoding. No DLL execution, login, game process or server emulation.','tools':{'dnfile':'0.18.0','dncil':'1.0.2','pefile':'2024.8.26'},'raw_dump_notes':'final_core, closure, deeper and conditions use method-relative IL branch labels. Earlier core and binding dumps have method-relative instruction offsets but branch operands retain dncil body offsets (include method header). Do not use their branch operand integers as IL labels. Method tokens and call-site offsets are exact.'}
(root/'provenance.json').write_text(json.dumps(prov,ensure_ascii=False,indent=2))
cd=json.load(open('v30_work/audio_assets_evidence/carddefs.json'));cards=json.load(open('v30_work/godot_v30/TavernDuel/assets/data/dual_deck_cards_5834.json'))['cards'];out=[]
for cid,v in cd.items():
 c=next(c for c in v['data']['components'] if 'm_PlayEffectDef'in c)
 row={'card_id':cid,'name':cards.get(cid,{}).get('name',cid),'carddef_guid':v['guid'],'carddef_bundle':v['bundle'],'carddef_path_id':v['path_id'],'source':'../audio_assets_evidence/carddefs.json','suppress_play_sounds_on_summon':c.get('m_SuppressPlaySoundsOnSummon'),'effect_defs':{k:c[k] for k in ['m_PlayEffectDef','m_AttackEffectDef','m_DeathEffectDef']},'warning':'Each m_SoundSpellPaths entry is a layer, but a subclass can return no matching AudioSource. Hero-skin conditional VO is not universal spell SFX.'}
 out.append(row)
(root/'card_binding_roots.json').write_text(json.dumps(out,ensure_ascii=False,indent=2))
(root/'README-ZH.md').write_text('''# 原版卡牌音效：只读代码证据

## 来源与范围

源为用户当前工程同源资源 build **37.0.0.255130.254477** 的 Assembly-CSharp.dll，SHA-256 `'''+sha+'''`。使用可信 PyPI dnfile 0.18.0 / dncil 1.0.2 解码 PE/CLR/CIL，不执行被测 DLL，不登录客户端。本证据不是 2014 年 1.0.0.5834 二进制证明；玩法卡池可以取 2014 数值，但声音与路由来自上述现代原包。

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
- 恰好两个互杀目标：优先被攻击者；被攻击者不可播则选另一个。
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
- 全局限流、ducking、声道配置依赖 SoundConfig 真实资产；当前未取得其数据时不能声称逐卡priority已复原。

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
''',encoding='utf-8')
print('Created provenance, card_binding_roots, README-ZH')
