# 图片识账与外部意图接口

Veri Fin 本体不监听任何通知或屏幕：不注册 `NotificationListenerService`、不注册 `AccessibilityService`、不申请短信权限。自动记账能力由两条**用户主动触发**的路线提供，全部只产草稿、绝不静默落账。

## 路线 A · 图片识账

- 入口：系统分享 `image/*`；App 内 AI 记账弹层的「图片识账」（相册选图）。
- 管线：相册/分享图片字节 → `prepareVisionImage`（最长边 1600、JPEG、≤1.5 MB、30 MP 上限）→ `AiVisionMessage`（OpenAI `image_url` data URL）→ `requestVisionEntryDraft`（视觉提示词直接输出交易 JSON）→ `EntryDetailPage` 确认。
- **没有端上 OCR**：图片直接交给用户配置的视觉模型；选图后不再需要第二次「解析」，成功后直接进入记账页。
- 视觉能力：AI 设置页在检测成功后显示独立的「能力检测结果」卡片，以左标签/右值展示连接、流式输出、原生 Tool Calls、实际协议和「图片识别：支持/不支持/未确认」；未配置或未检测时不显示图片识别行。检测仍由现有「检测能力」按钮触发（内置 4 位数字测试图，无用户数据），状态并入现有 `verifin.ai_capabilities.v1` 缓存，不新增 key。
- 图片入口只读缓存：已缓存「不支持」→ 选图前提示换模型；未检测/已支持 → 正常选图并请求；请求返回图片不支持时写入缓存并提示。
- 分享进来的图片不落库不留存；用户要在记账页手动添加附件才随交易存 `attachments` 表。
- App 内相册选图、拍照附件与头像读取完成后立即删除 `image_picker` 在应用缓存里的副本；用户相册原文件不变。
- 其他 App 分享的 `content://` 图片由原生层分块读取并累计大小，超过 25 MB 立即停止，不做全量 `readBytes()` 后再检查。
- 应用锁启用时，Shell 先等解锁再消费原生队列；锁屏期间不读取图片、不发请求。

## 路线 B · 外部意图接口

- 显式导出的 Intent：Action `top.talyra42.verifin.action.CAPTURE_TEXT`，Extra `text`，目标 `ShareReceiverActivity`；Tasker、MacroDroid 等自动化工具用它送入账单原文，解析交给用户配置的 AI。用户文档见 [automation.md](../product/automation.md)。
- 安全边界：文本输入长度限制、简单频率限制；收到后只产草稿弹确认，绝不静默落账。
- 应用锁启用时，分享/采集与小组件路由入口先等待锁屏解除，再消费原生队列中的内容；锁屏期间不发起图片识别、AI 请求或切换账本。

## 共同约定

- **AI 为硬门槛**：两条路线都依赖 `AiSettings`，未配置时入口引导去 AI 设置页。远程端点会收到用户主动选择的图片或文本；本地端点是否支持图片输入由模型和端点决定。
- **图片只走视觉模型**：不再保留「本地 OCR → 文本 → 文本 AI」的第二条路径；视觉能力检测与图片入口共用现有 AI 能力缓存。
- **无新增数据表**：草稿当场确认或放弃，不落库；视觉能力状态只在设备本地能力缓存，不进备份。
- **隐私红线**：App 本体零监听；用户主动选择的图片会发送到其配置的端点；应用本身不保存图片，除非用户手动添加为附件。

## 明确不做

| 通道 | 原因 |
|------|------|
| NLS 通知监听 | 与「数据自主、本地优先」的产品立场冲突，且 App 被杀即停、依赖前台服务保活 |
| 无障碍读屏/截屏 | 同上，且是最重的权限 |
| 短信监听 | 同上（`RECEIVE_SMS` 敏感） |
| Xposed/Root/LSPatch/Shizuku | 用户群与 GitHub Releases 分发模式不符 |
| MediaProjection 常驻录屏 | 监听类，且 Android 14+ 授权更严 |

## 实现落点

- `lib/app/ai/ai_vision_image.dart`：选图、压缩、data URL；
- `lib/app/ai/ai_vision_entry.dart`：视觉提示词与 `requestVisionEntryDraft`；
- `lib/app/ai/ai_capabilities.dart`：能力缓存中的视觉状态与探测；
- `lib/pages/capture_entry.dart`：图片/文本采集流程；
- `lib/pages/ai_entry_sheet.dart`：AI 记账弹层与图片入口；
- 原生 `ShareReceiverActivity` + MainActivity 采集桥接；`consumeCaptureImage` / `consumeCaptureText` 拉取（仿快速记账 intent 模式，保持单实例）。

## 验收

- 微信/支付宝/银行 App/云闪付真实账单截图各若干张，金额与收支方向必须准（分类允许用户改）；分享入口冷启动、已运行、连续分享多张均可用；识别失败有明确提示。
- 视觉模型不支持图片时，入口提示更换支持视觉的模型；设置页「检测能力」能更新「图片识别」状态。
- 自动化 Intent 冷启动（App 未运行）与运行中都能正确弹出确认页。
- 纯风景图或聊天/网页图提示「未识别到交易」；无数字文本不白调 AI；AI 报错/超时弹本地化错误提示——全部不崩、不落账。
- 图片会发送到用户配置的端点；应用内不持久化图片（手动添加附件除外）；release APK 需覆盖图片选择、分享入口和原生桥的真机行为。
