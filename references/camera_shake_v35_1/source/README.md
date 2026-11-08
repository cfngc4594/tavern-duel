# v35.1 死亡震动：原对象、层、时序与修复边界

范围：原视觉 build **37.0.0.255130.254477**，当前普通模式基础英雄与普通随从。只读原程序集/原资产，未运行原客户端、GPU或GUI，不修改历史5834规则。MOP/3D棋盘整轮恢复已暂停；此次只取修复分层晃动所需证据。

## 可直接用于修复的结论

1. **英雄死亡震的是主相机，不是逐个对象。** `MainCameraShakerAction.Shake` **0x06016be0** 直接取 `Camera.main`，调用 `CameraShakeMgr.Shake`。`UpdateShake` **0x06015088** 设置该相机 **世界 position = 首次保存的 initialPos + 三轴随机 offset**，从不移动棋盘物体、相机父对象、rotation或fieldOfView。所有经该相机绘制的物体用同一视图矩阵。
2. **法力、敌方手牌、牌库、结束按钮都在该相机的范围。** 不应因为它们看起来像UI就固定在屏幕上。资产证据和原加载方法见下表。把同一法力部件的框/晶体/文字或牌库厚度/牌背分开震，是兼容层错误，不是原版层分离。
3. **普通随从自身死亡没有屏幕震动动作。** 当前type5只有 `RootObject` 的 iTweenShakePosition，amount=(.1,0,.1)、time=.5、delay0、space0(world)、realTime=false。不是整个Actor，也不是DamageSplat所在的Actor/Spells兄弟分支。不能为修英雄屏幕震而让这些兄弟分支跟本体局部抖。
4. **英雄死亡另有独立的随从受冲击摇动。** 同一State3还有 ShakeMinionsAction(type2, all0, size3, custom .1, radius5)，通过 MinionShake/原Animator作用到符合范围的随从。它与相机抖、死亡RootObject抖是三种不同机制，不可合成一个全局随机振幅。
5. **同一主相机只保留一个CameraShakeMgr状态，不把各特效的shake相加。** 较小amount拒绝，等大或更大请求可重启；既有override阻止任何新请求直到停止。所有主相机内容在每帧共同使用最终一次采样，不可召唤取旧offset、战斗取部分offset、终局/棋盘取最终offset。

## 当前四类world UI的可核验归属

原非Phone相机由 `Gameplay.OnBoardLoaded` **0x06005826** 加载 `BoardCameras.prefab:b4f3a6717904ff34985655c86149f06c`；`OnBoardCamerasLoaded` **0x06005828** 将其根parent设到Board。原camera root为identity，Main Camera没有子camera，CameraShakeMgr与Camera在同一个GO。

`../source_shake_assets/board_cameras_source.json`：Main Camera pathID **-2202086695199829704**；GO **7270617503787520312**；CameraShakeMgr **3609817286069588280**。mask **16367875 = 0xf9c103**，包含层 **0,1,8,14,15,16,19,20,21,22,23**。完整原层名在 `SUMMARY.json` 和 `v32_work/source_code/global_layer_names.json`。

| 类别 | 原静态层/节点 | 运行时归属证据 |
|---|---|---|
| 隐藏敌方手牌 | Card_Hidden GUID **1a94649d257bc284ca6e2962f634a8b9**，31节点全layer0 | Card.DetermineActorPathForZone **0x06012e9b**：hidden定义在hand zone3返回这个prefab。Card.FinishActorLoad **0x06012e11**只有战吼源特判改layer19，19仍在主mask内 |
| 友/敌牌库 | Zone_Friendly_Deck 151节点、Zone_Opposing_Deck 29节点，全layer0，祖先ZoneMgr/BoardStandardGame | 普通board layout与摄像机独立实例化，非camera子树并不表示固定UI |
| 法力晶体/计数 | ManaCrystalMgr、ManaCounter_Friendly/Opposing为layer0；Resource晶体53节点为0/21 | ManaCrystalMgr.LoadCrystalCallback **0x06005b58 IL014e–016a**：桌面分支parent到manager并localPosition=0，不进入GUI camera |
| 结束回合按钮 | EndTurnButton GUID **313ebd8bcb770a944be3633ad928096b**，18节点为layer0/8 | Gameplay.OnEndTurnButtonLoaded **0x0600582c**保留普通棋盘按钮对象，没有切入独立UI camera的逻辑 |

