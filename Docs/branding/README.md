# 国际化 Icon 与四册封面

2026-10-06 最终确认版：使用内置 `image_gen`，按用户选定的正中 NCE 字标 Icon 与 C 款手绘封面生成五张正式原图，并替换工程实际使用的 Icon 与八张 iPhone/iPad 封面。没有加入英文界面，也没有改变首页四册布局、设置按钮或学习流程。

## 设计

- Icon：酒红底、四根高低错落的白色手绘书脊、四色腰封；定制粗衬线 `NCE` 字标位于书脊正中，不使用左上角字标或出版社图案。字标是位图设计，不是完整可安装字体。
- 封面：采用此前确认的 C 款细线手绘设计；统一 `New Concept English` 两行衬线标题、白色纸面及 `BOOK 1`–`BOOK 4` 底部标签。酒红、青绿、蓝、金点缀四册，插图分别为书本与对话气泡、双人交流、笔记本与钢笔、书本与台灯；不使用巨型中央编号。
- 简繁体、日文及韩文共享同一套封面，不把地区旗帜或特定语言文字烘焙进图片。VoiceOver 册数标签继续使用现有本地化。
- 新图片未使用出版社封面作为生成参考，也不宣称出版社官方身份；这不替代课文、音频及教材名称的授权核实。

## 文件与导出

完整提示词、用户选定稿和参考关系在 `ContentPipeline/branding/design-spec.json`；五张生成原图在其 `source/`。最初的 Icon 和封面完整备份于 `ContentPipeline/branding/previous/`；上一套立体设计的原图、提示词和 QA 记录保留于 `ContentPipeline/branding/revisions/20261006-before-approved-ink/`。这些目录均不加入 Xcode Resources。

运行资源：`NCE_ALL/Images.xcassets/AppIcon.appiconset/` 与 `NCE_ALL/images/book1.jpg`–`book4.jpg`、`book1_iPad.png`–`book4_iPad.png`。不改资源名，所以首页仍通过原有路径加载。Icon 补齐所有已有槽位；所有导出图片为无透明通道的 RGB，Icon 各尺寸来自同一张正方形原图，其中商店图标导出为 1024×1024，不预切系统圆角。

iPhone 封面 540×756 JPEG，质量 0.84；iPad 封面 630×882 PNG，保持 5:7 比例。19 张 Icon 加八张封面，共 27 张运行资源，合计 4,585,039 字节（约 4.37 MiB）；最初资源合计 5,138,884 字节（约 4.90 MiB），减少约 10.8%。这是资源源文件总量，不等于最终 IPA 的压缩大小。

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcrun swift \
  -module-cache-path /private/tmp/NCEBrandingSwiftModuleCache26 Tools/export_brand_assets.swift
PYTHONDONTWRITEBYTECODE=1 python3 -m unittest discover \
  -s Tools/tests -p 'test_brand_assets.py'
```

`asset-report.json` 记录源图、导出图、原图哈希及尺寸。再次导出不会覆盖原图备份；导出工具只做格式与尺寸处理，不重绘生成插图。

## 校验与发布

- 四项资源测试全部通过：完整性与无透明通道、每个 Icon 槽位尺寸、封面路径与原图备份，以及正式 Icon 四角均为酒红底、没有预览白边或预切圆角。25 张最初旧图备份未被覆盖；六项中文和六项日韩本地化数据测试也通过。
- 构建产物检查通过：八张封面和两个实际打包的 iPhone/iPad Icon 与工程资源的原生解码像素完全一致，`Assets.car` 已编译，原图目录未加入 App。见 `packaged-validation.json`；使用 ImageIO 解码 Xcode 优化 PNG，不把通用 PNG 解码器的格式限制误判为图片损坏。
- 使用现有 `testInternationalBookCovers` 原生 UI 用例，只覆盖本次资源变更：四语言册数标签、四册入口可点击、边界与不重叠、封面比例，并保存真实首页截图。iPhone 12 Pro 与 13 英寸 iPad Pro（iOS 26.2）均通过，共保存八张新首页截图；人工查看了繁体 iPhone 及日文、韩文 iPad 首页，四封面清晰且无遮挡。上一套设计的结果保留在历史目录。
- UI 验证使用独立 `com.palmgame.NCEALL.resourceqa.localization` QA App，关闭广告，不覆盖正式学习记录。
- App Store 图标需随新构建上传；本次不上传构建、截图或提交审核。后续应以新首页重做商店截图，并删除描述中关于保留旧封面的过时说明。应用内其他原配图仍可保留原始文字。

本轮模拟器结果与截图见 `ui-validation.json` 和 `ui-screenshots/`；Debug 构建及 Icon 资源编译通过。本轮未运行 Release 归档或物理设备测试。这些是 QA 证据，不自动等于可直接上传的商店素材；正式素材需另外检查状态栏和系统窗口角标。没有重复验证未改动的广告、音频或全部学习流程。
