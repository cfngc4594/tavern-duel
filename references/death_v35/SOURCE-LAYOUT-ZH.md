# v35 源证据位置

此目录保留本轮只读恢复报告、CIL方法、Shader程序/反汇编/公式验证及资产引用链。报告原文及原始校验清单不重写路径，以下映射说明工程内位置。

- source_flow：同build程序集静态方法日志与语义。不包含原客户端可执行文件。
- source_shaders：六类源Shader程序、指令记录、逐公式CPU验证和移植草稿。运行Shader位于工程shaders目录。
- source_assets：原CardDef/SpellTable/材质/粒子/声音绑定、导出来源和恢复校验。其原报告中的assets目录对应工程assets/original_death_v35，不重复存第二份美术。
- source_assets/audio中的音频来源及事件绑定对应现有assets/original_audio_v30。19条声音与前版原文件SHA相同，运行时复用，不另换音轨。
- source_evidence_sha256.json仅校验此证据副本内文件。各恢复阶段的DELIVERABLE_HASHES保留其完整离线工作目录的原清单，其中下载的bundle、原managed DLL和重复音轨未打包；不能把这些清单误读成当前ZIP的文件清单。
- 原项目总览README-V35-ZH.md区分已移植内容、真实GPU验证和兼容边界。原ProjectedShadow投影后端、Unity原生粒子内部语义及服务器绝对包间距没有被这些静态证据替代。
