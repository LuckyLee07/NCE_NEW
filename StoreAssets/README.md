# App Store 更新素材

本批素材用于 1.3 商店更新。**修正版使用 `1.3-preview-fix/upload`，预览入口为 `1.3-preview-fix/index.html`，不要再上传 `1.3` 中带外框的旧视频。**不需要把素材目录加入 Xcode 工程。

## 2026-10-07 预览修正

用户提供的审核消息显示：1.3 (1) 因 Guideline 2.3.4 被要求修改预览视频，原因是实际 App 录屏外添加了框架。Submission ID 为 `a4aa7d98-1521-4d7c-b649-c5f985205c4f`，审核设备为 iPad Air 11-inch (M3)。

修正版复用原始录屏与五个场景时间点，仅做剪辑、整幅缩放和编码。已移除外围画布、留白、独立标题与副标题；没有添加文字叠加，也没有放大裁切界面。App 自身的状态栏、导航栏和背景保留。每段约 24 秒，封面参考为第 1 秒。

本次已替换简体、繁体、日语、韩语和加拿大英文的 iPhone/iPad 预览，共 10 段。仍跳过美国英文；目录保留 2 段 en-US 备用文件，不代表要新增该语言页。后台原有 50 张截图保留，不重新设计 Icon 或首页，不修改 App 代码、Version 或 Build。

修正版已完成本地导出与检查：9 项测试通过；12 段视频（含美国英文备用）均完整解码，浏览器逐段播放并抽查全部五个场景；90 张截图/抽帧的本地 OCR 无警告；四种真实界面语言的 iPhone/iPad 联系表已目视复核。60 张截图的哈希、所有录屏来源和剪辑时间点与旧批次一致。

2026-10-07 已通过 Computer Use 完成十段视频替换，逐组核对后台处理后的全屏首页画面，并保存约第 1 秒的封面。展开检查了其他尺寸组，没有残留独立旧预览；受支持的旧尺寸沿用新素材，iPhone Duo 保持空组。部分播放器首次加载失败，重新打开或刷新后恢复；未以“上传完成”代替画面核验。旧视频仅移除引用，文件仍保留在素材库。

15:40 已发送 Guideline 2.3.4 修复说明，15:42 重新提交原有 `1.3 (1)`。刷新后已确认提交及 App 版本均显示 **等待审核**，提交 ID 不变。保留“审核通过后自动发布、立即向所有用户发布、保留现有评分”的原设置；等待审核不代表已通过或已发布。本次上传及提交记录为 `1.3-preview-fix/asc-resubmission-record.json`。

技术清单为 `1.3-preview-fix/manifest.json`，本地生成快照为 `1.3-preview-fix/preview-fix-record.json`，目视记录为 `1.3-preview-fix/review/visual-review.json`。其中本地生成阶段的 `uploaded: false` 等字段是上传前快照，当前后台结果以 `asc-resubmission-record.json` 为准。检查仅覆盖媒体修正，不代表母语审校、全 App 验收或 Apple 审核通过。历史 `1.3` 目录及其上传记录保持原样，以便追溯此次问题。

本次已完成的替换步骤：

1. 在五种语言的媒体管理器中移除带框旧预览引用并上传对应修正版，保留已有截图。
2. 核对处理后的画面及其他尺寸组，保存约第 1 秒的首页封面。
3. 回复审核说明已移除外框和独立标题区，预览现在仅包含真实 App 全屏录制，重新提交 `1.3 (1)`。本次为媒体元数据修正，没有重新上传二进制。

## 历史上传

2026-10-07 之前已通过 Computer Use 上传简体、繁体、日语、韩语和加拿大英文的 iPhone/iPad 素材，共 50 张截图、10 段旧预览；按用户要求跳过美国英文。十组素材曾重新打开核对数量与截图顺序，并保存约 1 秒处的四册首页封面。记录在 `1.3/asc-upload-record.json`；其中“准备提交”是上传时的快照，用户后续已提交审核并收到上述修改要求，不代表当前后台状态。

## 语言与文件

