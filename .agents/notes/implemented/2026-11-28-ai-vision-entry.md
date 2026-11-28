# 图片识账：用用户自配视觉模型替代端上 OCR

**结论**：删除 ML Kit/端上 OCR，把现有「截图识账」的 OCR 调用替换成一次视觉模型请求；保持现有入口、加载态和跳转路径不变——选图后直接识别并进入记账页，不新增页面、不新增图片模式、不需要用户再点一次「解析」。AI 设置里增加视觉能力检测。目标 arm64 APK 从 44.9 MB 降到约 31.6 MB（以实际构建产物为准）。

> 状态：已实现（2026-11-28）。系统当前事实以源码、测试和 `docs/` 为准；本文保留当时的设计与取舍。

---

## 1. 背景

### 1.1 现状链路

```
AI 记账弹层 → 点「截图识账」→ 弹层关闭 → 相册选图
→ 端上 ML Kit OCR → OCR 文本
→ requestCapturedEntryDraft()（AI 文本解析）
→ EntryDetailPage 草稿 → 用户确认
```

涉及文件：

- `lib/app/screenshot_recognizer_io.dart`：ML Kit 中文识别器。
- `lib/pages/capture_entry.dart`：相册选图、分享图片、OCR、AI 解析、加载/错误弹窗。
- `lib/pages/ai_entry_sheet.dart`：AI 记账弹层（文字 + 截图识账入口）。
- `lib/app/ai/ai_entry_parser.dart`：文本解析提示词与 `requestCapturedEntryDraft`。
- `android/app/build.gradle.kts`：显式引入 `com.google.mlkit:text-recognition-chinese`。
- `android/app/proguard-rules.pro`：ML Kit 的 R8 keep/dontwarn 规则。

### 1.2 体积事实

v1.21.2 的 GitHub arm64 release APK（44.9 MB）拆包统计：

| 组成 | 压缩后 | 占比 |
| --- | ---: | ---: |
| Dart AOT `libapp.so` | 15.5 MB | 34.7% |
| Flutter 引擎 `libflutter.so` | 11.7 MB | 26.2% |
| ML Kit OCR 原生库 | 11.1 MB | 24.8% |
| ML Kit OCR 模型 | 1.9 MB | 4.3% |
| 其余 dex / assets / 资源 | 4.7 MB | 10% |

- OCR 合计约 **13.0 MB，占 29.1%**；移除后 arm64 APK 约 **31.6 MB**。
- AAB 97.7 MB 包含三套 ABI；移除 OCR 后预计约 62 MB。
- 之前已通过 `--split-per-abi` 剔除另外两套 OCR 原生库（约 62 MB → 44 MB），构建侧能省的已经省过。

### 1.3 为什么改

- OCR 使用率很低，却为所有用户承担 13 MB 体积和 ML Kit 的 R8/真机维护成本。
- OCR 只负责“把图读成字”，真正的记账理解仍由用户的 AI 完成；两步识别会叠加错误。
- 用户本来就在配置自己的 OpenAI 兼容端点；直接让视觉模型读图，准确性由用户选择的模型决定。
- 用户主动选图/分享图片就是明确的发送意图，不需要额外的上传确认。

### 1.4 与 PR #86 的关系

PR #86 是 Dependabot 的 6 项 pub 升级，其中 `google_mlkit_text_recognition` 1.0.3 只是 OCR 依赖的主版本升级；本提案会删除该依赖，因此 #86 暂不处理。

---

## 2. 目标与非目标

### 目标

1. 删除端上 OCR 和 ML Kit 依赖，APK/AAB 体积下降约 13 MB（arm64）。
2. 把「截图识账」的 OCR 调用替换成视觉模型请求：选图 → 识别 → `EntryDetailPage` 草稿；**选图后不再需要用户点「解析」**。
3. 在 AI 设置中增加视觉能力检测；不支持视觉的模型不能成功产出图片草稿。
4. 保持现有入口、加载态、错误提示和跳转路径；不新增独立页面、不新增图片预览模式。
5. 图片不落库、不留存；只在本次请求的内存中存在。
6. 同步更新隐私政策、产品文档、验收清单、CHANGELOG 和 `AGENTS.md`。

### 非目标

- 不做相机拍照入口（本期只保留相册 + 系统分享）。
- 不做 AI 对话/账目问答的图片输入（仍为纯文本）。
- 不做多图上传、批量识图。
- 不把识别图片自动保存为交易附件；图片识别后丢弃。
- 不保留 OCR 兜底，也不做本地视觉模型。
- 不新增 AI 记账页面/图片模式/图片预览，不改文字记账的交互。
- 不改数据库 schema、备份格式和账目口径。

---

## 3. 目标链路

### 3.1 App 内图片记账（替代 OCR 的那一条）

```
AI 记账弹层
  [文字输入] [图片识账] [解析]
        │
        └─ 点「图片识账」→ 弹层关闭
             ↓
        相册选图（取消则什么都不发生）
             ↓
        现有模态加载：「正在识别账单内容…」
             ↓
        requestVisionEntryDraft()（一次视觉请求）
             ↓
        EntryDetailPage 草稿 → 用户确认/修改/保存
```

- **没有第二次「解析」**：选图完成即上传识别，成功后直接进记账页。
- 「解析」按钮只属于文字输入；图片路径不经过它。
- 没有图片预览页、没有图片模式、没有独立页面。
- 加载/错误沿用现有 `_runCaptureParse` 的模态框与本地化错误。

### 3.2 系统分享/Intent

