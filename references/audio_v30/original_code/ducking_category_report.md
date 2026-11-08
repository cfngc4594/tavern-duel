# 可恢复的原版互压与音量逻辑

## 当前卡池的直接结论

39条角色Play/Attack/Death绑定中36条SoundCategory.VO=3，3条FX=1。已恢复的法术/英雄技能主体为FX=1。普通VO只压AMBIENCE=6至0.5，线性0.1秒进入、0.3秒恢复；不压MUSIC=2，不压FX=1。普通FX没有category触发duck规则。不能给所有角色台词统一加BGM/SFX压低。

这部分**不是缺少AudioMixer/DSP**：SoundManager直接乘AudioSource.volume，完整SoundConfig.m_DuckingDefs已恢复。全部9个触发category及受影响category/倍率/时间见原SoundConfig文件。SoundCategory与iTween EaseType枚举Constant表见audio_constants.json，其中21=linear。

## 最小精确移植逻辑

1. PlayImpl 0x06014791 IL006a–0076：如果此source尚未registered-for-duck，按SoundDef.category寻找对应SoundDuckingDef，RegisterSourceForDucking 0x0601477F注册每条受压category。
2. RegisterDuckState 0x06014781：每个target category保存多个DuckState，按trigger对象identity复用同一状态，新的volume初值1。
3. ChangeDuckState 0x06014785：停止该状态旧tween，begin mode1，restore mode3。Begin 0x06014786从当前volume向配置m_Volume，用m_BeginSec及m_BeginEaseType；Restore 0x06014788从当前volume回1，用m_RestoreSec及m_RestoreEaseType。当前所有配置ease21=linear。
4. 两个回调0x060147DC/DF每帧SetVolume并UpdateCategoryVolume。Begin完成改mode2；Restore完成0x06014789从category状态列表删除该DuckState。
5. FinishSource 0x06014799 IL0080调用UnregisterSourceForDucking，后者按trigger把各状态改Restore；UpdateDuckStates 0x060147A9也会对已销毁trigger开始Restore。不是音频固定长度预先定时复原，实际source finish/stop才发起恢复。
6. GetDuckingVolume(source) 0x0601478C：SoundDef.m_IgnoreDucking=true直接1。GetDuckingVolume(category) 0x0601478D取全部duck状态volume的最小值（初始1），**不相乘**。如果trigger category非NONE且IsCategoryAudible=false，则忽略该duck；mute的语音不能继续压低环境声。
7. source音量0x06014767 = codeVolume * sourceVolume * 随机SoundDef volume * categoryVolume * duckingVolume。复制声源与直接source应各自保留原基准sourceVolume。

## 用户音量选项与确切边界

SoundDataTables..cctor 0x06014811:
- MUSIC2/SPECIAL_MUSIC7/HERO_MUSIC9 → Option.MUSIC_VOLUME8，额外最大倍率0.5；这3类的enabled→Option.MUSIC3。
- AMBIENCE6 → AMBIENCE_VOLUME9。
- VO3/SPECIAL_VO4/TRIGGER_VO8/BOSS_VO10 → DIALOG_VOLUME10。
- FX1/SPECIAL_CARD5/TRIGGER_SFX12/SPECIAL_SFX13 → SOUND_EFFECT_VOLUME11。
- 未映射category默认volume1。

SoundUtils.GetOptionVolume 0x06014818先Clamp01(option float)，再乘该option最大倍率（仅MUSIC_VOLUME为0.5，其他1）。GetCategoryVolume 0x06014819还可被cheat禁用为0。

SetMasterVolumeExponential 0x06014717: AudioListener.volume=pow(clamp01(Option.SOUND_VOLUME7),1.75)。IsCategoryEnabled 0x06014775检查全局master enabled；音乐还检查设备后台音乐是否播放及music enabled。IsCategoryAudible 0x06014777要求category volume>Mathf.Epsilon且enabled。

**尚未恢复的是用户当前Options取值/设备后台音乐状态，不是此ducking算法或配置。** 原型应使用自身显式设置映射这些选项，不声称知道用户原客户端的滑块值。AudioListener最终输出、平台音频后端等未做运行验证；无需为这几条已证的乘法/线性tween声称必须完整移植DSP。

## 证据

- final_core.cil.json/txt: SoundManager与SoundUtils完整标准化CIL。
- ducking_details.cil.json/txt: DuckState、callbacks与SoundDataTables静态初始化。
- audio_constants.json: Source enums，另iTween.dll原CASC恢复来源同original_code旁。
- ../audio_assets_evidence/SoundConfig_-8607417786929617192.json: 完整原配置，非自行拼造。
