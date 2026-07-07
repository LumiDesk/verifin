# 自动化接入（Intent 接口）

Veri Fin 本体**不监听任何通知或屏幕**。如果你希望「支付宝一弹通知就自动记账」这类体验，可以用 Tasker、MacroDroid 等自动化工具抓取通知，再通过下面的 Intent 接口把账单原文送给 Veri Fin——由你自配的 AI 服务解析成交易草稿，**弹出记账页由你确认后才落账，绝不静默写入账本**。

这样监听通知的敏感权限授予的是自动化工具，而不是 Veri Fin；通知文案怎么抓、什么时候触发，完全由你自己掌控。

## 前置条件

- 已在「我的 → 设置 → AI 记账设置」配置好 AI（本地 Ollama / LM Studio 或任意 OpenAI 兼容云端服务）。
- 送入的文本无需你预先解析——金额、方向、分类、时间都由 AI 从原文里提取。

## 接口定义

发送一个**显式 Activity Intent**：

| 项 | 值 |
| --- | --- |
| Action | `top.talyra42.verifin.action.CAPTURE_TEXT` |
| Package | `top.talyra42.verifin` |
| Class | `top.talyra42.verifin.ShareReceiverActivity` |
| Extra | `text`（String）：账单原文，超过 8000 字符会被截断 |
| Category | `android.intent.category.DEFAULT` |

收到后 Veri Fin 会被拉起并直接进入「识别 → 草稿 → 确认」流程。文本里没有识别到交易时会明确提示，不会产生任何账目。

等价的 adb 验证命令：

```bash
adb shell am start -n top.talyra42.verifin/.ShareReceiverActivity \
  -a top.talyra42.verifin.action.CAPTURE_TEXT \
  --es text "招商银行：您账户0966于07月07日12:30消费人民币35.00元"
```

## Tasker 配置示例（抓支付宝通知）

1. **Profile → Event → UI → Notification**，Owner Application 选「支付宝」。
2. **Task → System → Send Intent**，填：
   - Action：`top.talyra42.verifin.action.CAPTURE_TEXT`
   - Extra：`text:%evtprm2 %evtprm3`（通知标题 + 内容）
   - Package：`top.talyra42.verifin`
   - Class：`top.talyra42.verifin.ShareReceiverActivity`
   - Target：`Activity`
3. 支付通知到达 → Veri Fin 弹出预填好的记账页 → 确认落账。

MacroDroid 类似：触发器选「通知」，动作选「发送 Intent」，按上表填写。

## 与分享入口的关系

不用自动化工具时，同样的解析管线也接在系统分享上：

- 在任意 App 里把**账单截图**分享给 Veri Fin → 本机离线 OCR（图片不上传）→ AI 解析 → 确认落账；
- 把**账单文本**分享给 Veri Fin → AI 解析 → 确认落账。

## 隐私说明

- 送入的文本（截图则为本机 OCR 出的文字）会发送到**你自己配置的 AI 端点**解析；使用本地模型（Ollama / LM Studio）时数据不出设备。
- 截图原图任何情况下都不会上传，识别完即弃、不留存。
- 该接口只产草稿并弹确认页，外部应用不可能绕过你直接写入账本。