| 入口 | 新行为 |
| --- | --- |
| 系统分享图片 | `consumeCaptureImage` → `startImageEntry(sharedImageBytes: bytes)` → 与 3.1 同一条视觉链路 |
| 系统分享文本 | `consumeCaptureText` → `startCapturedTextEntry`（保持现状，文本 AI） |
| `CAPTURE_TEXT` Intent | 同上，文本 AI |
| 分享图片 + 文本同时到达 | 图片优先；文本消费后丢弃，不参与识别 |

- 应用锁启用时 Shell 仍先等解锁，再消费原生队列。
- 分享图片 25 MB 原生上限保留；超过即拒绝。
- 分享消费与快速记账/数字键盘共用 Shell 单飞，避免叠加。

### 3.3 AI 设置里的视觉检测

不新增卡片或测试区。现有 AI 配置卡下方已经有一组能力文本和「检测能力」按钮；把视觉能力并入同一条检测链路：

```
[工具调用协议 ▼]
图片识别：未检测 / 支持 / 不支持 / 未确认
连接正常
流式正常
原生 Tool Calls：支持
实际协议：...
[检测能力]
```

- 「检测能力」一次完成：普通补全 + 流式 + 原生 Tool Calls + 视觉探测。
- 视觉探测用内置测试图，不包含用户数据；结果和端点/模型一起缓存。
- 页面始终显示一行「图片识别：未检测/支持/不支持/未确认」，用户不用猜。
- 不做手动选择：自动检测比让用户勾“支持”更可靠；模型变化后回到「未检测」。
- 图片入口只读缓存：已缓存不支持 → 选图前提示；未检测/支持 → 正常选图并请求；请求失败写缓存。

---

## 4. UI/UX 变化

### 4.1 用户看到的变化

| 场景 | 现在 | 改后 |
| --- | --- | --- |
| AI 记账弹层 | 文字 + 「截图识账」+ 解析 | 文字 + 「图片识账」+ 解析；不新增图片模式/页面 |
| 图片入口 | 选图 → 本机 OCR → 文本 AI | 选图 → 视觉 AI；**不再需要点第二次解析** |
| 图片加载 | 模态「正在识别账单内容…」 | 同一模态与同一文案；不新增加载页 |
| 模型不支持视觉 | 不存在 | 已缓存不支持时选图前提示；未检测时直接请求，失败后提示并写缓存 |
| 视觉能力检测 | 无 | AI 设置页一行状态 + 现有「检测能力」按钮 |
| 分享图片 | OCR → 文本 AI | 同一视觉链路 |
| 隐私口径 | 图片不出设备 | 图片发送到用户配置的端点；政策更新 |
| arm64 APK | 44.9 MB | 约 31.6 MB |

### 4.2 弹层文案/按钮

- 「截图识账」→「图片识账」（或「从图片记账」），图标沿用图片/扫描图标。
- 删除弹层里的 `aiPrivacyNotice`；不新增任何上传确认或提示。
- 「解析」按钮保留给文字输入；图片按钮是独立动作，点击后弹层关闭并直接走识别流程。
- 不新增图片预览、缩略图、重试/移除图片的图片模式；失败仍用现有错误弹窗，用户可重新点图片按钮。
- 如果视觉缓存是「不支持」：点图片按钮时弹现有风格的信息框「当前模型不支持图片输入，请在 AI 设置中更换支持视觉的模型」，不打开相册。
- 如果缓存未检测：正常打开相册并请求；如果端点不支持图片，就用同一提示拦下并写缓存（想先确认可在 AI 设置检测）。

### 4.3 设置页视觉状态行

- 不新增卡片、不新增按钮、不做测试区域。
- 在现有「工具调用协议」下方加一行：
  - `图片识别：未检测`（没有缓存或配置已变）
  - `图片识别：支持`
  - `图片识别：不支持`
  - `图片识别：未确认`（检测时视觉探测没给出明确结果）
- 现有的「检测能力」按钮同时检测视觉；检测结果写入现有 AI 能力缓存。
- 模型或 Base URL 变化回到「未检测」；只改 API Key 不强制重检，也不要把本地视觉状态清成「未检测」，保存后与 controller 缓存对齐。
- 检测失败沿用现有错误文案；不把视觉失败单独做成卡片/弹窗。
- 与现有连接/SSE/Tool Calls 状态放在同一张卡、同一组文本里，符合当前设置页的信息架构。

### 4.4 文案 key

新增/修改：

| key | 中文 |
| --- | --- |
| `screenshotEntryButton` | 图片识账（原「截图识账」改文案） |
| `visionEntryUnsupported` | 当前模型不支持图片输入，请在 AI 设置中更换支持视觉的模型 |
| `visionEntryNoResult` | AI 未返回可识别的结果，请换一张更清晰的账单截图 |
| `visionEntryImageInvalid` | 无法读取这张图片，请换一张 |
| `visionEntryImageTooLarge` | 图片过大，请换一张或重新选择 |
| `aiVisionLabel` | 图片识别 |
| `aiVisionStatusUnknown` | 未检测 |
| `aiVisionStatusUnknownChecked` | 未确认 |
| `aiVisionStatusSupported` | 支持 |
| `aiVisionStatusUnsupported` | 不支持 |

删除：

- `screenshotEntryUnsupported`（设备不再需要端上 OCR）。
- `screenshotEntryNoText`（没有 OCR 文本了；图片无交易继续用现有 `captureEntryNoTransaction`）。
- `aiPrivacyNotice`（不再在入口提示）。

不新增「检测视觉能力」按钮、检测提示、检测失败卡片等文案；复用现有「检测能力」按钮和状态文本。

### 4.5 隐私提示

按当前决定：

