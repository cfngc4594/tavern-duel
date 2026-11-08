# V35.1 原死亡震动静态证据摘要

范围：client 37.0.0.255130.254477，原Assembly/本地bundle只读；不运行原程序、GPU或GUI，不改生产工程或5834规则，不恢复棋盘广度。

## 可执行结论

1. 英雄死亡 `MainCameraShakerAction.Shake` 0x06016be0 → `Camera.main` → 单例 `CameraShakeMgr`。只改相机世界position，所有主相机内容共同使用视图变化。
2. 每轴 `offset = Random.Range(-amount.axis * curve(progress), +amount.axis * curve(progress))`；position=初次保存基准+offset。先采样，再以scaled Time.deltaTime递增。duration达到后下一次Update恢复基准。
3. 请求不相加。非override且amount²较小拒绝；已有override阻止任何新请求；等量/更大请求可重启，重入不重置基准。停止精确恢复基准并清状态。
4. MainCameraShakerAction的delay在OnUpdate累积timer后触发；到触发时才仲裁。OnEnter只清timer。退出FSM状态不自动停止独立manager。
5. 胜/负/平局敌英雄State3均amount=(.30000001192092896,.30000001192092896,.30000001192092896)、time1、delay0。普通随从death无主相机shake，只有RootObject本地iTweenShakePosition amount=(.1,0,.1)、time.5；DamageSplat兄弟分支不继承这个局部抖。

核心token：Update 0x06015080，长Shake 0x06015081，线性Shake 0x06015082，StartShake 0x06015086，StopShake 0x06015087，UpdateShake 0x06015088，IsHolding 0x0601508a；详见camera_shake.cil.*、shake_actions.cil.*。

## 主相机与覆盖层

主Camera component -2202086695199829704，GO7270617503787520312，CameraShakeMgr3609817286069588280；mask16367875/0xf9c103包含0,1,8,14,15,16,19,20,21,22,23。

|内容|原证据|当前兼容层应否共用camera位移|
|---|---|---|
|敌手/牌库|Card_Hidden及deck原层0|应|
|法力框/晶体/计数|原层0/21；桌面晶体parent到ManaCrystalMgr|应，不能同widget拆开|
|结束按钮|原层0/8|应|
|历史栏|原层0/8/14/19；运行时只在0/8/19切换|应|
|回合TurnIndicator|全7节点14；parent到TurnStartManager|应|
|胜/负TwoScoop、continue/ScoreScreen|Start/Awake运行时显式SetLayer19|应；19只免部分后期|
|玩家姓名NameBanner|70个renderer全13；UpdateAnchor挂OverlayUI|不应跟主相机位移|
|Godot自定义帮助/指针/设置/toast|不是已恢复的原资源对象|明确为自定义overlay，不猜原层|

姓名GUID f579c831653574d4da0437a5fcf0d58f。原NameBanner仍layer13。OverlayUI.Awake只把FindFirstByLayer(18)返回值存m_UICamera：CameraUtils 0x06014c08→0x06014c09测试的是cullingMask & LayerBit(18)，**不是camera GO.layer==18，不是把姓名改18，也未确证该UI camera完整mask**。主mask排13+原OverlayUI挂接足以区分姓名。

姓名Update虽每帧调UpdateAnchor，但基础桌面路径只取bottomLeft/topLeft序列化锚点（CanvasAnchors.GetAnchor 0x06015e52）并设置GameEntity.NameBannerPosition 0x060054a8的常量(0,5,22)/(0,5,-10)。该链不调用OverlayUI.GetRelativePosition或Camera.WorldToScreenPoint，不是随主场景投影的悬浮标签。详见name_anchor_semantics.cil.*。

## 交付索引与验证

- README.md：详细调用关系、原值、时序、仲裁和兼容边界。
- METHOD_LOG.md / source_provenance.json：每方法token/RVA、原程序集及上游CIL SHA256。
- death_shake_original_actions.json / summon_camera_shaker_components.json：原FSM动作和召唤CameraShaker全部字段。
- extra_ui_ownership、overlay_ui_ownership、name_banner_loading、result_screen_ownership、camera_lookup_semantics.cil.*：补齐范围的精确指令。
- SOURCE_HASHES.json：本次全部源CIL、源对象导出、上游manifest与bundle哈希。
- DELIVERABLE_SHA256.json：本目录逐文件SHA256。
- static_validation.json：选中方法全部解析成功，3条英雄路线同.3，普通death相机动作数0。
- shake_oracle_validation.json：10/10 CPU oracle通过：先采样、弱请求拒绝、等量重入不漂基准、到期下一Update停止、精确恢复、override锁、hold越界不snap、零时长清理、scaled进度、同一offset共享。

工具边界：实际调用官方rea-agents6.8.0只读CLI，但其managed metadata超过64MiB表示预算而partial；完整方法证据由已装dnfile/dncil读取原CIL补齐。未称REA完整反编译、未称原运行随机序列或逐帧像素相同。固定2.5D统一位移能修当前分层错位，仍不是原透视的深度视差。
