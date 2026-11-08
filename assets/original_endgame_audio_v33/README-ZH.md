# v33 原终局音频

已恢复13条完整原音，来源固定原37客户端Build 37.0.0.255130.254477。clips_provenance.json记录中文locale映射、原AudioClip对象、原FSB SHA256、WAV SHA256、采样率、声道及完整时长；source_bundle_provenance.json对9个原bundle同时校验CASC content MD5和SHA256。无裁剪、增益烘焙、变速、混音或重采样。

## 绑定而非猜名

- 两基础Hero CardDef的m_DeathEffectDef.m_SoundSpellPaths→CardSoundSpell，均无EmoteType29，故可走ForceActivateDeathSoundSpells回退。吉安娜、古尔丹各一条zhCN Death，无随机变体。恢复了可播放路由，但实际ForceActivateDeathSoundSpells调用时点必须由主控制器源证据派发，音频模块不会因HP<=0自动播。最新xref核37/38/39 FSM无AudioPlayActorDeathVOAction且AnimationClip events为空；死亡波由DeathSpellController只选择一张未抑制声音的卡。不能按爆炸State3重复VO，也不能平局无条件两Hero并发VO。英雄是否纳入死亡波待主trace进一步确认。
- GameEntity.NotifyOfGameOver先StartPlaylist107，再胜option22 victory_jingle、败或平option21 defeat_jingle，再BlowUpHero。playlist107只有type1 ambience，原MusicManager会Nuke旧音乐；heavy prefab实际绑定medium clip，原AudioSource0.3乘track1，FadeTrackIn持续1秒。这不是名字匹配。
- 真实win/lose/draw破碎FSM State2 crack gain0.8、State3 explode gain0.9，只有win State4 fireworks gain0.5。每个源动作delay0、pitch1，无变体。平局己方由39转换38，敌方39，必须按实际prefab派发，不能两侧硬播draw。
- VictoryScreen FSM Action→Audio立即胜screen_start，Wait6s→firework loop源gain0.2。DefeatScreen（包含平局）Action→Audio立即败screen_start，Wait1s→thunder loop源gain0.4。Cancel/Death均1秒fade-out loop+banner_shrink gain0.4。胜screen_start有Scenario2890特殊替代，当前基础对局使用default，未泛化成该冒险场景。
- SoundManager.GetVolume/SetVolume操作codeVolume，不覆盖原AudioSource gain；screen loop State2 code-volume fade的目标1乘原0.2/0.4。完整原global category ducking/混音未声明复原。

## 接口

scripts/native_endgame_audio.gd独立Node：
- setup(game)：读取manifest并取既有SoundManager。
- begin(scope:String, outcome:String, dead_sides:Array=[], heroes:Dictionary={})：在原NotifyOfGameOver门调用一次。outcome=win/victory、lose/defeat、tie/draw。自动playlist107和胜/败平jingle，不自行播放英雄VO或估算破碎时点。
- trigger("hero_death", {card_id:"HERO_08"或"HERO_07",side:0或1})：只在源证据的死亡声音入口调用。
- trigger("win_state2"/"win_state3"/"win_state4"/"lose_state2"/"lose_state3"/"draw_state2"/"draw_state3", {side:...})：按真实FSM进入派发，同scope/event/side幂等。
- screen_show()：原screen FSM收到Action时调用一次，自动上述开场及源Wait后的loop；不能提前到HP归零。
- screen_close()：原screen Cancel/Death时调用，取消未开始loop，已播loop按1秒淡出，播原banner_shrink。
- clear(restore_bgm=true)：换局/重开取消所有pending和voices，恢复旧BGM stream、位置、音量及用户音乐开关；退出clear(false)不恢复。
- get_audit()：包含真实播放/静音/缺失/重复等状态。unbound路由失败关闭，不播放猜测音。

## 控制与验证

原107 ambience复用SoundManager.music_player替换旧BGM，防叠播；B键和Music音量统一控制。其余原category1/3用既有SFX总线与M键、SFX音量。静音停止本模块SFX；退出与clear显式stop、释放stream和节点。原Unity类别ducking映射为既有两总线属于适配，未虚称全局混音一模一样。

Godot4.6.3 headless测试tests/v33_endgame_audio_test.gd 18项通过，无ERROR、泄漏；覆盖源clip、未绑定失败关闭、幂等、两Hero接口、静音、旧BGM恢复、6s/1s loop门、关闭1s淡出、提前关闭取消pending与音乐开关。Headless只能验证调度/资源/控制，不等于扬声器主观试听证明。