- **不新增任何上传确认、弹窗或常驻提示。** 用户点图片按钮/分享图片本身就是明确操作。
- 删除弹层里的 `aiPrivacyNotice`。
- 隐私政策、产品文档按事实更新：图片会发送到用户配置的端点；图片识账本身不把图片写入账目或附件。
- 这是“事实披露”与“交互确认”的区分：不打断用户，但不允许法律文本继续声称“图片始终留在设备上”。

---

## 5. 技术设计

### 5.1 视觉消息与请求

新增 `AiVisionMessage`（`lib/app/ai/ai_agent_message.dart`）：

```dart
class AiVisionMessage extends AiAgentMessage {
  const AiVisionMessage({required this.text, required this.imageDataUrl})
    : super(AiMessageRole.user);

  final String text;
  final String imageDataUrl;

  @override
  Map<String, Object?> toJson() => <String, Object?>{
    'role': 'user',
    'content': <Object?>[
      <String, Object?>{'type': 'text', 'text': text},
      <String, Object?>{
        'type': 'image_url',
        'image_url': <String, Object?>{'url': imageDataUrl},
      },
    ],
  };
}
```

- 只允许 `user` 角色；不参与 Agent 的 `priorMessages` 循环，也不要把 `AiVisionMessage` 传给 `AiAgentEngine`（引擎按 JSON 字符数算请求预算，base64 会把预算撑爆）。
- 视觉入口走独立的 `aiAgentComplete` 单轮请求；`_requestBody` 已通过 `message.toJson()` 序列化，无需改构造。
- **不新增 `max_tokens`**：部分推理模型只接受 `max_completion_tokens`，现有 OpenAI 兼容端点也不一定接受该字段；输出长度由提示词约束。
- 新增请求体上限：编码后的 JSON 超过 8 MB 直接抛 `requestTooLarge`，不把大图发出去。
- 标准格式固定为 OpenAI Chat Completions 的 `content` 数组 + `image_url` data URL；不支持该格式的端点由请求错误/检测判定，不做第二套协议适配。

### 5.2 图片选择、压缩与安全

新增 `lib/app/ai/ai_vision_image.dart`：

- `Future<Uint8List?> pickVisionImage()`：
  - `ImagePicker().pickImage(source: ImageSource.gallery, maxWidth: 2400, maxHeight: 2400)`；
  - 读字节后 `finally` 删除 `image_picker` 缓存副本；
  - 取消返回 `null`。
- `Future<Uint8List> prepareVisionImage(Uint8List bytes)`：
  - 输入上限 25 MB；分享侧原生已限制，这里再兜底；
  - 在 `compute` 中解码/缩放/编码；
  - 只接受 JPEG / PNG / WebP / GIF 首帧；解码时用带 `maxPixels` 的解码器，限制 30 MP；
  - `bakeOrientation` 后重新编码，去掉 EXIF/GPS；
  - 最长边 1600，JPEG 质量 82；结果 >1.5 MB 时依次降到 75/68/60，仍超限缩到 1280/1024；
  - 仍超过 1.5 MB 抛 `VisionImageException.tooLarge`；
  - 失败映射为 `VisionImageException.invalid`。
- `String visionImageDataUrl(Uint8List jpegBytes)`：`data:image/jpeg;base64,...`，长度校验，不写日志。
- 不写附件目录、不写 SQLite、不创建临时文件；相册缓存副本读完即删。

**安全边界**：

- 分享 `content://` 的 25 MB 流式读取限制继续由原生 `MainActivity.readCaptureImageBytes` 负责。
- Dart 解码必须带像素上限，防止压缩炸弹。
- HEIC 等 `image` 包不支持的格式按“无法读取”提示。

### 5.3 视觉识账提示词与解析

新增 `lib/app/ai/ai_vision_entry.dart`：

- `String buildVisionEntryPrompt(AiEntryContext context)`：
  - 复用 `buildAiEntryPrompt` 的分类/账户/日期上下文；
  - 追加图片规则：
    - 输入是用户主动选择的账单截图、支付页面或小票照片，可能含余额、优惠、积分、广告、按钮等噪音；
    - 只提取最主要的一笔交易；金额只取交易金额本身，忽略余额/优惠/积分；
    - 付款/消费/扣款 → expense；到账/收款/退款/工资 → income；账户间转账/还款/提现 → transfer；
    - 日期/时间从图片中读取；识别不到就用当前时间；
    - 商户/对方/备注放 note，保留原语言；
    - 如果图中没有交易，`amount` 置 0；
    - 只输出 JSON，不要解释/Markdown。
- `Future<AiEntryDraft> requestVisionEntryDraft({settings, imageBytes, note, context})`：
  - `prepareVisionImage` → data URL；
  - `AiVisionMessage(text: note.isEmpty ? '请识别这张图片中的交易。' : note, imageDataUrl: ...)`；
  - 系统提示用 `buildVisionEntryPrompt`；
  - `aiAgentComplete(...)`；
  - 复用 `parseAiEntryDraft`；解析失败/无金额的语义与文本入口一致；
  - 不做“文本无数字”预过滤（图片入口没有 OCR 文本）。

错误映射：

- 新增 `AiErrorCode.visionUnsupported`，`aiErrorMessage` → `visionEntryUnsupported`。
- `requestVisionEntryDraft` 捕获 `serverError`/`badResponse`，如果错误详情包含 image/vision/multimodal 且包含 unsupported/not support/invalid 等词，转成 `visionUnsupported`。
- 其他 400/422 仍按通用服务器错误处理。

### 5.4 视觉能力检测（并入现有 AI 能力缓存）

不新增 `verifin.ai_vision.*` key、profile 或 notifier；扩展现有 `AiCapabilityProfile`：