| 目录 | App Store Connect 语言 | 真实 App 界面 |
| --- | --- | --- |
| `zh-Hans` | 简体中文 | 简体中文 |
| `zh-Hant` | 繁体中文 | 繁体中文，共用台湾及香港等地区文案 |
| `ja` | 日语 | 日文 |
| `ko` | 韩语 | 韩文 |
| `en-US` | 英语 美国 | 简体中文，仅作备用，不上传 |
| `en-CA` | 英语 加拿大 | 与美国英文素材相同，不更改原加拿大元数据 |

每种商店语言包含 `iphone` 和 `ipad` 两个目录。每个目录有五张截图、一段 App 预览视频和一张视频封面参考图。合计 60 张上传截图、12 段预览视频、12 张封面参考图。原生界面只有四种语言，英文商店素材不代表提供英文菜单。

## 上传顺序与规格

1. `01-home.png`：四册首页，展示新封面。
2. `02-lesson.png`：英文课文与所选语言译文。
3. `03-word.png`：umbrella 的释义、配图与发音按钮。
4. `04-practice.png`：词义选择练习。
5. `05-wordbook.png`：按学习状态进入的单词列表。

| 文件 | iPhone | iPad |
| --- | --- | --- |
| 五张 PNG 截图 | 1290 × 2796，竖屏 | 2048 × 2732，竖屏 |
| ASC 实际上传分组 | 带灵动岛的 iPhone（大显示屏） | iPad 13 英寸 |
| `app-preview.mp4` | 886 × 1920，竖屏 | 1200 × 1600，竖屏 |
| 视频时长 | 约 24 秒 | 约 24 秒 |
| 视频编码 | H.264 High Level 4.0，30 fps，目标 11 Mbps | 同左 |

在对应语言的媒体管理页面，选择上表的尺寸分组，按编号上传五张 PNG。视频上传到 App 预览区域，不要当截图上传。`preview-poster.png` 是封面选帧参考，不能与五张截图一起上传；预览处理完成后，可将封面时间选在约 1 秒的首页画面，或按商店实际效果选择其他帧。

本次后台使用整秒选帧，十段视频均选择 1 秒处。iPhone 必填的中等显示屏组沿用新大屏素材，不重复上传。经用户确认，已移除 1.3 草稿中简体旧 iPhone/iPad 的四组截图引用，共 20 张；其他语言原先沿用这些旧素材。旧文件仍保留在素材库，已上线的 1.2 不受影响。

修正版视频是实际 App 操作录屏的剪辑，不再附加本地化标题或外框。音轨为静音 AAC 双声道 48 kHz，不包含模拟的 App 发音、旁白或外部配乐。浏览型预览适合静音自动播放，但不能用它检查实际发音质量。截图没有添加营销文字或虚构界面。

## 核验与发布边界

录制使用独立 QA 包 `com.palmgame.NCEALL.resourceqa.storemedia`，不覆盖正式 App，也不接触正式 App 学习数据。素材中广告关闭，练习记录只存在于 QA 容器。原始录屏、XCTest 附件和场景时间保存在清单所引用的本机临时目录。

技术校验检查截图像素、完整性、文件哈希、视频分辨率、时长、码率、帧率、编码及全部帧可解码；另检查课文切句和单词本滚动确实出现在视频内。修正版还将每个场景抽帧与原始录屏缩略图比对，分别检查整幅及四侧边缘的像素差，防止重新加入画布或边框。OCR 结果在对应目录的 `review/text-review.json`，只能辅助核查文字和警告，不能替代母语审校。

各目录 `review` 里的视频抽帧、联系表和浏览器页面截图仅用于检查，不要上传。修正版的美国、加拿大英文素材与简体素材哈希一致；真实界面仍是简体中文，不虚构英文菜单。`review/visual-review.json` 记录目视检查范围，不是全 App 功能验收或审核通过证明。

本次为解决实录发现的日文课文间距问题，统一了课文测量字体与显示字体，并把行内留白纳入行高。截图测试检查前四行英译文本与下一句不重叠。旧版样片已移出交付目录，不应上传。