详细原GO/祖先/renderer路径：`../source_shake_assets/hand_mana_layer_source.json`、`hand_deck_endturn_layer_source.json`。只核这次可达基础对象，不把结论泛化到所有游戏模式/所有UI。

### 补齐的历史、姓名、回合提示与结算分层

这四类不能笼统称为UI并统一移动或统一固定。资产层与运行时链共同给出以下范围：

- **历史栏随主相机。** BoardStandardGame/HistoryManager为layer8，相关HistoryTile/箭头渲染节点在0/8/14/19。运行时 `HistoryManager.FadeVignetteIn` **0x0600592b**把tiles和manager改19；`FadeVignetteOut` **0x0600592c**把tile collider恢复0、manager恢复8；`OnFullScreenEffectOutFinished` **0x0600592d**把tile actor恢复0。所有路径仍在主mask，不会进入固定GUI。详见 `extra_ui_ownership.cil.*` 与 `../source_shake_assets/history_banner_turn_layer_source.json`。
- **回合提示随主相机。** TurnIndicator GUID **eb380f78748e2b9479aae6aff3d09d5f**，CAB-69c88b234dfa427e02d1fcee9337ae34:5686996374379425036，7节点全layer14。`<InstantiateTurnStartIndicator>d__31.MoveNext` **0x06006305 IL00b9–00ca**把实例parent到TurnStartManager；`TurnStartIndicator.Start/Show` **0x06016042/0x06016045**设置世界位置和动画，不改layer、不改到OverlayUI。详见 `overlay_ui_ownership.cil.*` 与 `playername_turnindicator_layer_source.json`。
- **玩家姓名应保持独立覆盖层。** `Gameplay.OnTransitionFinished` **0x06005838**的非Phone路径加载 `NameBanner.prefab:f579c831653574d4da0437a5fcf0d58f`。真实根 CAB-82d08c8cc01bd15ce55e7d57190fd3af:-8329923226233505397，107节点中106在layer13 BackgroundUI，**70个renderer全部layer13**，不在主mask；唯一layer0是无renderer的ArenaEndOfMatchRecord WidgetInstance。`NameBanner.Initialize` **0x06005d29** → `UpdateAnchor` **0x06005d31** → `OverlayUI.AddGameObject` **0x06015e59** → CanvasAnchors.GetAnchor/AttachAndPreserveLocalTransform，保留原层。OverlayUI.Awake **0x06015e55**只把FindFirstByLayer(18)返回值存入m_UICamera，用于UI坐标转换；**0x06014c08→0x06014c09**实际测试camera.cullingMask & LayerBit(18)，不是camera.gameObject.layer==18，也没有把NameBanner改成18。不能据此断言UI camera的完整mask，但可明确layer13姓名不经本次被震的Main Camera。姓名从world统一变换中分离有依据，并非漏震。详见 `name_banner_loading.cil.*`、`extra_ui_ownership.cil.*`、`overlay_ui_ownership.cil.*` 和 `../source_shake_assets/name_banner_layer_source.json`。
- **胜/负结算TwoScoop属于主相机layer19，而非固定GUI。** `EndGameTwoScoop.Start` **0x06004d8d IL0000–0008**对自身gameObject执行SetLayer(19)；`EndGameScreen.Awake` **0x06004cc8 IL0104–0134**把continueText/hitbox设19；`ShowScoreScreen` **0x06004ce9 IL0043–004a**也设19。19只豁免部分全屏后期，不豁免camera位置变化。当前终局流程通常在英雄death结束后显示结果，不能以缺少同时抖动的观察反推它属于固定GUI。若Godot保留独立CanvasLayer以实现后期豁免，应让该层在相机shake仍活动时消费同一相机位移。详见 `result_screen_ownership.cil.*`。

**姓名每帧锚点复核：** `NameBanner.Update` **0x06005d1c**确实每帧调用UpdateAnchor，但基础非Phone路径选择的是OverlayUI heightScale的bottomLeft(5)或topLeft(7)。`CanvasAnchors.GetAnchor` **0x06015e52**仅按枚举返回序列化Transform字段；`AttachAndPreserveLocalTransform` **0x06015002**仅换parent并恢复local；`GameEntity.NameBannerPosition` **0x060054a8**返回常量side1=(0,5,22)、其他=(0,5,-10)。此调用链不使用Camera.main或WorldToScreenPoint。OverlayUI.GetRelativePosition虽提供世界坐标转UI功能，但NameBanner这条链没有调用它。因此已证基础桌面路径不是将被震场景锚点每帧投影到固定UI；不将基础GameEntity方法推广为所有特殊模式override。见 `name_anchor_semantics.cil.*`。