```dart
enum AiVisionCapability { unknown, supported, unsupported }

class AiCapabilityProfile {
  final String endpoint;
  final String model;
  final AiNativeToolCapability nativeToolCalls;
  final AiVisionCapability vision;
  final DateTime checkedAt;
  final int protocolVersion;
  bool matches(AiSettings settings);
}
```

- `forSettings` 增加 `vision`（默认 `unknown`）；`toJson/fromJson/==/hashCode` 同步。
- 旧缓存没有 `vision` 字段 → 读成 `unknown`，不需要升 protocolVersion，也不丢原有工具能力。
- `detectAiCapabilities` 增加可选 `visionProbeImageBytes`：在普通补全、流式、Tool Calls 探测之后，再发一次带探测图的补全（tools 为空）。
  - 探测图由设置页从 `assets/ai_vision/vision_probe.png` 读入并传入；能力模块不依赖 `rootBundle`。
  - 200 且响应包含固定 4 位数字 → `supported`；
  - 200 但数字不匹配 → `unsupported`（能收图但读不出清晰数字，对账单更不可靠）；
  - 400/422 且错误详情指向图片输入不支持 → `unsupported`；
  - 其他 `AiException`（401/403、404、429、网络、超时、5xx）→ 按现有检测语义抛错；页面显示检测失败，不写新缓存；
  - 没有传入探测图 → `unknown`。
- 探测图约 2 KB、无用户数据；换图/改提示词时提升 `aiCapabilityProtocolVersion`，旧缓存整体失效（与现有工具能力缓存同一机制）。
- 结果写入现有 `verifin.ai_capabilities.v1`，仍然设备本地、不进备份。

**设置页**：

- 现有「检测能力」按钮同时检测视觉；不新增按钮/卡片。
- 在「工具调用协议」下方显示一行「图片识别：未检测/支持/不支持/未确认」。
- 模型或 Base URL 变化时现有能力缓存失效逻辑会把该行重置为「未检测」；只改 API Key 不影响。
- 明文 HTTP 沿用现有 `confirmCleartextIfRisky`；检测前先 `flush()` 自动保存。

**图片入口**：

- 读取 `controller.aiCapabilityProfile`：
  - `matches` 且 `vision == unsupported` → 选图前提示换模型；
  - `matches` 且 `vision == supported`/`unknown` → 正常选图并请求；
  - 没有缓存/不匹配 → 正常选图并请求（入口不做额外探测）。
- 请求返回 `visionUnsupported` → 用现有 `setAiCapabilityProfile` 写一个 `vision: unsupported` 的 profile（保留已有 nativeToolCalls），再提示换模型。
- 检测是设置页的用户动作；入口只承担一次图片请求。

### 5.5 Controller / 缓存

- 复用现有 `_aiCapabilityProfile`、`aiCapabilityListenable`、`setAiCapabilityProfile`；不新增字段、key 或 notifier。
- `AiCapabilityProfile` 的 `matches` 仍只看 endpoint + model + protocolVersion；视觉状态随同一个 profile 失效。
- `setAiSettings` / `saveAiSettingsDraft` 现有的失效逻辑已覆盖视觉，无需额外改动。
- 请求返回 `visionUnsupported` 时更新 profile（见 5.4），仍然只更新现有窄粒度 notifier。
- 缓存仍然设备本地、不进 JSON 备份；不新增 SQLite 表/列。

### 5.6 UI 与路由

修改：

- `lib/pages/ai_entry_sheet.dart`：
  - `startAiEntry` 保持现有 `ensureAiConfigured` + `showVeriModalSheet` 流程；
  - 弹层内删除 `aiPrivacyNotice`；
  - 「截图识账」按钮改文案「图片识账」，仍返回 `_imageRequested` 哨兵；
  - `startAiEntry` 收到哨兵后调用 `startImageEntry(context)`；不新增图片模式/预览/检测 UI。
- `lib/pages/capture_entry.dart`：
  - `startScreenshotEntry` 改为 `startImageEntry`：
    - `ensureAiConfigured`；
    - 检查缓存 `unsupported`，是则提示并返回；
    - `pickVisionImage()`（或使用 `sharedImageBytes`）；
    - 现有 `_runCaptureParse` 加载态中调用 `requestVisionEntryDraft`；
    - `_runCaptureParse` 增加 `VisionImageException` 分支（invalid/tooLarge → 本地化文案）；无交易仍用现有 `captureEntryNoTransaction`；图片的 `emptyResult` 用新 `visionEntryNoResult`，不复用文字版“换种说法”；
    - 未配置/不支持提示用 `showConfirmDialog`（去设置/取消）或 `showInfoDialog`，不新增内联两按钮 `AlertDialog`；现有 `ensureAiConfigured` 可顺手改用统一 helper；
    - 调用闭包里捕获 `AiException(visionUnsupported)`：先写 controller 的 unsupported 缓存，再 rethrow，由现有错误弹窗展示；
    - 成功 `_confirmDraft` 进 `EntryDetailPage`，继续传 `controller.defaultAccountId`；
    - 失败走现有错误弹窗；已缓存不支持时选图前就提示；
    - `finally` 清理相册缓存副本。
  - `startSharedCaptureEntry`：有图 → `startImageEntry(sharedImageBytes: bytes)`；无图 → `startCapturedTextEntry`；图片优先时消费并丢弃残留文本。
  - `startCapturedTextEntry`：保持现状，仍走 `requestCapturedEntryDraft`。
  - 删除 OCR import、`_CaptureNoTextException`、`screenshotRecognitionSupported` 判断。