iPad 学习页面从导航栏下方开始布局，修正了英文单词、练习分数被导航栏遮挡的问题。专项测试验证了搜索框点击、输入、进入单词及练习页顶部边界；四语言录制也检查单词标题和分数行不被遮挡。此改动不影响四册首页布局和 iPhone 页面。

以下项目仍与发布相关，但不属于素材生成完成的证明：

- 录制时的 QA 包版本是 1.2，构建号 1；这些是更新代码的实录。用户审核消息显示正式 1.3 (1) 已上传并受审。本次仅修改媒体，不调整 Version/Build；若之后修改二进制重新上传，则需使用未上传过的更高 Build。本地 QA 编译、截图不占用商店构建号。
- 日文及韩文学习译文仍需母语审校。日文 handbag 配图存在把手提包标成手袋的问题，因此本批没有使用该图；全库配图文字需要单独复核。
- 之前记录的 iOS 26.2 小屏兼容性警告不是本次素材制作所解决的问题。
- 内容授权和真机发布检查需要分别确认。本次后台已逐组检查视频帧和封面，但未逐段完整播放十段视频；完整解码及五场景比对是本地技术检查。已重新提交审核，但不代表审核通过或发布；此次没有更改销售地区、商店文案或构建选择。

## 重新生成

使用已安装 iOS 17.2 的独立大屏 iPhone 和 iPad 模拟器，运行 `Tools/capture_store_media.py`。第二台设备可复用已构建 QA 包，但不得使用正式 App 的 Bundle ID。

```bash
/usr/bin/python3 Tools/capture_store_media.py \
  --device <SIMULATOR_UDID> --label iphone \
  --output /private/tmp/NCEStoreMedia-NewRun
```

两台设备都通过后，使用有 Pillow 的 Python 环境和可运行的 FFmpeg：

```bash
python3 Tools/export_store_media.py \
  --captures /private/tmp/NCEStoreMedia-NewRun \
  --output StoreAssets/1.3-new
```

可以先用 `--device iphone` 导出已完成设备，再通过 `--device ipad --resume` 补齐；只有两台设备完整导出才会生成最终清单和预览页。不要对已经审核或手工调整的交付文件使用未核对的覆盖操作。

本机旧 FFmpeg 使用已安装的兼容 libtiff 时，可添加 `--library-path /opt/homebrew/Cellar/libtiff/4.4.0_1/lib`，仅影响当前工具进程，不修改 Homebrew 或系统库。其他机器应使用自身正常运行的 FFmpeg，无须照搬这个参数。

导出后的检查工具：

```bash
NCE_STORE_MEDIA_ROOT="$PWD/StoreAssets/1.3-preview-fix" \
  python3 -m unittest discover -s Tools/tests -p test_store_media.py
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcrun swift \
  Tools/inspect_store_media.swift "$PWD/StoreAssets/1.3-preview-fix" \
  "$PWD/StoreAssets/1.3-preview-fix/review/text-review.json"
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcrun swift \
  Tools/contact_store_media.swift "$PWD/StoreAssets/1.3-preview-fix"
node Tools/test_store_media_gallery.cjs "$PWD/StoreAssets/1.3-preview-fix"
```

Python 检查需要 Pillow；浏览器检查与现有配图库测试共用 Playwright 和 Chrome 运行环境。macOS Vision 需要能够访问本地系统识别服务，受限执行环境可能需额外允许；识别不上传图片。重新导出会把目视检查状态恢复为待检查，须再次核对新文件。

## Apple 规格依据

- [截图规格](https://developer.apple.com/help/app-store-connect/reference/app-information/screenshot-specifications)
- [App 预览规格](https://developer.apple.com/help/app-store-connect/reference/app-information/app-preview-specifications)
- [App 预览制作建议](https://developer.apple.com/app-store/app-previews/)
- [审核指南：准确元数据与 2.3.4](https://developer.apple.com/app-store/review/guidelines/#accurate-metadata)
- [回复审核消息与重新提交](https://developer.apple.com/help/app-store-connect/manage-submissions-to-app-review/reply-to-app-review-messages)
- [Version 与 Build 规则](https://developer.apple.com/documentation/xcode/preparing-your-app-for-distribution)
