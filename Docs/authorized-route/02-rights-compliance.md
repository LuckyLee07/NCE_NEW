# Rights And Compliance Plan

本文档用于“正式授权路线”的合规落地。它不是法律意见；正式发布前应由权利方或法律顾问确认授权文本。

## 1. 版权授权门槛

### 必须确认的授权范围

| 项目 | 必须覆盖 | 证据 |
| --- | --- | --- |
| 英文课文 | App 内展示、离线存储、截图展示 | 授权合同或邮件确认 |
| 中文翻译 | App 内展示、离线存储、截图展示 | 授权合同或邮件确认 |
| 课文音频 | App 内播放、后台播放、离线存储 | 授权合同或录音版权证明 |
| 单词音频 | App 内播放、离线存储 | 授权合同或录音版权证明 |
| 词表/释义 | App 内学习、搜索、测试 | 授权合同或来源说明 |
| 封面/图片 | App 内展示、商店截图和宣传 | 授权合同或图片素材授权 |
| 品牌名称 | App 名、关键词、描述、截图、图标 | 商标/品牌使用授权 |
| 商业化 | AdMob 广告、IAP、去广告、课程包 | 授权合同明确允许 |
| 地区 | App Store 目标销售地区 | 授权合同明确地区 |
| 期限 | 上架期限、续约、到期处理 | 授权合同明确期限 |

### 不允许带缺口发布的情况

- 只有实体书或音频购买凭证，没有复制分发授权。
- 只有文字授权，没有音频授权。
- 只有课程内容授权，没有品牌名称/封面使用授权。
- 授权只覆盖非商业用途，但 App 有广告或 IAP。
- 授权只覆盖单一地区，但 App Store 面向其他地区开放。
- 授权到期后没有下架、替换或续约机制。

## 2. 授权证据管理

建议建立内部目录：

```text
RightsEvidence/
  contracts/
  correspondence/
  asset-mapping/
  renewal-calendar/
  app-review-notes/
```

每类资产建立映射：

| asset_id | asset_type | app_path | source | rights_document | allowed_use | expiry |
| --- | --- | --- | --- | --- | --- | --- |

示例：

```text
N1_L001_S001 | lesson_audio | data/lessons/mp3/... | publisher master audio | contract-2026-001.pdf | iOS offline playback | 2029-12-31
```

## 3. Apple App Store 合规

### App Review 重点

- 知识产权：只能提交自己创建或有权使用的内容。
- App 完整性：不能只是空壳、链接集合或未完成样板。
- IAP：App 内数字功能/内容解锁通常使用 In-App Purchase。
- 隐私：声明自身和第三方 SDK 收集的数据。

### 审核备注建议

在 `App Review Notes` 中准备简短说明：

```text
This app includes licensed New Concept English learning content. We have rights to distribute the included text, translation, audio, vocabulary, and related learning materials in this iOS app. Documentation can be provided upon request.
```

如果授权方允许，可以附：

- 授权方名称。
- 合同编号。
- 授权范围摘要。
- 联系邮箱。

不要在审核备注中粘贴完整合同，除非 Apple 要求。

## 4. 隐私与追踪

### 推荐路线：非个性化广告

默认建议：

- 使用非个性化广告请求。
- 不请求 IDFA。
- 移除未使用的 ATT 代码。
- 不保留无用的 `NSUserTrackingUsageDescription`。
- 隐私政策说明 AdMob 可能收集设备信息、IP、广告互动数据等。

### 个性化广告路线

如果需要个性化广告：

- 实现 ATT 弹窗。
- 说明请求追踪的原因。
- 用户拒绝后仍可正常学习。
- App Store Connect 隐私问答必须声明追踪。
- 隐私政策必须覆盖广告追踪用途。

## 5. 第三方 SDK 合规

当前项目相关 SDK/库：

- GoogleMobileAds。
- GoogleUtilities。
- GoogleAppMeasurement。
- UserMessagingPlatform。
- MBProgressHUD。

发布前检查：

- SDK 是否为最新可用稳定版。
- 是否包含隐私清单。
- 是否涉及 required reason APIs。
- 是否需要签名要求。
- 是否更新了 SKAdNetwork 列表。
- 是否有第三方 SDK 数据收集需要填入 App Privacy。

## 6. 官方参考

发布前应重新核对这些官方页面：

- Apple App Privacy Details: https://developer.apple.com/app-store/app-privacy-details/
- Apple App Review Guidelines: https://developer.apple.com/app-store/review/guidelines/
- Apple Third-party SDK requirements: https://developer.apple.com/support/third-party-SDK-requirements/
- Google AdMob iOS Privacy Strategies: https://developers.google.com/admob/ios/privacy/strategies

本文件最后整理日期：2026-06-11。每次提交审核前都应重新核对官方页面。

