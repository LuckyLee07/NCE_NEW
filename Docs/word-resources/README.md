# 单词资源检查与补齐

已完成缺失音频补齐，随后补充小尺寸单词配图。现有课文包、数据库、单词录音和原有图片均不替换；不增加资源下载，也不把生成工具或语音模型带入 App。

## 检查结果

| 项目 | 补齐前 | 补齐后 |
| --- | ---: | ---: |
| 词表记录 | 3,332 | 3,332 |
| 独立单词或短语 | 3,104 | 3,104 |
| 单词音频文件 | 2,889 | 3,099 |
| 无对应音频的独立词条 | 210 | 0 |
| 图片文件 | 1,779 | 3,104 |
| 无对应图片的独立词条 | 1,320 | 0 |

资源文件数不必等于词条数：部分大小写不同的词条共用现有资源，另有一个未被当前词表引用的 `word.wav`，暂予保留。3,104 个独立词条现在都有可读取的音频和图片。本轮还新增 5 张错义替代图，保留原文件，只修正词条映射；因此生成图总数为 1,325，原始缺图补齐数仍是 1,320。

逐词结果见 [检查清单](checklist.md) 和 [当前机器可读报告](current.json)。原始状态保存在 `baseline.json`，解码结果分别保存在 `baseline-decode.json` 与 `current-decode.json`。

2026-10-06 的 [早期二次独立校验](second-validation.json) 保留为历史快照：当时 6,202 个打包资源 SHA-256 一致，26 张图集重切得到的 104 张小图一致；该快照不包含本轮语义修正。当前文件统计以 `current.json` 和 [本轮复核汇总](review-summary.json) 为准。

本轮 1,325 张生成图已完成 AI 视觉/配方复核，记录与当前文件 SHA-256 绑定于 [图片复核记录](image-ai-review.json)，具体修正见 [语义发现](semantic-findings.json)。这**不是人工或出版方内容验收**；两个人工审校表仍无已通过勾选。用户暂时无法解锁 iPhone，真机界面验收明确暂缓，独立签名构建成功不算真机功能通过。本轮也不作教材版权授权结论。

## 新增音频

210 个 WAV 在本机使用 Kokoro 合成，选择英式英语预设 `bf_emma`、0.9 倍语速，输出 24 kHz、单声道、16 位 PCM。它们是 AI 合成发音草稿，不是教材出版方录音，也没有冒充真人录音。

