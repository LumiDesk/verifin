# 自动记账定案：截图识别 + 外部意图接口（不做任何监听）

> 状态：**路线 A 与路线 B 均已实现（2026-07-07）**，待真机验收。实现落点：`lib/app/screenshot_recognizer_*.dart`（OCR 两件套）、`lib/app/ai/ai_entry_parser.dart`（`buildCapturedEntryPrompt`/`requestCapturedEntryDraft`）、`lib/pages/capture_entry.dart`（识别流程）、原生 `ShareReceiverActivity` + MainActivity 采集桥接；意图接口用户文档在 `docs/automation.md`。与本方案的偏差：在 App 内入口上只做了相册选图（AI 记账弹层「截图识账」按钮），拍照与磁贴入口按 backlog 未做；无新增数据表（草稿当场确认，不落库）。
> 定案（2026-07-07，用户拍板）：**永久不做「监听类」自动记账**（通知监听 NLS、无障碍读屏/截屏都不做）——监听用户消息过于侵犯隐私，且可靠性天花板由系统/ROM 决定无法根治。保留两条不含任何监听的路线：**① 截图识别**（用户主动截图、主动分享进来才识别）；**② 钱迹式外部意图接口**（愿意折腾的用户用 Tasker 等自动化工具自建触发，敏感权限授给自动化工具而非本 App）。
> 本文档为内部技术评估，正文保留中文（不进 ARB）。

## 一、决策背景

### 第一轮监听方案的真机失败（已 revert）

第一轮（NLS 通知监听 + AI 解析 + 确认落账，约 2000 行）曾完整实现，真机验收后经 `0eb3ba5` revert 撤回（代码仍在 main 历史 `9f1ace8`…`2fb92ef`，本方案**不再捡回**）。失败原因：① App 从最近任务划掉后 NLS 就停，需前台服务保活才勉强可用；② 银行「到账」不在默认白名单漏识别；③ 识别偏慢；④ 通知监听权限敏感、易随各 App 文案失效、体验烦。

### 第二轮调研结论 + 最终取舍

