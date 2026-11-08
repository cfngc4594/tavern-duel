# v31 原召唤资源

此目录保存固定客户端 build **37.0.0.255130.254477** 的原始资源解码结果，不是自画特效或按名称猜选的素材。

## 入口

- `manifest.json`：1385 个对象，以 `cab:path_id` 字符串为键；原 typetree、强引用字段到目标对象的映射、导出文件路径。
- `root_labels`：手牌 Out 小/中/大；在场 In 小/中/大/对手；生成随从友方/对手；Hand/Play/Hidden actor、对手手牌 Out；雪人原画像。
- `minimum_yeti_manifest.json`：固定的 Out22 → In24 最小特效闭包，74 对象，零未解引用。Actor 与画像在主清单内。
- `data/summon_fsm_decoded.json`：原 FSM 状态、动作参数与曲线，不替代代码侧分支选择审计。
- `data/particle_modules.json`：16 个原 ParticleSystem 的全部序列化模块。未把未知枚举或随机算法捏造成已验证语义。
- `data/source_bundle_provenance.json`：19 个实际使用的源 bundle 的 SHA-256、MD5，与固定 build install content key 的一致性核验。
- `data/validation.json`：对象计数和未解边界。

## 几何、动画、纹理

- `.mesh.json` 的 vertices、normals、uv0、colors、submesh triangles 保留原 Unity 局部数值，不重画、不重新拟合。转换坐标、投影与运行时布局由 Godot 适配层负责。
- `.obj` 是 UnityPy 的辅助查看输出：该导出器反转 X 并倒转面绕序。运行时应读 `.mesh.json`，避免重复转换。
- AnimationClip JSON 保留原 keyframe 的时间、值、in/out slopes、weights、Infinity 模式等。非有限浮点编码为字符串 `Infinity`、`-Infinity`、`NaN`，以保持合法 JSON；不能把步进切线改成普通插值。
- `m_LocalEulerAnglesHint` 是原编辑提示字段，不应替代实际 quaternion。
- PNG 为原 Texture2D 解码，原过滤/寻址等参数仍保存在 manifest 对象 data 内。
- 雪人画像由原 CardDef 的 `m_PortraitTexturePath` 强引用 GUID `bebfe051c23dc1247a8012b76e269359` 定位，文件为 `textures/WOW_ACT_105_D__3353938903773336444.png`。
- PathID 超过 JavaScript/Godot JSON 浮点精度，绑定只使用对象 key 与 refs 中的字符串，不能从 data 中的裸数值重建身份。

## Shader

`shaders/*.json` 保存原 Shader serialized state 与编译块；`.shader.txt` 只是 UnityPy 查看输出，不是可直接运行的 Godot shader，也不保证包含 PlayerSubPrograms。Shader 的平台字节码公式、Blend/Cull/ZWrite、UV/空间适配应以独立原 DXBC 分析为准。不能因 shader 名字相近而替换为经验近似。

## 仍需明确的边界

- 普通 rect → oval 主链是原 Hand actor 与 Play actor 的替换，不是把一个矩形 mesh 缩成椭圆。
- 主清单含原 actor 的 inactive、rarity、class、golden 等备选子层。实例化时应保留 prefab/renderer 启用状态，并执行已验证的 Actor 初始化配置，而非把所有子层显示出来。
- 六个 Unity 内置 mesh `10210` 不在提供的原 client bundles 中，涉及 reward、cardback、tutorial、multiclass ribbon 备选 GO。清单保留缺项，未自行画一个平面来冒充原对象。普通雪人 Out22/In24 最小特效及普通 Play portrait/frame 不依赖它们。
- `ManaGem` 的一个精确 CAB/PathID mesh 复用用户提供的旧原解码资源包；已保留源文件 SHA-256，明确 `source_binary_revalidated=false`。其它 44 个 mesh 来自本次已核验的原 bundle。
- 当前缓存中查到的相机属于 silhouette 或特定卡牌效果。未证实普通 GameplayCamera；不能宣称兼容投影就是原客户端相机。
- 本目录是源资源与证据，不单独证明 Godot 运行时的随机采样、GPU 行为、排序、相机、帧调度与原引擎逐像素一致。
