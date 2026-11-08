# v30 原客户端声音路由契约

## 版本与证据

规则保持 1.0.0.5834；此次音源、资源绑定及反编译代码来自恢复的 37.0.0.255130.254477 客户端。不能把这批现代客户端原音称为 5834 原包音轨。没有修改 `dual_class_rules.gd` 的伤害、抽牌、冻结、目标选择或同步结算。

`tools/build_v30_audio_manifest.py` 只转换强引用链 CardDef / Actor SpellTable → prefab → FSM action / CardSoundData / SpellStateAudioSource → AudioSource → SoundDef → AudioClip。运行时事实是 `assets/original_audio_v30/runtime_manifest.json`。每层保留来源文件、稳定 row_id、state_index、源组件身份与原路径；不能用重名 FSM state 的名字替代索引。

原片段完整解码为 PCM WAV，保留采样率、声道、时长；没有裁切、变声、逐卡归一化或补造音源。中文 VO 由官方 locale GUID 覆盖链确定，非语言 SFX 用 global 原资源。主法术 91 条音频动作中 83 条可达可用；3 条原禁用、3 条条件默认空、2 条重名 state 影子排除。41 条控制中 40 条启用。无原音动作的阶段标 `source_silent`，不等于资源丢失；state-only 控制不计为可听音源。

## 事件与实例

- `SoundManager.play_original_event(card_id, event, context)`；随从为 play/attack/death，法术为 precast/cast/launch/hit/release/cancel。共享系统为 @physical、@attack、@actor、@hand、@mana。
- context 包含 scope_id、event_token、source_side、unit_id、target_id、delay_sec、stage_filter。返回 accepted、layers_scheduled、first_delay_sec 或拒绝原因。`event_token` 是本原型的回调锁，不是虚构的原版去重算法。
- CardSoundSpell 的同一实例重播先 Stop 自己的声音及待播回调。两个同名随从具有不同实例作用域；不按 cardID 全局互斥。
- 原 AudioPlayClip / RandomClip 及 OneShotSound 产生新声源；不能统一当 CardSoundSpell 复用。空模板精确使用 SoundConfig 的默认 PlayClipTemplate，不继承附近声源的 Loop。硬币 Start 为独立一次声，随后另有持续 Loop。
- SpellStateAudioSource 仅在 `!PlayGlobally && StopOnStateChange` 时因阶段改变而停。取消、重开、退出、SFX 关闭或滑到零清除待播工作，不留异步 SceneTreeTimer 音频协程。
- 队列按源等待、原状态路径、动作索引排序。多个层共用同一个 RandomWait 抽样。先发生的新阶段能取消旧阶段尚未发生的动作。finish_scope 等待源延时、淡出和一次声尾音，不再在结算后固定 .35 秒截断。
- scope 退休清理随机等待、回调锁、阶段、控制、待播与淡出缓存。音频 RNG 独立，不消耗玩法或 AI 随机数。

## 实际触发点

- 随从角色登场声在合法提交 hand-to-play 时触发，不在牌面揭示后重复。
- 攻击角色 VO 在合法进入攻击瞄准时触发；取消瞄准不意味着此前没有声音。确认不重播。实际冲刺起点播原 AttackLaunch，接触时按攻击者攻击力选原物理 Impact：0–2、3–5、6–7、8–9999，越界先钳到外档，中间未匹配使用原 default。空来源安全跳过是原型防护，不能称为原代码行为。
- 批量死亡只选一张 CharacterDeath soundSpells。单个需合格；两个互杀先检查 defender，失败直接返回 attacker，保留原不重验 attacker tag 的边界；其余从合格者均匀抽一个。382/959 参与资格，1075 阻止 CardEffect 激活。各死亡 actor 的共享碎裂声独立，不受批次角色 VO 抑制。
- 有目标法术进入手牌有效区外的预瞄才 Birth/precast；无目标法术提交才 Birth。不是刚拾牌便播所有法术音。
- Area 的 Friendly/Opponent 是按施法者视角二选一的候选，每次行动最多一个；无适用候选才按原顺序 fallback。不是两边同时播，也不是每目标播 Area。
- Impact 按实际规则伤害目标记录分派；根部施法者效果仅一次。三发奥术飞弹保留原同步规则结算，但声音按实际每次目标记录串行：每发原 PathDuration .5–.7 秒到达后，启动该发 Impact 并开始下一发。最后发启动触发 Start 的 release。死亡声随对应命中排队，不早于命中。
- 原 Missile 首发、Area、Impact 协程即使 SpawnDelay=0 也 yield。这里映射为至少一个 Godot process 帧，然后才开始源 FSM 等待；序列第二发以后按原分支跳过 Missile SpawnDelay。原服务器 metadata 门禁在本地无对应模型，不虚构秒数。
- 友方手牌 Out 使用 Hand Actor 自己的 1/22/23 表及 Regular、非 ELITE 分支，不能借用 Play Actor 的同编号 prefab。In 使用基础费用档（<4、4–6、≥7）对应友方 2/24/25、敌方 42/68/69。Out 完成→新 actor 显现→In 启动在本项目映射到 reveal 回调；In 的 .5/.43 或 medium/large 源动画界限等待从该点计时。生成 token 则用 26/31，不套手牌档。敌方隐藏手牌 Out 的独立 prefab 无音频动作，CardBackSummon 只换贴图，确证静默；不复用友方 Out。
- 恶魔卫士仅在本地友方基础水晶容量实际减少时走原毁晶 UI 链，等待 gemDestroy 的 .5 秒显式 FINISHED 后发声。敌方原函数直接返回，不凭对称性补声。

