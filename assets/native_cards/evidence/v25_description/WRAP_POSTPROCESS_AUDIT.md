# 独立换行前后处理审计

2026-11-02，仅只读原源码/原REA IL，不修改移植代码。问题：末行“器。”“晶。”是否漏了原客户端孤字避免或行长均衡？

## 结论
在本build原UberText+UberTextLineWrapper完整已检查路径中，**没有额外Widow/Orphan/BalanceLines后处理或最小末行字符数字段**。不能因为末行短就添加人为平衡规则；它可能来自真实窄区约束，也可能是bounds/Underwear移植差异，应分别验证。

## 调用前
- UberText.SetupTextAndCharacterSize：未命中缓存时，GameStrings lookup（条件启用）→LocalizationFixes→ProcessText→WordWrapString/ResizeTextToFit。
- LocalizationFixes（UberText.cs2633起）只对global::Locale15(thTH)调用FixThai，其余返回原文，zhCN不追加均衡规则。
- ProcessText（2597起）richText=false原样；否则设置material标签，把<b>改<material=1>，</b>改</material>。只有不WordWrap时RemoveLineBreakTagsHardSpace。
- 原正文组件zhCN=9没有locale独立调整；现有调整仅koKR4/zhTW8/thTH15。原FontDef多行行距modifier1.25仍需要，不能混淆为换行后处理。

## Wrapper内部/返回
原DLL SHA256 09fb757690d86a436eafd02d8846f760c3592bf18021388172eb046957bccb7c。
证据文件 `/workspace/scratch/bb17e9e89c3a/name_mesh_probe/text_pipeline/linewrapper-rea.json`。

- WordWrapString token0x060000fa：16条IL，Reset后直接Wrap。
- Wrap token0x060000fb：428条IL，decoded428，truncated0。包含greedy词段循环、bullet、large-word、ellipsis、Underwear等；无按末行字数重排函数。
- 主循环尾后：IL1273–1276 RestoreTextMeshBackup；richText分支IL1304 RemoveLineBreakTagsHardSpace；IL1327 ReplaceUnderscoredAngleBrackets；IL1335 LineCount；IL1343 ret。没有二次逐行balance。
- WordWrapSettings15字段完整：OriginalWidth,Width,Height,Ellipsized,RichText,ResizeToFit,ForceWrapLargeWords,IndentBulletPoints,Alignment,UseUnderwear,UnderwearWidth,UnderwearHeight,UnderwearWidthLocaleAdjustment,UnderwearHeightLocaleAdjustment,UnderwearFlip；无widow控制。

## 中文断点规则与短末行
CanWrapBetween token0x06000106（linebreak-il.txt）：检查字符/标点对，不是句子语义分词。
- 右侧。U+3002(12290)、，U+FF0C(65292)等禁止起行；左侧句号/逗号可产生下一段断点。
- 普通CJK右字符范围允许断点。因此“器。”和“晶。”本身合法：未在句号前断开，仍允许在器/晶前断。
- 部分特殊分支限frFR/deDE或koKR，不能移植成zhCN孤字避让。

## 调用后
ResizeTextToFit会依据原测量结果按characterSize缩放/重新wrap（原字符尺寸，不是字体字号递减）；返回后缓存最终text和charSize，再应用unboundCharSize及alignment。没有末行均衡。

建议：保留原换行规则，先和原Underwear GetFinalContainerWidth、实际TextMesh bounds、初始width/height、原始rich文本/空格/硬换行逐项对照。不要仅因短行观感作补丁。
