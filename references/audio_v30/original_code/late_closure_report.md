# 最终限定补核（本卡池，不扩大其他UI）

## 恶魔卫士毁晶：卡专属与通用UI分开

EX1_301 CardDef无专属m_SpellPath等，不能凭文件名补战吼声。已证明原全局链：

1. Player.OnFriendlyPlayerTagChanged **0x06005DC2**，GAME_TAG.RESOURCES=26分支（IL028D–02F0），容量new<=old调用DestroyManaCrystal(old-new)。RESOURCES_USED=25另有消费路径，不应混淆。
2. Player.DestroyManaCrystal **0x06005DAF** 首先IsFriendlySide；false立即返回，true调用ManaCrystalMgr.DestroyManaCrystals。**这是本地友方晶体UI链，不得自动给敌方也播放。**
3. ManaCrystalMgr.DestroyManaCrystals **0x06005B3B**→WaitThenDestroyManaCrystals **0x06005B5C**，等待加载完成，再按个数DestroyManaCrystal **0x06005B5F**→ManaCrystal.Destroy **0x06005B18**。
4. ManaCrystal.WaitThenDestroy异步MoveNext **0x06005B2C** 等m_playingAnimation结束；非临时晶体取gemDestroy GO，取其Spell、注册完成callback、Activate。临时晶体用tempGemDestroy。
5. ManaCrystalMgr.GetManaCrystalAssetPaths **0x06005B5A** 按m_ManaCrystalAssetTable中m_Type首匹配，无匹配用表第0项；资源入口是ManaCrystalAssetPaths.m_ResourcePath，只有Add/Spend/Refresh音效字段，**无SoundOnDestroyPath**，毁晶必须追上述gemDestroy Spell。
6. 资源代理已按默认m_Type0强引用：Resource.prefab:d481f3581f436af43893ba4f88346fce→ManaCrystal -7388720680279173223→gemDestroy GO -5725931659908507751→子GO AudioSource -2085742355177826407 / SoundDef -692930451109800039→mana_crystal_expend:56dc0c11d98cdae4795ea38a39f3150c。这是实际引用，不是因为名字相近借用。具体FSM状态与本地音频路径由资源侧最终binding交付。

代码文件：mana_crystal_events.cil.*、mana_destroy_closure.cil.*、callers_06005b3b.json、callers_06005daf.json。资源文件：mana_crystal_asset_search、mana_destroy_effect_prefabs（由资源代理维护）。

## Fireball cast与launch不是同process帧

SuperSpell.SpawnAllMissiles **0x06014B20** 按目标启动SpawnMissile协程后，立即DoStartSpellAction。WaitAndSpawnMissile.MoveNext **0x06014B91** IL005E–0072 在非sequence或targetIndex0时**即便随机delay=0也yield WaitForSeconds(0)**，随后还可能等待metadata任务。因此cast先，missile至少后续协程调度再出生，不能固定同process帧。Godot用一次process defer重建是明确调度适配，不是宣称Unity帧量化完全等同。

group343对Shared_Fire_Cast_1限1、priority0、exclusive threshold0.1，短间隔launch仍可能被抑制，限流本身正确；但正确限流不能掩盖错误事件起点。

WaitAndSpawnMissile明确调用ActivateState(Birth1)，不是无参Activate首usable扫描；OnMissileSpellStateFinished **0x06014B24** 在Birth结束调用FireMissileOnPath。源/弹道/命中阶段不能全部套统一入口策略。

## Area基数与手牌actor切换

WaitAndSpawnAreaEffect.MoveNext **0x06014B7F** 随机一次delay、一次CloneSpell、一次Activate、保存单一m_activeAreaEffectSpell。DetermineAreaEffectInfo按source控制方择Friendly/Opponent之一，非每个伤害目标重复。

Card.ActivateActorSpells_HandToPlay **0x06012E50** 启动oldActor outSpell；其完成callback **0x06012E51** Show新actor后GetBestSummonSpell并Activate inSpell。因此Out完成→新actor显现→In启动，不是都commit同帧。原型1.5秒视觉总长是自身时钟，原In内部延迟仍应相对In起点。

普通非premium手牌分档按EntityDef基础cost：<4 / 4–6 / >=7，不是ATK、稀有度、实际消耗费用。token另走type26/31。通用type5死亡spell不受CardEffect death soundSpells的批次抑制。

## 额外小分支

- AttackSpellController.GetSourceAttackSpell **0x06011626** 本地友方取type17，敌方type18（特殊模式另有override）。资源侧已逐字段证明两者AttackLaunch音源等价，不只凭同名猜。
- hand SendEventBasedOnEntityTagAction **0x06016C25/26** whichEntity5通过SpellAction.GetEntity **0x06016C8C**优先取spellActor.GetEntity，找不到才source fallback。ELITE=114、PREMIUM=12，名字“Dragon?”不代表种族龙。range走GetAppropriateElementAccordingToRanges，即inclusive首匹配、边界外取极值档、内部gap无事件。
- SpellCustomActorVariable **0x06016CCE**写引用后立即Finish；ActorSetVisibility **0x06016A63** Show/Hide后立即Finish。对应hand_source_actions.cil.*。

资源FSM最终补齐：mana_destroy_audio_bindings_resolved.json中 `Action → State 2 → FINISHED → State 3`，前置iTweenShakePosition显式FINISHED在0.5秒，之后AudioPlaythroughAction播放上述真实source。该0.5从gemDestroy spell启动计算，之前仍有晶体已有动画等待。

## 隐藏敌方手牌移出没有音源

资源侧 `hidden_hand_effect_prefabs.json` / `hidden_hand_fsm_decoded.json` 证明 Card_Hidden_SummonOut.prefab:7293a69287e574d4ea07c6b8a9c189d6 的直接引用闭包没有 AudioSource、SoundDef 或 Audio* action，且无未解析引用。唯一待核自定义组件 CardBackSummon 已用原代码排除额外播放：OnEnable **0x06001B6F** 只注册状态/卡背更新回调；OnStateStarted **0x06001B71** 在 Birth 调 UpdateEchoTexture；UpdateEchoTexture **0x06001B73** 仅按友敌选 CardBackManager.GetFriendlyCardBack/GetOpponentCardBack，读 CardBack.m_HiddenCardEchoTexture **0x0400145A**，设置 Renderer.material.mainTexture。该类既不加载特效，也不播放音频。完整类见 `hidden_cardback_summon.cil.json/txt`。因此本池普通隐藏敌方手牌的这个 Out 根可保持静默，不应复用友方 Out 声；此结论不泛指整段出牌没有随后的召唤 In / 角色声音。
