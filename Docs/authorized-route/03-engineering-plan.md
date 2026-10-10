# Engineering Plan

本文档把长期路线拆成工程任务，便于后续创建 issue、里程碑和 PR。

## 1. 当前工程基线

当前项目形态：

- Objective-C/UIKit。
- 本地 `NCE.db`。
- 本地课文 mp3/lrc。
- 本地单词 wav/jpg。
- Google AdMob。
- 无账号。
- 无服务端。
- 学习记录写入 Documents 里的数据库。

## 2. P0 工程任务：发布稳定性

### Build Configuration

- 明确 Debug/Release 差异。
- Release 禁用测试广告设备配置。
- Release 使用正式 bundle id、version、build number。
- App Store 归档前检查 `Info.plist` 隐私和广告 key。

### Privacy Configuration

- 如果非个性化广告：
  - 保留 `npa=1` 请求参数。
  - 移除未调用或未使用的 IDFA 请求代码。
  - 移除未使用 ATT framework。
- 如果个性化广告：
  - 建立 ATT 请求时机。
  - 记录用户拒绝后的广告降级路径。

### Core Flow Smoke Test

人工 smoke test 至少覆盖：

- 启动 App。
- 进入四册首页。
- 进入第一册。
- 进入第一课。
- 播放第一句。
- 切到后台继续播放。
- 进入单词学习。
- 播放单词发音。
- 完成一次听写。
- 完成一次英汉选择题。
- 查看单词本。
- 在线词典加载失败不影响返回。

## 3. P1 工程任务：数据层

### Repository 分层

建议新增：

```text
NCE_ALL/Data/
  NCEDatabase.h/.m
  NCERepository.h/.m
  LessonRepository.h/.m
  WordRepository.h/.m
  ProgressStore.h/.m
```

职责：

- `NCEDatabase`：数据库路径、连接、事务、错误日志。
- `NCERepository`：聚合书册和全局配置。
- `LessonRepository`：课程和句子读取。
- `WordRepository`：单词、搜索、词表读取。
- `ProgressStore`：错题、熟悉度、学习记录写入。

### 数据库迁移

新增表：

```sql
CREATE TABLE IF NOT EXISTS schema_version (
  id INTEGER PRIMARY KEY CHECK (id = 1),
  version INTEGER NOT NULL,
  updated_at TEXT NOT NULL
);
```

迁移策略：

- 首次启动复制 bundle 数据库到 Documents。
- 如果 Documents 数据库存在，读取 `schema_version`。
- 按版本顺序执行迁移。
- 每次迁移包裹事务。
- 迁移失败时保留原数据库备份。

### SQL 参数绑定

优先修复位置：

- 单词搜索。
- 错题更新。
- 听写结果更新。
- 单词本筛选。
- 在线词典查询词拼接前 URL encode。

目标：

- Controller 不拼接 SQL。
- 所有字符串参数使用 `sqlite3_bind_text`。
- 所有整数参数使用 `sqlite3_bind_int`。

## 4. P1 工程任务：音频服务

新增：

```text
NCE_ALL/Audio/
  AudioPlaybackService.h/.m
  AudioItem.h/.m
```

能力：

- 播放本地音频。
- 停止、暂停、恢复。
- 设置播放速度。
- 单句完成回调。
- 播放队列。
- 后台播放 session 管理。
- 中断恢复。

替换范围：

- `TextViewController`
- `WordViewController`
- `WordDictationViewController`

验收：

- 三类页面不再各自创建独立的播放策略。
- 后台播放行为一致。
- 音频失败时 UI 可恢复。

## 5. P2 工程任务：学习闭环

### 新增进度字段

建议迁移添加：

```sql
ALTER TABLE words ADD COLUMN review_count INTEGER DEFAULT 0;
ALTER TABLE words ADD COLUMN last_reviewed_at TEXT;
ALTER TABLE words ADD COLUMN next_review_at TEXT;
ALTER TABLE words ADD COLUMN ease REAL DEFAULT 2.5;
ALTER TABLE words ADD COLUMN last_result INTEGER DEFAULT 0;
```

如果 SQLite 版本或旧数据兼容有问题，用新表：

```sql
CREATE TABLE word_progress (
  word_id INTEGER PRIMARY KEY,
  word_status INTEGER DEFAULT 0,
  wrong INTEGER DEFAULT 0,
  review_count INTEGER DEFAULT 0,
  last_reviewed_at TEXT,
  next_review_at TEXT,
  ease REAL DEFAULT 2.5,
  last_result INTEGER DEFAULT 0
);
```

### 今日学习生成

输入：

- 最近课程。
- 未完成课。
- 今日到期复习词。
- 错题。

输出：

- `continue_lesson`
- `review_words`
- `dictation_queue`
- `wrong_words`

## 6. P3 工程任务：内容质量

### 缺失资源报告

新增脚本或工具输出：

- words 总数。
- wav 命中数。
- jpg 命中数。
- lesson sentence 总数。
- mp3 命中数。
- lrc 命中数。

输出文件：

```text
Reports/content-resource-audit.json
Reports/content-resource-audit.md
```

### 内置词典

逐步从 `words` 表扩展：

- 简明英文释义。
- 中文释义。
- 例句。
- 来源课程。
- 发音资源路径。

在线词典作为补充，不作为核心能力。

## 7. P4 工程任务：IAP 与同步

### 去广告 IAP

新增：

```text
NCE_ALL/Purchase/
  PurchaseManager.swift
  EntitlementStore.swift
```

功能：

- 加载商品。
- 购买。
- 恢复购买。
- 本地缓存 entitlement。
- 购买失败和无网络降级。

### iCloud 同步

同步对象：

- word progress。
- lesson progress。
- favorite sentences。
- settings。

原则：

- 本地数据优先。
- 冲突保留最近更新时间。
- 同步失败不阻断学习。

## 8. P5 工程任务：现代化

### Swift 渐进式引入

优先 Swift 化：

- 新数据层。
- 复习算法。
- IAP。
- 设置页。
- 统计页。

### 资源拆包

新增资源 manifest：

```json
{
  "pack_id": "nce-book-2-audio",
  "version": "1.0.0",
  "sha256": "...",
  "size_bytes": 0,
  "required_license": "contract-id"
}
```

下载内容只包含资源和数据，不包含可执行代码。

## 9. 工程优先级

1. 授权证据和发布合规。
2. 数据层收口。
3. 数据库迁移。
4. 音频服务。
5. 今日学习。
6. 间隔复习。
7. 内容资源审计。
8. IAP。
9. iCloud。
10. SwiftUI/Swift 化。

