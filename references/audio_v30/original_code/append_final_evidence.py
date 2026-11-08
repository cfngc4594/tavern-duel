from pathlib import Path
import json,re,hashlib
p=Path('v30_work/audio_code_evidence')
f=p/'README-ZH.md';s=f.read_text()
s=s.replace('- 恰好两个互杀目标：优先被攻击者；被攻击者不可播则选另一个。','- 恰好两个互杀目标：优先被攻击者；被攻击者不可播则直接选攻击者，**不再次检查攻击者 CanPlayDeathSound**。不能在此分支之前统一过滤 eligible；两个均被382/959排除时仍可能选攻击者。下游 ActivateCharacterDeathEffects/ActivateSoundSpell 没有再检查382/959，另有1075 CARD_DOES_NOTHING gate。')
s=s.replace('- 全局限流、ducking、声道配置依赖 SoundConfig 真实资产；当前未取得其数据时不能声称逐卡priority已复原。','- 已取得真实 SoundConfig：`SoundConfig.prefab:cd41c731c777d4f468b79ffa365a9f94`，Initialize协程 **0x060147F7** IL_002a引用。资源为 essential_base_global-prefab-0.unity3d / pathID -8607417786929617192，原 typetree见 `../audio_assets_evidence/SoundConfig_-8607417786929617192.json`。完整750组，按当前真实clip GUID匹配的子集见 `relevant_playback_limits.json`。已播放比例**超过** exclusive threshold 的source既不计数也不停止，可以和新source重叠。当前匹配组均priority0，组内窗口内达限就拒播，不是手工按文件去重。')
marker='## 补充闭包：预瞄、PlayMaker、标准actor与英雄技能'
s=s.split(marker)[0]
s+='''## 补充闭包：预瞄、PlayMaker、标准actor与英雄技能

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
'''
f.write_text(s)
# Make multi-token callsite script independent of dump_cil optional DLL argument.
f=p/'find_callers.py';s=f.read_text();s=s.replace("exec(Path('v30_work/audio_code_evidence/dump_cil.py').read_text().split('pattern=sys.argv')[0])","exec(Path('v30_work/audio_code_evidence/dump_cil.py').read_text().split('pattern=sys.argv')[0].replace(\"sys.argv[3] if len(sys.argv)>3 else 'v30_work/original_code/Assembly-CSharp.dll'\", \"'v30_work/original_code/Assembly-CSharp.dll'\"))");f.write_text(s)
# Refresh exact GUID joins, keeping complete original group definitions.
a=Path('v30_work/audio_assets_evidence'); refs=set();files=['character_bindings_resolved.json','spell_audio_bindings_resolved.json']
for name in files:
 text=(a/name).read_text()
 refs.update(x.lower() for x in re.findall(r'[^"\\\n]*\.(?:wav|ogg|mp3):([a-fA-F0-9]{32})',text))
config=json.loads((a/'SoundConfig_-8607417786929617192.json').read_text())['data'];groups=[]
for i,g in enumerate(config['m_PlaybackLimitDefs']):
 matches=[c['m_Path'] for c in g['m_ClipDefs'] if c.get('m_Path','').split(':')[-1].lower() in refs]
 if matches:groups.append({'source_group_index':i,'match':matches,**g})
(p/'relevant_playback_limits.json').write_text(json.dumps({'source':'../audio_assets_evidence/SoundConfig_-8607417786929617192.json','binding_sources':files,'matched_exact_guid_count':len(refs),'groups':groups},indent=2))
# Cross-DLL provenance avoids token namespace ambiguity.
rows=[]
for name in ['Assembly-CSharp.dll','Blizzard.T5.PlayMaker.Runtime.dll','PlayMaker.dll']:
 q=Path('v30_work/original_code')/name
 rows.append({'file':str(q),'bytes':q.stat().st_size,'sha256':hashlib.sha256(q.read_bytes()).hexdigest(),'scope':'read-only static PE/CLR/CIL; never executed'})
(p/'assembly_sources.json').write_text(json.dumps(rows,indent=2))
print('Report updated; matched config groups:',len(groups),'exact clip refs:',len(refs))