- `lib/pages/shell.dart` / `transactions_pages.dart`：入口调用不变（`startAiEntry` 签名不变）；分享消费保持 `await` 与单飞。
- `lib/pages/ai_settings_page.dart`：读取探测图字节；在「工具调用协议」下加一行视觉状态；现有「检测能力」按钮把 `visionProbeImageBytes` 传给 `detectAiCapabilities`；不新增卡片/按钮。
- `lib/app/veri_fin_controller*.dart`：状态/缓存/notifier。
- `lib/app/ai/ai_agent_message.dart`、`ai_client_io.dart`、`ai_error.dart`。
- `lib/app/ai/ai_entry_parser.dart`：`buildCapturedEntryPrompt` 去掉 OCR 措辞；保留文本路径。

删除：

- `lib/app/screenshot_recognizer.dart`、`_io.dart`、`_stub.dart`。
- `_runCaptureParse` 里的 `_CaptureNoTextException` 分支。
- 弹层的 `aiPrivacyNotice` 行。

### 5.7 分享/Intent 流程

`startSharedCaptureEntry(context)`：

1. `consumeCaptureImage()`；有图 →
   - 消费并丢弃残留文本；
   - `startImageEntry(sharedImageBytes: bytes)`。
2. 无图 → `consumeCaptureText()`；有文本 → `startCapturedTextEntry(text)`。
3. 都没有 → 静默返回。

- 图片链路与 App 内选图完全一致：加载 → 视觉请求 → 草稿。
- 应用锁：Shell 在消费前 `waitUntilUnlocked`。
- 分享消费与快速记账单飞；图片优先时清除残留文本。
- 超过 25 MB 原生返回 null，当前不打开流程；与现状一致。

### 5.8 错误与日志

- 网络错误走现有 `AiException` → `aiErrorMessage`；新增 `visionUnsupported`。
- 图片解码/压缩失败用 `VisionImageException`，UI 映射为新文案。
- 日志：
  - 记录端点主机、模型、状态码/错误码、图片字节数与压缩后尺寸（可选）；
  - **禁止**记录 base64/data URL、图片字节、API Key、完整账目；
  - 上游错误 `detail` 进入日志前先截断并剔除 `data:image/...;base64,` 片段。
- 设置页检测前 `await _autoSave.flush()`，失败中止；检测结果写入 controller 前确认 `profile.matches(controller.aiSettings)`。
- 所有 `await` 后使用 `BuildContext` 前检查 `mounted`。

### 5.9 兼容性与数据

- 无数据库迁移；无备份格式变化。
- 旧交易的附件、退款、多币种、预算口径全部不变。
- 旧 AI 配置继续可读；视觉状态并入现有 `verifin.ai_capabilities.v1`，不是新 key。
- AI 配置仍只存设备 KV、不进备份；能力缓存同样不进备份。
- 用户升级后第一次使用图片入口：若能力缓存里视觉状态为 unknown，正常选图请求；失败会提示换模型。旧 OCR 入口不存在。
- 没有 AI 模型或模型不支持视觉时，图片入口不可用；文字 AI 记账、AI 对话、账目查询不受影响。
- 图片路径没有页面/预览状态，进程被杀不会产生半截交易。

---

## 6. 文件级改动清单

### 新增

| 文件 | 用途 |
| --- | --- |
| `lib/app/ai/ai_vision_image.dart` | 相册选图、压缩、解码上限、data URL |
| `lib/app/ai/ai_vision_entry.dart` | 视觉提示词、视觉请求、错误映射 |
| `assets/ai_vision/vision_probe.png` | 视觉检测内置测试图（4 位数字） |
| `test/ai_vision_image_test.dart` | 压缩、尺寸上限、EXIF/格式、data URL |
| `test/ai_vision_entry_test.dart` | 视觉请求正文、解析、错误映射 |

### 修改

| 文件 | 改动 |
| --- | --- |
| `lib/app/ai/ai_agent_message.dart` | 新增 `AiVisionMessage` |
| `lib/app/ai/ai_client_io.dart` | 新增请求体上限；图片消息序列化无需特殊分支 |
| `lib/app/ai/ai_error.dart` | 新增 `visionUnsupported` 映射 |
| `lib/app/ai/ai_entry_parser.dart` | 文本采集提示词去掉 OCR 措辞；保留文本路径 |
| `lib/app/ai/ai_capabilities.dart` | `AiCapabilityProfile` 增加 vision；`detectAiCapabilities` 增加探测图/视觉探测；旧缓存缺字段读 unknown |
| `lib/pages/ai_settings_page.dart` | 读取探测图字节；在工具协议下加一行视觉状态；现有检测按钮同时检测视觉 |
| `lib/pages/ai_entry_sheet.dart` | 删除隐私提示；图片按钮改文案；收到哨兵调用 `startImageEntry` |
| `lib/pages/capture_entry.dart` | OCR → `requestVisionEntryDraft`；保留现有加载/错误/跳转；分享图片走同一函数 |
| `lib/pages/shell.dart` | 分享入口保持现有 `await`/单飞；无需页面路由 |
| `lib/pages/transactions_pages.dart` | 确认 AI 入口仍调 `startAiEntry`（签名不变） |
| `lib/app/platform_bridge_capture.dart` | 仅更新注释（能力不变） |
| `pubspec.yaml` | 移除 ML Kit；新增探测图 asset |
| `pubspec.lock` | `flutter pub get` 自动更新 |
| `android/app/build.gradle.kts` | 删除 ML Kit 依赖与注释 |
| `android/app/proguard-rules.pro` | 删除 ML Kit 规则 |
| `android/app/src/main/kotlin/.../MainActivity.kt` | 注释更新 |
| `lib/l10n/app_zh.arb` / `app_en.arb` | 新增/删除/改写的 key；重新生成 `app_localizations*.dart` 并提交生成文件（不手改） |
| `README.md` / `AGENTS.md` / `docs/**` / `CHANGELOG.md` | 见第 8 节 |