以上层摘要和renderer逐条路径在 `../source_shake_assets/ADDITIONAL_UI_SUMMARY.json`。Godot自定义调试帮助、光标、设置、toast不自动拥有任何原UI的归属；应明确列为兼容层界面，不凭名字猜原层。

### 独立覆盖层的边界

`CameraManager.Initialize` iterator **0x06011d7c** 从 `PegUI.orthographicUICam`取得独立UI相机。`CameraManager.set_BaseCamera` **0x06011d73** 把它加入主相机URP cameraStack，**Add不是Transform reparent**。`MainCamera.Awake` **0x06014684**另外把FindFirstByLayer(18)找到的相机加入stack。此查找按camera.cullingMask包含BattleNet位18进行，不按camera GO.layer进行，见`camera_lookup_semantics.cil.*`。主相机prefab没有这些子camera。MainCameraShakerAction只明确震Camera.main，不包含“遍历整个stack使所有camera震”的代码。

因此不能声称所有屏幕覆盖层都应震；也不能用独立GUI存在来解释上述四类world UI不动。全局PegUI/BattleNet各自具体屏幕内容不属于本次完整恢复范围。若未来要动菜单/聊天/好友/指针，应先核其实际归属。**Layer19名为IgnoreFullScreenEffects仍在主camera mask，忽略后处理不等于忽略相机震动。**

## 原动作和时序

原三条terminal路线来自 `death_shake_original_actions.json`，均在 **State 3** 有同值动作：amount=(0.30000001192092896,0.30000001192092896,0.30000001192092896)、time=1、delay=0。

- 胜利37的敌英雄：State3名义进入时间Action+.40000000596 scaled seconds。
- 失败38的己方英雄：Action+.5 scaled seconds。
- 平局39的敌英雄：Action+.5加一次RandomWait(.10000000149..30000001192) scaled seconds。基础己英雄39会被原路由改38。
- 这些是状态名义入口，不是精确墙钟时刻；原AnimateFloatV2显式FINISHED与PlayMaker帧边界在旧v33证据中已有说明。

`MainCameraShakerAction.OnEnter` **0x06016bde**只清timer=0、fired=false。`OnUpdate` **0x06016bdf**先 `timer += Time.deltaTime`，再在timer>=delay且尚未fired时启动shake。即使delay0也在OnUpdate触发，不是OnEnter，也不能凭此固定加1/60秒。动作timer达到delay+time时才发m_FinishedEvent并Finish。

三个动作的m_FinishedEvent为空；Win/Lose State3的AnimateFloatV2在.8s显式发FINISHED可以先离开State3。该MainCameraShakerAction类没有OnExit停止逻辑，独立CameraShakeMgr仍运行至1s。不要在State3退出时清shake，也不要把1s当State3强制等待时间。

## CameraShakeMgr完整算法

原方法与分支偏移在 `camera_shake.cil.txt`；全部token属于Assembly-CSharp.dll，不能跨程序集误用。

- `Shake(camera,amount,time)` **0x06015082** 构造 `AnimationCurve.Linear(0,1,time,0)`，hold=null、isOverride=false。
- `Shake(camera,amount,curve,hold,override)` **0x06015081** 要求camera存在且Options.GetBool(110)为true；复用camera同GO上的CameraShakeMgr，缺失才AddComponent。null/空/末key.time<=0曲线：已有manager就StopShake；没有manager则返回。
- `StartShake` **0x06015086**：若incoming非override且amount²小于当前amount²，拒绝；随后若当前m_isOverride为true，拒绝。否则替换amount/curve/hold/override。首次从未started时保存世界position，重入不会用当前抖动位置重置基准；progress=0，duration=末key.time。
- `Update` **0x06015080**：未started返回；若progress>=duration且不是hold，StopShake并return；否则UpdateShake。
- `UpdateShake` **0x06015088**：**先采样再递增**。intensity=curve.Evaluate(progress)；三个轴分别Random.Range(-amount.axis*intensity,+amount.axis*intensity)；camera.worldPosition=initialPos+offset。hold则不推进，否则progress=min(progress+Time.deltaTime,duration)。原不是sine、不累计随机游走、不按delta乘offset，也不一次性取圆球方向。
- `IsHolding` **0x0601508a**：holdAtSec有值且progress>=holdAtSec。因为检查/递增顺序，可能跨过hold阈值后停在第一个达到阈值的progress，不应发明强制snap到hold阈值。
- `StopShake` **0x06015087**：若started，精确还原initialPos；随后amount=zero、curve=null、hold=null、override=false、started=false。
- `Stop(camera,time)` **0x06015083**：time<=0直接Stop；time>0以当前强度到0建线性曲线再走StartShake，因此已有override仍遵循同一拒绝逻辑。