## 已还原的等待、音量与限流

- 火球 release 的 Death 入口内有 .5 秒原曲线等待；寒冰箭的 Death 入口内没有这段等待，但此前 Start Action 必须先完成 .5 秒 AudioVolumeFade 才可进入 release，两段不能混淆。11 卡 Start Action 完成表见 start_release_timing.json；其余 10 卡无固定等待，不把 Playthrough 当作等待音轨结束，也不把 false DeathAfterAllMissilesFire 解读为等 impact。烈焰风暴后段 End 等 .7 秒显式 FINISHED，不被并行 2.15 秒 CameraShake 拖长。腐蚀 impact 的 .25 秒等候保留。
- 弓箭手先复用同一次 Birth 随机等待（.15–.45 秒），Birth 完成才启动 .1 秒 Missile 路径，随后 Impact 与死亡音排队；不是提交时立即命中。酸性沼泽软泥怪同控制器按原 .5–.65 秒路径。弓箭手后段等待 Take001 完成，静态 legacy 曲线界限为 .6333333254 秒，后加同状态原随机 .05–.15 秒等待。未把空 MuscleClip 的默认 1 秒误当动画时长，也不称静态曲线界限为 Unity native length 实测。
- AudioSetVolume / AudioVolumeFade 写的是 codeVolume 乘数；fade 为线性 Lerp。非正 FadeTime 原行为为直接 Finish，不强行设置目标值或 Stop。硬币原 SoundVolume 的 unweighted Hermite 曲线持续驱动 codeVolume，.7 秒后进入原下降曲线；不用常量 1 代替。
- 增益为 codeVolume × AudioSource 原 volume × SoundDef 随机 volume × category × duck；音高为 codePitch × AudioSource 原 pitch × SoundDef 随机 pitch。原普通 Music/SFX 控件保留，没有把原 Options 的 master 指数或 music 最大 .5 再乘到旧控件上。最终混音另加 Godot 专属 SFX 总线 −6 dB 安全余量和 Master HardLimiter（effect ceiling −1 dB、release .1 秒），保留已有 Master −3 dB。这是实际合法 7+7 Hellfire 峰值 3.945149 后的输出保护，不是原客户端参数，也不是逐卡归一化。16 个场景实际 float Master 复测最高 0.89125514（约 −1 dB），大于等于 1 的样本为零；不靠总线参数简单相加猜输出上限。
- SoundUtils RandomClips：原始权重总和、Range、`<=` 边界、最后一项 fallback；全零多项落第一项，随机空 clip 回落主 clip。没有 shuffle 或禁止连选。
- PlayMaker AudioPlayRandomClipAction：空权重选第一个；有权重使用严格 `<` 逐项减权，未命中返回 -1。全零的原 action 会负索引异常，这里明确安全静音，不冒充原错误行为。
- SoundConfig 的 clip group 使用已播放比例的 exclusive 窗口。窗口外旧音仍播但不占限额；窗口内仅严格较低 priority 可被替换，否则拒绝新音。不是固定毫秒去抖。火球 cast/launch 共用音源时也按此判断，不手工删重复层或强迫都响。
- InstanceLimited 按源 GO 名计时间窗，从实际 PlayImpl 开始，不按是否仍播放计数；当前启用者全为 SKIP_NEWEST。源码 STOP_OLDEST 倒序且可能删到刚生成自己，这个本池未使用的 bug 没有假装实现成 FIFO，运行时诊断明确标记边界。
- 已实现原类别 ducking 的线性进入/恢复及多个状态取最小值，IgnoreDucking 跳过。本池实际只有 1=FX 与 3=角色 VO；VO 只压 6=环境，不压 BGM 或 FX。没有 category 6 播放者时无可闻 duck 变化。

## 适配边界与验证

既有 Godot 视觉时钟、角色揭示过程和 16 声部安全池保留。普通单发法术依旧绑定本项目既有视觉命中回调；完整 Unity 动画、3D 衰减、距离缩放和服务器 metadata 时钟不在移植范围。源 FSM 内可证明的数值等待、分支、权重、帧 yield 与声音控制已单独还原，不能把这些与未移植部分混为一谈。

`play_history` 只记录实际分配到声部的播放；`original_audio.event_history` 记录请求、排程、取消、缺失和限流。源资产/hash、原 CIL、独立 raw audit、规则回归、自然输入、实际 Master PCM 混音和录屏分开留证。`baseline_audio_audit.json` 是改动前缺漏矩阵，不是最终运行时覆盖声明。