### 删除

| 文件 | 原因 |
| --- | --- |
| `lib/app/screenshot_recognizer.dart` | OCR 条件导入门面 |
| `lib/app/screenshot_recognizer_io.dart` | ML Kit 中文识别 |
| `lib/app/screenshot_recognizer_stub.dart` | 测试 stub |
| `test/capture_entry_test.dart` 中的 OCR/截图 UI 用例 | 改为视觉/文本采集用例；文本纯函数测试保留并迁移 |
| `test/ai_entry_flow_test.dart` 中的旧截图入口断言 | 改为图片入口断言 |

---

## 7. 测试计划

### 单元/纯函数

- `AiVisionMessage.toJson`：content 数组、text/image_url、data URL 前缀。
- `visionImageDataUrl`：base64 可解码、长度上限、非法输入。
- `prepareVisionImage`：JPEG/PNG/WebP、长边缩到 1600、质量回退、>1.5 MB 拒绝、30 MP 上限、EXIF 方向/元数据去除。
- `AiCapabilityProfile`：新增 `vision` 后 encode/decode 往返；旧 JSON 缺字段读 unknown；不包含 API Key；endpoint/model 匹配逻辑不变。
- Controller 现有能力缓存生命周期：检测结果写 KV；重启后仍可读；模型/Base URL 变化清空；只改 API Key 保留；视觉状态随 profile 一起失效。
- `detectAiCapabilities` 的视觉探测：
  - 正确数字 → supported；
  - 数字不匹配 → unsupported；
  - 400 图片不支持 → unsupported；
  - 401/网络/超时/5xx → 抛错且不写新缓存；
  - 传入探测图字节时，complete transport 能收到 `AiVisionMessage`。
- `buildVisionEntryPrompt`：包含分类/账户/日期、图片规则、无 OCR 依赖。
- `requestVisionEntryDraft`：提示词、图片消息、错误映射；无金额/空结果异常。
- 文本采集路径不变：`sharedText` 仍使用 `buildCapturedEntryPrompt` / `requestCapturedEntryDraft`。
- `aiErrorMessage`：`visionUnsupported` 本地化。

### 传输层

- 本地 `HttpServer` 捕获请求体：
  - messages 最后一条 `content` 为 text + image_url；
  - data URL 可解码为 JPEG；
  - 不包含 `tools`；
  - 超过 8 MB 请求体被拒；
  - 400 图片错误映射为 `visionUnsupported`。
- 现有文本/SSE/Tool Calls 测试全部保持通过。

### Widget / 流程

- `AiEntrySheet`：
  - 文本输入 → 解析 → `EntryDetailPage`；错误内联，现有行为不变。
  - 点「图片识账」→ 弹层关闭；不出现第二次「解析」或图片模式/预览。
  - 未配置 AI → 现有配置引导对话框不变。
- `startImageEntry`：
  - 已缓存不支持 → 不打开相册，提示换模型。
  - 已缓存支持/未检测 → 选图 → 加载 → 请求 → 成功进 `EntryDetailPage`；失败弹现有错误。
  - 请求返回 `visionUnsupported` → 写入缓存并提示换模型。
  - 取消选图 → 无请求、无错误、无账目。
  - 分享图片字节与 App 内选图走同一请求/跳转。
- `AiSettingsPage`：
  - 视觉状态行初始「未检测」；现有「检测能力」按钮检测后显示支持/不支持/未确认；模型变化重置；缓存跨重启保留。
  - 检测前自动保存/flush；明文 HTTP 确认沿用。
- 现有文本 AI 记账、分享文本、CAPTURE_TEXT、AI 对话、备份/恢复、附件、应用锁测试全部通过。
- `test/l10n_keys_test.dart` 中英 key 一致且无未引用文案。
- 360dp / 393×852、浅/深色、大字号不溢出；文字/图片入口的现有布局不回归。

### 回归与删除验证

- `flutter analyze` 无问题；`flutter test` 全量通过。
- 全仓搜索 `google_mlkit`、`screenshot_recognizer`、`screenshotEntry`、`startScreenshotEntry`、`_CaptureNoTextException` 无残留；`captureEntryRecognizing` 保留给文字/图片加载文案。
- `pubspec.lock` 无 `google_mlkit_*`。
- release APK/AAB 中不再出现：
  - `lib/*/libmlkit_google_ocr_pipeline.so`；
  - `assets/mlkit-google-ocr-models/**`。

### 真机 / release

- 使用 CI 生成的 release APK（debug 不能替代）：
  - 配一个支持视觉的模型 → 设置页检测支持 → AI 弹层点「图片识账」→ 相册选账单截图 → 加载 → 直接进记账页 → 确认保存。
  - **确认选图后没有第二个「解析」按钮、没有图片预览页、没有额外跳转。**
  - 配一个纯文本模型 → 已缓存不支持时选图前提示；未检测时请求失败并写缓存，提示换模型；文字记账仍可用。
  - 系统分享图片：冷启动、已运行、连续分享；应用锁开启时先解锁；超过 25 MB 拒绝。
  - CAPTURE_TEXT：冷启动与运行中都能出草稿。
  - 断网/超时/401/429/服务端 400：本地化错误、可重试、不崩、不落账。
  - 大图/长截图/PNG/JPEG/HEIC：压缩或明确报错；不 OOM。
  - 取消选图/关闭加载：不留图片、不留草稿、不留日志敏感内容。
  - 浅/深色、360dp、大字号不溢出。