原Unity每帧Random.Range流、Animator native blend kernel、同优先级MonoBehaviour的回调排序不能由CIL恢复。不能标称随机逐帧像素相同，但这些边界不妨碍复刻单例仲裁、scaled进度、一次采样及同一渲染矩阵。

### 同一管理器的召唤请求

`CameraShaker.StartShake` **0x0601508c**从component读取m_Amount、完整m_IntensityCurve、m_Hold/m_HoldAtSec、m_IsOverride，再对Camera.main调用同一个 `CameraShakeMgr.Shake`。它不是MainCameraShakerAction，触发延迟由其原FSM InvokeMethod事件负责；不能额外复制MainCameraShakerAction自己的timer。已从既有v31原manifest抽取 `summon_camera_shaker_components.json`：

- play_in_medium：组件CAB-824a57d31e8915d6162164fd62a4305d:-2572546672156582894，amount各轴0.10000000149011612，curve(0,1)→(.25,0)，两端slope=-4，hold0、override0。
- play_in_large：组件同CAB:5311267106057970181，amount各轴0.4000000059604645，curve(0,1)→(.3999999761581421,0)，两端slope=-2.500000238418579，hold0、override0。
- hand_actor上的另一个CameraShaker curve为空。空curve若被真正调用须遵循manager的Stop语义，不能擅自补默认衰减。

保留原component字段而非根据视觉手填；以source FSM实际触发事件决定是否/何时提交这些请求。

## 当前Godot兼容层的最小修复合同

以下为基于本报告证据的集成要求：

1. 从各来源收集相机shake请求，保留原触发帧和scaled参数；让共享manager完成原大小/override仲裁，每展示帧只采样一次。
2. 所有已证主相机内容在同一时刻消费同一最终offset或共同视图/合成变换，包含棋盘、2D/3D卡牌、碎片、法力、敌手、牌库、结束按钮。不要逐补漏项后继续保留各自时序。
3. RootObject局部death shake和独立MinionShake依然只作用原对象范围，再共同经过camera投影；DamageSplat不应获得RootObject局部抖。
4. 若保留当前固定15°正交/2D棋盘，统一画面位移只是**现有投影下的兼容映射**。原相机是透视FOV34.870445251464844，三轴世界位移有深度相关视差；不能声称统一2D平移恢复了完整原透视，也不必借此扩大为整棋盘重做。
5. 原camera向+x移动时场景投影相对向-x移动；保留当前坐标桥时应明确这是camera位移还是等价world位移。对称随机边缘分布不会证明每帧符号映射正确。
6. 验证一次英雄爆炸、胜/负/平局、同时combat+endgame请求、零时长Stop、停止精确归零、重复请求较小/相同/更大、缩放时间、重开清理，以及普通随从死亡没有新增screen shake。法力框/晶体/计数、牌库厚度/牌背必须同帧位移一致。

## 证据工具边界

按用户要求实际调用了已安装官方 **rea-agents@6.8.0** 的隔离只读CLI `inspect-managed-members`。`rea_shake_members.json`确认assembly SHA256/MVID和CameraShakeMgr/CameraShaker/MainCameraShakerAction类型，但报64MiB metadata representation resource-limit，methods/fields为空不代表不存在。继续用既有dnfile/dncil静态CIL解析闭合完整方法，而不是停在unknown。没有注册MCP、没有执行原DLL。`METHOD_LOG.md`、`source_provenance.json`、`static_validation.json`列完整来源与检查。