业界主流确实是「无障碍 + 通知监听」（开源标杆 [AutoAccounting](https://github.com/AutoAccountingOrg/AutoAccounting)：Xposed/通知/短信/无障碍截屏 OCR 多通道 + 规则 + AI），但都不稳、都要重权限。行业标杆**钱迹官方拒做自动记账**（认为实时监控屏幕太激进、违背记账工具初衷），只暴露 [Tasker 意图接口](https://docs.qianjiapp.com/plugin/auto_tasker.html)让用户自建自动化——敏感权限授给 Tasker、通知格式变化由用户自己调规则，App 侧零隐私争议、零维护成本。

**Veri Fin 最终选择与钱迹同一立场**：App 本体绝不监听通知、绝不用无障碍读屏。理由按优先级：

1. **价值观**：本应用的立身之本是「数据自主、本地优先」，常驻读取用户的支付通知/屏幕与此相悖，用户自己也不接受；
2. **可靠性**：监听路线在国产 ROM 上的存活率问题无法根治（第一轮已验证）；
3. **维护成本**：追各 App 通知文案/页面版面是无底洞。

「懒得手动记」的痛点由不含监听的三件套覆盖：**截图识别（本方案）+ 已有的 AI 文字记账 + 账单文件导入**（漏单兜底）。

### 明确不做清单

| 通道 | 不做的原因 |
|------|-----------|
| NLS 通知监听 | 定案：监听类一律不做（隐私 + 保活不可根治 + 第一轮真机已否决） |
| 无障碍读屏/截屏 | 同上，且是最重的权限 |
| 短信监听 | 同上（`RECEIVE_SMS` 敏感） |
| Xposed/Root/LSPatch/Shizuku | 用户群与 GitHub Releases 分发模式不符 |
| MediaProjection 常驻录屏 | 监听类，且 Android 14+ 授权更严 |

## 二、总体架构

两条路线殊途同归，共用同一条解析管线（复用现有 AI 记账基建），**绝不自动落账**：

```
┌ 入口（都是用户/用户配置的工具主动触发，无任何被动监听）──┐
│ A. 截图识别：系统分享 ACTION_SEND(image/*) /            │
│    App 内选图·拍照                                      │
│ B. 外部意图接口：Tasker 等经显式 Intent 送入原始文本      │
└──────────────┬─────────────────────────────────────────┘
               ▼
   kind=image → 本地 OCR（ML Kit 中文模型，离线）→ 文本
               ▼
   本地预过滤（含金额数字/交易关键词才继续，省 Token）
               ▼
   AI 解析（复用 AI 记账管线：isTransaction 过滤非交易 +
   金额/收支方向/对方/日期抽取 + 分类账户校验到当前账本清单）
   失败兜底：产「待解析」草稿（OCR 原文进备注），数据不丢
               ▼
   AiEntryDraft → EntryDetailPage(initialDraft:) 确认/修改 → 落账
```

- **AI 为硬门槛**：两条路线都依赖 AI 解析（`AiSettings`），未配置时入口引导先去 AI 设置页；主推本地 Ollama/LM Studio（文本不出设备）。
- **图像默认「本地 OCR → 文本 → 现有 AI 文本管线」**，不直接发图：复用管线与提示词、文本 Token 便宜、纯本地部署（本地模型多无视觉能力）也能用。可选增强：设置里加「视觉模型直读图」开关（要求用户端点支持视觉，单独告知会发图）。
- 与监听方案不同，两条路线都是**即到即处理、前台完成**，无后台队列、无保活问题；意图接口在 App 未运行时由 Intent 正常拉起。

## 三、路线 A：截图识别（先做）

用户支付完成 → 截图 → 分享给 Veri Fin（或在 App 内选图）→ 识别 → 确认落账。

**入口（按优先级）：**

1. **系统分享**：Manifest 给 MainActivity 加 `ACTION_SEND`（`image/*`）intent-filter。微信/支付宝里截图后「分享 → Veri Fin」直达识别流程，全程三步不用切 App 找入口。需处理冷启动/已运行/多次分享的 intent 消费（仿现有 `consumeQuickEntryIntent` 模式）。
2. **App 内选图/拍照**：记一笔入口扩展「截图识账」，复用现有 `attachment_picker_*`（`image_picker`）。
3. **快速记账磁贴扩展**（backlog，可选）：磁贴加「识别最近截图」，Android 13+ 走 Photo Picker 免权限。

**技术要点：**

- OCR 用 `google_mlkit_text_recognition`（中文模型，端上离线）。本方案唯一新增依赖；包体积增加需在 CHANGELOG/README 注明。
- OCR 文本 → 复用 AI 记账提示词框架，扩「账单截图」变体（容忍 OCR 噪声文本的换行/乱序/页面杂项，输出草稿 JSON + isTransaction）。
- 识别中有明确加载态（第一轮真机反馈教训）；结果进 `EntryDetailPage(initialDraft:)`，AI 草稿模式关闭自动识别（现有行为）。
- **分享进来的图不落库不留存**，识别完即弃；用户勾选「保存为附件」才随交易存 `attachments` 表。
- 条件导入两件套：`screenshot_recognizer_io.dart`（ML Kit）+ stub（测试宿主 `recognitionSupported=false`），与 `attachment_picker_*` 同模式。

**验收**：微信/支付宝/银行 App/云闪付真实账单截图各若干张，金额与收支方向必须准（分类允许用户改）；分享入口冷启动/已运行/连续分享多张均可用；识别失败有兜底草稿。

## 四、路线 B：外部意图接口（后做，成本极低）

学钱迹：暴露一个显式导出的 Intent（如 `top.talyra42.verifin.action.CAPTURE_TEXT`，extra 带原始文本），Tasker/MacroDroid 等自动化工具把它们抓到的通知/短信/剪贴板文本丢进 Veri Fin 解析管线，产草稿弹确认。

- **比钱迹接口更宽松**：不要求调用方自己解析金额/分类，丢原文进来即可，解析交给 AI——把「怎么触发」外包给自动化生态，把「怎么解析」留在我们最擅长的一层。
- 敏感权限（通知监听等）由用户授给自动化工具，与 Veri Fin 无关；通知文案变化不影响接口。
- 安全边界：输入长度限制、简单频率限制；收到后**只产草稿弹确认，绝不静默落账**（外部 App 不可能绕过用户直接写账本）。
- 出用户文档（README 或 docs/）：接口格式 + 一个 Tasker 抓支付宝通知的示例配置。
- 可选增强（backlog）：接口支持结构化 extras（金额/分类名/备注直给，跳过 AI），供进阶用户省 Token。

## 五、数据与偏好

- **无新增数据表**：两条路线都是前台即时处理，草稿不落库（用户当场确认或放弃），第一轮方案里的 `pending_captures` 表不再需要。
- 新增偏好仅「视觉模型直读图」等开关，并入现有 AI 设置或独立小 KV；设备本地、不进备份、初始化保留（与 `verifin.ai.v1` 同策略；备份偏好范围用户已定，不得擅自扩大，如有新增须同步 README/docs 清单）。
- 数据兼容：对 1.5.0+ 老用户零迁移风险（无 schema 变更）。

## 六、隐私红线

- **App 本体零监听**：不注册 NotificationListenerService、不注册 AccessibilityService、不申请短信权限——这是产品承诺，写进 README 的隐私说明。
- **绝不自动落账**：一切入口只产草稿，用户确认才成账。
- **截图原图不上传**：本地 OCR 后只发文本到用户自配 AI 端点；「视觉模型直读图」开关单独明示会发图。主推本地模型时全程数据不出设备。
- 意图接口收到的文本同样只发往用户自配端点，且来源是用户自己配置的自动化工具。

## 七、工程注意事项

- 平台差异走仓库既有条件导入两件套（io + stub），测试宿主 `supported=false`。
- 文案 zh+en 双 ARB。
- 新增依赖仅 `google_mlkit_text_recognition`（路线 A）；路线 B 零新依赖。
- 每路线独立提交、独立可发版；用户可见改动记 CHANGELOG `[Unreleased]`；架构/隐私承诺同步 CLAUDE.md/AGENTS.md/README/docs。
- 测试：提示词构造、OCR 文本→草稿映射、预过滤、intent 参数校验均为纯函数/可注入，进 `test/`；OCR 本身依赖真机，走真机验收。

## 附：历史与参考

- 第一轮监听方案完整设计与实现：main 历史 `293de00`（评估文档）、`9f1ace8`…`2fb92ef`（实现），`0eb3ba5` revert。仅作历史参考，不再捡回。
- AutoAccounting：https://github.com/AutoAccountingOrg/AutoAccounting 、 https://ez-book.org/pages/24b7f5/
- 钱迹不做自动记账 / Tasker 接口：https://docs.qianjiapp.com/question_answer.html 、 https://docs.qianjiapp.com/plugin/auto_tasker.html 、 https://sspai.com/post/61292
- 截图 OCR 记账先例（神奇账本）：https://zhuanlan.zhihu.com/p/30382584
- ML Kit 端上文字识别（中文）：https://developers.google.com/ml-kit/vision/text-recognition/v2/android