- 体积：
  - arm64 APK 目标 ≤ 33 MB（当前 44.9 MB；预计 31.6 MB）；
  - AAB 预计约 62 MB；
  - 记录实际值到汇报。

---

## 8. 文档与 CHANGELOG

| 文件 | 需要改什么 |
| --- | --- |
| `README.md` | 核心能力「识别截图」；技术栈「AI 与 OCR」→「AI」；去掉 ML Kit |
| `AGENTS.md` | 产品原则（图片主动发送、不做监听、OCR 删除）；AI 与 Android 规则；Never 规则；测试/验收中的 OCR 表述 |
| `docs/product/product.md` | 隐私原则、AI 记账/图片识账描述、Android 能力、当前边界（需要视觉模型、无端上 OCR） |
| `docs/product/acceptance-checklist.md` | 替换 OCR 验收为视觉验收；移除 R8/ML Kit 项；增加体积、闸门、分享、错误、隐私验收；确认选图后无第二次解析 |
| `docs/product/automation.md` | 分享图片改为视觉模型；“截图原图任何情况下都不会上传”“本地模型数据不出设备”等表述按新链路修正 |
| `docs/dev/auto-capture.md` | 路线 A 重写：无 OCR；图片压缩/视觉请求/检测/隐私/限制；更新“AI 硬门槛”和本地端点兼容说明 |
| `docs/dev/tech-decisions.md` | 删除 OCR 决策行，新增「图片识账改视觉模型」决策；AI 能力缓存说明补充视觉状态（不新增 key）；更新 Release 打包与 UI 组件选型 |
| `docs/dev/known-limitations.md` | 新增 L18：视觉能力限制（探测误判、端点兼容性、无离线、无相机、无多图、HEIC/超大图按错误处理）；同步 L12 的“截图入口”措辞 |
| `docs/dev/ai-provider-presets.md` | 更新「图片识账共用配置」；补充视觉能力检测与 OpenAI `image_url` 兼容边界 |
| `docs/dev/architecture.md` | AI/外部采集行改为图片识别；移除 OCR 两件套 |
| `docs/dev/android-development.md` | 「图形/OCR/插件」→「图形/图片/AI/插件」release 检查 |
| `lib/app/legal_content.dart` | 隐私政策第三节“相册”权限说明 + 第四节 AI 图片口径；更新 `legalUpdatedAt` |
| `CHANGELOG.md` | `## [Unreleased]` 记录：移除端上 OCR、视觉识账、检测、体积变化 |
| `docs/release-notes/vX.Y.Z.md` | 后续发版时写入用户可见说明与体积变化 |

**隐私政策第四节的新口径（中文）**：

> AI 记账、图片识账与 AI 账目问答均为可选功能，只有你自行配置 OpenAI 兼容端点后才会启用。启用后：你主动选择的图片、输入的文字，以及回答问题所需的只读账目摘要会发送到你所配置的端点；该端点如何处理数据由其运营方决定，请在使用前阅读其隐私政策。图片识账本身不会把图片写入账目或附件，图片仅用于本次识别；如你在记账页手动把图片添加为附件，则按附件存储规则保存；AI 记账只生成待确认草稿，必须经你确认后才落账；AI 查询工具全部只读。AI 密钥仅保存在本机，不进入备份。

同时更新 `legalUpdatedAt`。

---

## 9. 体积与收益

- 删除 ML Kit 原生库 11.06 MB + 模型 1.93 MB = **12.99 MB**（APK 压缩后）。
- arm64 APK：44.9 MB → **约 31.6 MB**（约 -29%）。
- AAB（三套 ABI）：97.7 MB → **约 62 MB**（估算，实际以 CI 产物为准）。
- 收益：少一个端上模型和 R8 维护面；识别准确性由用户选择的模型决定；仍保持“用户主动触发、只产草稿、图片不落库”。
- 代价：图片要离开设备，依赖网络和用户端点；没有 OCR 兜底；模型不支持视觉时图片入口不可用。

---

## 10. 风险与取舍

| 风险 | 影响 | 缓解 |
| --- | --- | --- |
| 用户的模型不支持 `image_url` | 图片识账失败 | 设置页检测；入口缓存不支持时提前提示；请求失败写缓存并提示换模型 |
| 探测图误判 | 少数模型被判定不支持 | 允许重新检测；不提供绕过（严格） |
| 未检测时直接请求 | 用户图片可能发到非视觉端点后才失败 | 设置页可先检测；失败写缓存并提示；入口不做额外探测（按最小改动取舍） |
| 图片发送到第三方 | 隐私口径变化 | 隐私政策/产品文档如实更新；图片不落库；不做后台/自动上传 |
| 网络/超时/大图 | 识别失败或慢 | 压缩、请求体上限、超时、现有错误提示 |
| 解析质量依赖模型 | 分类/账户可能错 | 仍进 `EntryDetailPage` 由用户确认；不静默落账 |
| 无 OCR 兜底 | 纯文本模型无法识图 | 文案说明需要视觉模型；文字 AI 记账保留 |
| HEIC/畸形图 | 解码失败 | 明确本地化错误；不 OOM |
| 旧用户困惑 | “截图识账”改名/需要视觉模型 | CHANGELOG/release notes 说明 |
| 超大分享图静默丢弃 | >25 MB 不打开流程 | 沿用现有原生上限；后续可改为 typed 提示 |

**接受的产品取舍**：

- 图片识账不再离线；用户必须在“本地优先”和“视觉模型准确性”之间选择后者。
- 不为图片入口增加预览、二次确认、重试面板或独立页面；失败就按现有错误提示重试。
- 不做相机、多图、自动附件；需要时另立 Issue。

---

## 11. 实施顺序