[Kokoro 模型页](https://huggingface.co/hexgrad/Kokoro-82M) 标注模型许可为 Apache-2.0；[kokoro-onnx 项目](https://github.com/thewh1teagle/kokoro-onnx) 标注推理代码许可为 MIT。模型与音色下载地址、固定 SHA-256、生成参数和每个音频的校验值均记录于 [生成记录](generated-audio.json)。这不改变原有教材、音频和图片各自需要确认的授权状态，也不是整个 App 的版权合规结论。

所有新增音频仍标记为 `pending_listening_review`。播放、格式、时长和校验值通过，不等于发音已经人工审校。请使用 [逐条听审清单](listening-review.md) 核对重音、尾音、缩写、地名和外来词。

离线 Whisper `small.en` 对全部 210 条执行无预期词提示的独立识别，并对首轮非精确匹配的 78 条用不同 beam 参数再检查。两轮共 138 条得到精确词面匹配，72 条仍保留听审标记，其中含缩写、英美拼写差异、专名及可能的语音错误；精确识别也不证明重音或自然度合格。[首轮证据](audio-ai-review.json) 与 [第二轮证据](audio-ai-second-pass.json) 保留原始输出。波形未发现静音、削波或文件边缘零留白；这不是尾音完整性的听觉验收，没有上传音频到外部服务。

依据词典音标重新合成 `Antipodes`、`AT&T`、`praying mantis`，修正重音/音节、字母 A 和 mantis 元音；仅替换本流程自己的草稿。旧版本按 SHA-256 存在 `ContentPipeline/word-audio/revisions`，生成记录保留三条 revision。重新合成后仍待人工听审。`Justitieombudsman`、`Kituro`、`Wayle` 等特殊名称的发音保留专项确认要求。

## 名称映射

`NCE_ALL/data/words/resource-index.json` 将数据库词条显式映射到真实文件名。单词学习和听写均通过 `NCEWordResourceStore` 读取，不再依赖文件系统的大小写容错。现有文件没有为消除差异而强行重命名或复制。

六处音频别名和当前四处图片别名列于检查清单。最初五处图片共用关系均已视觉复核；`South` 的州名含义不适用罗盘，另做释义卡。`may`、`march`、`miss`、`press` 的动词/情态含义另做独立图，`May`、`March`、`Miss`、`Press` 保留月份或称谓/新闻语境图。原始文件不变，修正登记在 `ContentPipeline/word-images/semantic-repairs.json`。

## 词表待审

- `Mew Jersey` 的显示已纠正为 `New Jersey`，搜索与答题接受正确拼写，资源和学习记录继续使用旧键。州名拼写依据 [New Jersey 官方网站](https://www.nj.gov/)。
- `St.Petersbrug` 显示为 `St. Petersburg`，答题也接受 `Saint Petersburg`，数据库保留旧键。拼写依据 [当地政府英文页面](https://kvs.gov.spb.ru/en/information/)。
- `Justiteombudsman` 显示拼写已按 [瑞典监察专员官网](https://www.jo.se/om-jo/justitieombudsmannen/) 纠正为 `Justitieombudsman`；官网文字不能验证本条合成音频的瑞典语发音，仍需专项听审。

`NCE_ALL/data/words/editorial-overrides.json` 是可审计的显示/释义/答案覆盖层，不改数据库或学习进度键。专名人工编辑确认仍保留。含 `(title)` 的标签、`Mrs.`、`IBM`、`AT&T`、`cm` 等合成输入处理记录在 `spoken-text-overrides.json`。

## 新增图片

1,325 张生成 JPEG 全部为 **128×128**，质量参数 0.55，总计 **3.35 MiB**，平均约 **2.59 KiB**，最大 **5.44 KiB**。构建流程限制每张不超过 8 KiB。这里只压缩生成图片；原有 1,779 张图片逐一校验，字节不变。

| 类型 | 数量 | 用途 |
| --- | ---: | --- |
| 轻量物体插图 | 155 | 手提包、键盘、茶壶等可识别物体或物体提示 |
| AI 插图 | 120 | 三个单图图源及 29 张四词图集；旧稿与明确共享关系均有登记 |
| 情境提示图 | 514 | 动作、职业、情绪、地名等助记线索，不是实景照片 |
| 关系示意图 | 121 | 时间、方向、数量、重复、明信片结构、岩层等简明示意 |
| 明确标注的释义卡 | 415 | 抽象词、功能词、专名与不宜用通用图标表示的词 |

“文件补齐”不等于每个词都有写实插画。释义卡直接使用词表释义，不用无关照片冒充配图；情境图也不应当当作物体或地理位置的精确描绘。当前是混合型、小体积资源草稿，均标记 `pending_semantic_review`。

浏览 [配图审校预览](image-review.html)，可搜索单词或释义、按类型筛选；[逐词审校表](image-review.md) 保留人工勾选和备注。[生成清单](generated-images.json) 记录每张图的类型、来源、尺寸、体积与 SHA-256。

开源图形采用 [Twemoji 17.0.3](https://github.com/jdecked/twemoji/tree/v17.0.3) 的 **CC BY 4.0** 图形素材，并保留署名、来源和组合/加字/缩图修改说明。选用素材、版本与校验值在 `ContentPipeline/word-images/sources.json`；App 内“设置 → 配图来源与许可”可离线查看署名，完整许可随包保存。此许可只覆盖本次新增开源图形，不替代原有教材和图片的授权确认。

AI 图源是内置图像工具生成的学习插图草稿，不是教材出版方素材，也不是特定历史实物的精确照片。[单图提示词](../../ContentPipeline/word-images/ai-prompts.json)、[首批四词图集记录](../../ContentPipeline/word-images/atlas-001.json) 与 [本轮 100 词生产清单](../../ContentPipeline/word-images/illustration-plan.json) 保存生成来源；后者对应 `atlas-002.json` 至 `atlas-026.json` 的完整提示词和处理步骤，没有使用外部图像 API。App 只携带最终小 JPEG，不携带图集大图、源图标或构建工具。

生成文件使用 `单词名--词条哈希.jpg`，在 `generated-image-map.json` 中显式映射。这样 `Endeavour`（航天飞机）和 `endeavour`（努力）不会因大小写折叠而误用同图。当前四处旧图片别名只保留已复核适用的词义关系。

`anchor` 的乱码已通过覆盖层修正到学习页、搜索、测验和图片提示，不改数据库；`vole`、`bulrush`、`hip`、`CD-ROM`、`asterisk` 也有明确编辑记录和来源。

## 配图生产流程

### 四词一图

后续具象词优先采用用户确认的四词图集方式。一次生成一张 2×2 图集，再确定性切割为四张图；这减少生成调用次数，但不免除每格的词义和裁切检查。

第一批是 `cloakroom`、`lamp-post`、`fire extinguisher`、`windscreen`，固定按**左上、右上、左下、右下**排序。提示词要求白底、主体留白、不越中线、不含文字或边框。分格标签由清单控制，不让模型生成的文字决定文件名。

图集源图保留为 512×512，切割后每格 128×128 PNG，再用同一绘图流程加中文提示并压缩为 JPEG。四个词原来的释义卡已升级为插图；原有教材图片未替换。大图与分格 PNG 只在内容生产目录，不随 App 打包。

```sh
# 先通过内置图像工具生成一张四词图集，保存缩小后的源图与批次清单。
python3 Tools/split_word_image_atlas.py \
  --manifest ContentPipeline/word-images/atlas-001.json

# 只重绘这一批自己的输出，不重绘其他 1,316 张图片。
python3 Tools/build_word_images.py \
  --twemoji-archive <Twemoji-17.0.3.zip> --include-meaning-cards \
  --rebuild-generated --only-words cloakroom lamp-post "fire extinguisher" windscreen
```

早期 `atlas-002` 至 `atlas-026` 将 100 个释义卡词升级为插图。本轮 `atlas-027` 至 `atlas-029` 修正门把手、内存条、支票、书架、长筒袜等图形；`glider` 的滑翔机旧稿已被鸟类图替代，历史生产清单不重写。`bookcase` 图格明确登记也用于 `shelf`。最终 415 张释义卡保持明确标签，不计作 AI 插图。

后续批次从新的 `atlas-030` 等 ID 开始。切割工具拒绝非正方形、奇数尺寸、重复词条、错乱分格顺序，以及覆盖未登记或人工改动过的切片。共享格必须显式登记，不能静默分配给另一词。`atlas-029` 的首稿人物越过中线，已重新编辑并核对完整头部与留白，首稿不进入 App。

本轮已对上述重点词做 AI 语境复核与必要修正：`vole` 为田鼠，`bulrush` 使用香蒲等水生植物提示，`glider` 为滑翔飞行的鸟，`hip` 用髋部提示。`jigsaw`、`capsule`、`print`、`plough`、`superstructure` 的图分别符合当前线锯、容器、印痕、耕地和船舶上部结构的释义。神话与历史人物仍是通用学习图示，不是权威肖像或历史细节复原；专业终审与人工勾选仍独立保留。

### 检查与打包

1. 从原始缺图清单选词，审核 `ContentPipeline/word-images/recipes.txt` 中的逐词图形映射；无准确图形时使用标注释义卡。
2. 固定并校验 Twemoji 版本，只保留实际使用的图标；AI 图像通过内置工具单独生成，保存提示词后压缩到源图目录。
3. 使用 macOS 原生绘图接口组合、加字与编码，输出 128×128 JPEG 和逐图校验记录。构建拒绝覆盖旧图片或人工改动过的新图。
4. 重新生成资源映射与审校预览。逐图检查解码、非空白像素、尺寸、体积、哈希和 App 读取结果，再做人工语义审校。
5. 在模拟器构建产物上重跑相同检查，确认所有图片、索引、署名与许可都随 App 离线打包。

重建命令：

```sh
python3 Tools/build_word_images.py \
  --twemoji-archive <Twemoji-17.0.3.zip> --include-meaning-cards
```

来源 URL 和 ZIP 的固定 SHA-256 见 `sources.json`；普通 App 构建和测试不需要联网或重新下载素材。正常重跑会跳过校验一致的已生成图片；只有显式使用 `--rebuild-generated` 才重绘本流程自己的、校验值未被人工改动的输出。不得用该参数替代对语义错误的审校。

## 最终打包检查

2026-10-06 已以 `NCE_NEW` 的 Release / iphoneos 配置编译，使用 `CODE_SIGNING_ALLOWED=NO`；这是正式配置的编译与打包检查，**不是签名归档、上架或真机运行验收**。

- 源资源与最终 App 内的 6,208 个单词资源文件逐一 SHA-256 一致；数据库哈希不变。
- 1,779 张原有图片逐一与保留清单一致；2,889 条原有录音与早期独立构建产物比较，差异为零。
- 源目录及 App 产物都通过单词测试：14 个 Python 单元测试、6,203 个 WAV/JPEG 的实际解码、3,104 个词条的索引读取，以及生成资源的尺寸、体积、哈希检查。
- 最终课文包通过 20 个 Python 单元测试、四册 8,890 个条目的实际读取与哈希检查、8 条音频抽样解码、并发读取和 9 类错误场景。音频抽样解码不等于逐条课文听审。
- App 单词资源目录不含生产图集/PNG 或 `.DS_Store`；生产图源、工具和语音模型不进入 App。

原始结果见 [最终 Release 资源比较](packaged-release-validation.json)。这些检查确认资源覆盖、完整性与读取流程，不替代人工语义审校、逐条听审、教材授权或真机验收。

### 学习流程回归

所有界面测试使用独立的 `.resourceqa` App 和专用模拟器，不启动正式 App、不修改其学习记录。Debug QA 启动参数只在独立身份下停用广告 SDK/请求；正式 App 与 Release 的广告行为不变，因此不能用本轮结果证明真实广告或广告失败降级已通过。

| 用例 | 验证范围 | 最终结果 |
| --- | --- | --- |
| `testFourBooksAndFirstLessonControls` | 四册首课进入、暂停/播放、前后句控制及截图 | 通过 |
| `testGeneratedImagesAndCorrectedNames` | 10 个图例、正确名称搜索、图文边界、重读后暂停和标记 | 通过最终复测 |
| `testDictationAndBothChoiceTestsComplete` | 听写提交/跳过及两种选择测验各 20 题、结果页返回 | 通过 |
| `testBothRecallModes` | 显示/隐藏词义或英语、恢复配图 | 通过最终复测 |
| `testWordbookMarkSurvivesRelaunch` | 标记陌生、独立 QA App 重启后从单词本读取 | 通过 |
| `testSettingsCredits` | 设置入口及离线 Twemoji/CC BY 4.0 信息 | 通过 |

[初轮原始结果](ui-iphone-initial.json) 为 5 项通过、1 项失败：测试把 `maitre d'hotel` 放错册数；核对数据库后将测试样例改为第四册，[十词复测](ui-iphone-image-retest.json) 通过。本轮也修复设置表被导航栏遮挡、课名挤占箭头、词条错拼显示/答题兼容、含撇号词条的状态更新，以及“暂停后重读”未恢复暂停按钮的问题。

[最终回归结果](ui-iphone-final-retest.json) 的 2 个用例全部通过，专门再次检查十词图例的重读/暂停及两种回想模式。以上结果来自初轮及明确的复测组合，不伪称初轮一次全量通过；覆盖的是列出的样例与流程，不是所有课程逐屏人工验收。

### 小屏与 iPad

iPhone 13 mini 与 13 英寸 iPad Pro（均为 iOS 26.2 模拟器）各通过 2 个专项用例：长词/长释义样例及离线许可页。实际点击、图文不重叠及窗口边界均检查；保留 [小屏原始结果](ui-small-iphone-layout.json) 与 [iPad 原始结果](ui-ipad-layout.json)。长词、长释义和许可页的整屏截图存于 `ui-screenshots/`。

小屏最初使用 `XCUIApplication.screenshot` 和应用根节点边界时，截图被裁切，新增的边界断言也失败；[失败历史](ui-small-iphone-application-bounds.json) 未删除。改用 `XCUIScreen` 整屏捕获及实际 App 窗口坐标后通过，截图已视觉确认长词与配图完整。该小屏模拟器仍显示兼容视口、上下留白及系统诊断条；本次只确认当前 App 窗口内布局，不宣称小屏真机原生全屏适配通过。

## 剩余验收

| 项目 | 当前状态 | 放行条件 |
| --- | --- | --- |
| 新增图片的人工/专业语义终审 | AI 已复核 1,325 张，人工通过数为 0 | 按 `image-review.md` 实际审校并记录结论；原有 1,779 张图片不包含在本轮完整语义审校范围内 |
| 新增录音的人工听审 | 210 条已有波形及独立识别证据，人工通过数为 0 | 核对全部 210 条的发音、重音与自然度；优先检查 72 条非精确识别和特殊名称 |
| 特殊名称发音 | `Justitieombudsman`、`Kituro`、`Wayle` 保留专项要求 | 由熟悉相应语言/名称的人确认，不能只凭英文 ASR 放行 |
| 真机界面验收 | 用户暂时无法解锁，按要求暂缓 | 在独立 QA App 上完成，不覆盖原 App 或学习记录 |
| 广告、外部词典、后台/中断音频 | 不属于本轮离线资源 UI 通过结论 | 另行执行有网络、真实设备和系统中断场景的检查 |

不得因机器检查通过而自动勾选两个内容审校表，也不得把本轮结果描述为全部内容已获人工或出版方验收。

## 重跑检查

从仓库根目录执行：

```sh
bash Tools/test_word_resources.sh
```

更新清单和名称映射前先重新解码：

```sh
xcrun clang -fobjc-arc -framework Foundation -framework AVFoundation \
  -framework ImageIO -framework CoreGraphics \
  Tools/tests/word_resource_decoder.m -o /tmp/nce-word-decoder
/tmp/nce-word-decoder NCE_ALL/data/words Docs/word-resources/current-decode.json
python3 Tools/audit_word_resources.py \
  --validation Docs/word-resources/current-decode.json \
  --baseline Docs/word-resources/baseline.json \
  --checklist Docs/word-resources/checklist.md --write-index
```

补音频脚本只生成原始清单中缺失的文件，拒绝覆盖现有录音。需要重新生成时，先在独立 Python 环境安装 `Tools/word_tts_requirements.txt`，按生成记录里的地址获取并校验模型与音色，再执行 `Tools/generate_missing_word_audio.py --model-dir <模型目录>`。正常 App 构建、测试和运行均不需要安装 TTS 工具。
