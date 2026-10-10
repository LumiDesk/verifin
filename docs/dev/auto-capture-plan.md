# 截图识账与外部意图接口

Veri Fin 本体不监听任何通知或屏幕：不注册 `NotificationListenerService`、不注册 `AccessibilityService`、不申请短信权限。自动记账能力由两条**用户主动触发**的路线提供，全部只产草稿、绝不静默落账。

## 路线 A · 截图识别

- 入口：系统分享 `image/*`；App 内 AI 记账弹层的「截图识账」（相册选图）。
- 管线：本地 OCR（`google_mlkit_text_recognition`，中文模型，端上离线）→ 文本 → AI 解析（复用 AI 记账管线，`requestCapturedEntryDraft`，含无数字短路与文本截断）→ 草稿 → `EntryDetailPage` 确认。
- 分享进来的图片不落库不留存；用户勾选「保存为附件」才随交易存 `attachments` 表。
- 其他 App 分享的 `content://` 图片由原生层分块读取并累计大小，超过 25 MB 立即停止，不做全量 `readBytes()` 后再检查。
- 条件导入两件套 `screenshot_recognizer_io.dart`（ML Kit）+ stub（测试宿主 `recognitionSupported=false`）。

## 路线 B · 外部意图接口

- 显式导出的 Intent：Action `top.talyra42.verifin.action.CAPTURE_TEXT`，Extra `text`，目标 `ShareReceiverActivity`；Tasker、MacroDroid 等自动化工具用它送入账单原文，解析交给用户配置的 AI。用户文档见 [automation.md](../automation.md)。
- 安全边界：文本输入长度限制、简单频率限制；收到后只产草稿弹确认，绝不静默落账。

## 共同约定

- **AI 为硬门槛**：两条路线都依赖 `AiSettings`，未配置时入口引导去 AI 设置页；主推本地 Ollama/LM Studio（文本不出设备）。
- 图像默认走「本地 OCR → 文本 → 现有 AI 文本管线」，不直接把图片发给模型。
- **无新增数据表**：草稿当场确认或放弃，不落库；新增偏好仅为设备本地 KV，不进备份。
- **隐私红线**：App 本体零监听；截图原图不上传；只把识别文本发往用户自配端点。

## 明确不做

| 通道 | 原因 |
|------|------|
| NLS 通知监听 | 与「数据自主、本地优先」的产品立场冲突，且 App 被杀即停、依赖前台服务保活 |
| 无障碍读屏/截屏 | 同上，且是最重的权限 |
| 短信监听 | 同上（`RECEIVE_SMS` 敏感） |
| Xposed/Root/LSPatch/Shizuku | 用户群与 GitHub Releases 分发模式不符 |
| MediaProjection 常驻录屏 | 监听类，且 Android 14+ 授权更严 |

## 实现落点

- `lib/app/screenshot_recognizer_*.dart`：OCR 两件套；
- `lib/app/ai/ai_entry_parser.dart`：`buildCapturedEntryPrompt` / `requestCapturedEntryDraft`；
- `lib/pages/capture_entry.dart`：识别流程；
- 原生 `ShareReceiverActivity` + MainActivity 采集桥接；`consumeCaptureImage` / `consumeCaptureText` 拉取（仿快速记账 intent 模式，保持单实例）。

## 验收

- 微信/支付宝/银行 App/云闪付真实账单截图各若干张，金额与收支方向必须准（分类允许用户改）；分享入口冷启动、已运行、连续分享多张均可用；识别失败有兜底草稿。
- 自动化 Intent 冷启动（App 未运行）与运行中都能正确弹出确认页。
- 纯风景图（无文字）提示「没识别到文字」；聊天/网页图（有文字非交易）提示「未识别到交易」；无数字文本不白调 AI；AI 报错/超时弹本地化错误提示——全部不崩、不落账。
- OCR 依赖 ML Kit，release 的 R8 行为与 debug 不同，须用 CI release APK 真机验收。