1. **基础设施**
   - `AiVisionMessage`、`aiAgentComplete` 请求体上限；
   - `ai_vision_image.dart`、`ai_vision_entry.dart`；
   - 扩展 `AiCapabilityProfile` / `detectAiCapabilities`；
   - 纯函数/传输/缓存测试。
2. **入口切换**
   - `startImageEntry`：选图 → 视觉请求 → 现有加载/错误/跳转；
   - `startSharedCaptureEntry` 图片走同一函数；
   - 弹层图片按钮改文案、删除隐私提示；
   - 设置页视觉状态行；
   - Widget/流程测试、ARB。
3. **清理与验证**
   - 删除 OCR 三件套、ML Kit 依赖/Gradle/proguard/注释；
   - 文档、隐私政策、CHANGELOG；
   - 全量 analyze/test、CI release APK、体积/真机验收。

不拆成“先删 OCR 再加视觉”的中间版本；最终状态必须一起可运行。

---

## 12. 验收标准

- [ ] AI 弹层点「图片识账」→ 相册选图 → 加载 → **直接进入 `EntryDetailPage`**；没有第二次「解析」、没有图片预览页、没有额外路由。
- [ ] 文字 AI 记账、分享文本、CAPTURE_TEXT 的现有行为不变。
- [ ] AI 设置页有一行「图片识别：未检测/支持/不支持/未确认」；现有「检测能力」按钮同时检测视觉；模型变更重置。
- [ ] 已缓存不支持时选图前提示换模型；未检测时请求失败会提示并写缓存；入口不做额外探测。
- [ ] 相册 + 系统分享图片 + CAPTURE_TEXT 三条入口均可用；图片不落库、不写临时文件、不进备份。
- [ ] 识别成功进入草稿；失败本地化提示、可重试、不崩、不落账。
- [ ] 没有 OCR/ML Kit 代码、依赖、Gradle 引入、proguard 规则和 APK 产物。
- [ ] arm64 release APK ≤ 33 MB；AAB 体积记录；无 `libmlkit_google_ocr_pipeline.so` / `mlkit-google-ocr-models`。
- [ ] `flutter analyze` / `flutter test` 全绿；PR CI 与 main debug APK 构建绿。
- [ ] release APK 真机通过第 7 节验收项。
- [ ] 隐私政策、README、AGENTS、产品/验收/技术文档、CHANGELOG 同步。
- [ ] 提交不含本机路径、账号、设备信息；无 AI 署名。

---

## 13. 已确认的决定

1. **UI**：保留现有 AI 记账弹层；图片按钮走现有“选图 → 加载 → 记账页”路径；不新增页面、预览或图片模式；选图后不需要再点解析。（已确认）
2. **提示**：不新增上传确认/提示，并删除弹层里的 `aiPrivacyNotice`；隐私政策按事实更新。（已确认）
3. **发布**：先实现功能，不排版本、不现在准备 release notes。（已确认）
4. **视觉检测**：不新增按钮/卡片；现有「检测能力」按钮同时检测视觉，设置页显示一行状态；图片入口只读现有能力缓存，未检测时直接请求，失败写缓存并提示。（技术实现）
5. **探测图**：内置 4 位数字测试图，无用户数据，精确匹配数字；技术选择，可替换。

---

## 14. 闭环自检

| 环节 | 结论 | 依据 |
| --- | --- | --- |
| 图片入口 | 闭环 | 弹层图片按钮 → 相册 → 加载 → 视觉请求 → `EntryDetailPage`；没有第二个解析/页面/预览 |
| 文字入口 | 闭环 | 弹层文字 + 解析按钮保持不变；分享文本仍走 `requestCapturedEntryDraft` |
| 分享/Intent | 闭环 | 图片走同一视觉函数；文本走原路径；图片优先并清理残留文本；锁/单飞不变 |
| 视觉闸门 | 闭环 | 现有「检测能力」按钮更新能力缓存；设置页一行状态；入口只读缓存；请求 `visionUnsupported` 写缓存并提示；严格无绕过 |
| 图片处理 | 闭环 | 相册缓存副本删除；分享字节只在内存；压缩 1600px/≤1.5 MB；30 MP/25 MB 上限 |
| 请求 | 闭环 | `AiVisionMessage` 标准 `image_url` data URL；单轮非流式；8 MB 请求体上限；不塞进 Agent 预算 |
| 解析与落账 | 闭环 | 复用 `parseAiEntryDraft`；只产 `EntryDetailPage` 草稿；默认账户沿用；用户确认才落账 |
| 失败路径 | 闭环 | 无 AI/不支持/网络/鉴权/限流/无交易/图片过大/格式错误都有本地化提示；不崩、不落账 |
| 数据与兼容 | 闭环 | 无 schema/备份变化；视觉状态并入现有 AI 能力缓存（设备本地、不进备份）；旧账目不变 |
| 删除 | 闭环 | OCR 三件套、ML Kit 依赖/Gradle/proguard/ARB/测试都有删除落点 |
| 体积 | 闭环 | 预期 arm64 44.9 → 31.6 MB；release 产物核对 |
| 文档/法务 | 闭环 | README、AGENTS、产品/验收/自动化/技术/架构/限制文档、隐私政策、CHANGELOG 均有条目 |
| 已确认决定 | 闭环 | 保留弹层、选图后直接进记账页、不加入口提示、视觉检测并入现有「检测能力」、先实现功能；见第 13 节 |

**自检结论**：这条链路已经是最小改动——**OCR 换成一次视觉请求，选图后直接进记账页**；没有新增页面、图片模式、预览、二次解析或额外探测。剩余风险是模型端点差异和识别质量，属于验收项，不是链路断点。
