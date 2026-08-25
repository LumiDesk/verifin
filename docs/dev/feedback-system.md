# 轻提示组件与迁移规范

本文定义 Veri Fin 应用内轻提示的组件 API、交互语义、队列规则和迁移方法。
正式入口为 `lib/app/feedback.dart`。根级 Host 已安装，迁移批次 1 已替换“再次返回
退出”和全局持久化失败；简单、领域、数据管理和 UI Lab 清理批次均已完成，所有
Dart 实现已统一使用根级轻提示。迁移过程按本文分类完成，未做机械全局替换。

## 适用边界

轻提示用于不打断当前任务的短反馈：保存成功、复制完成、操作受限、短错误、后台
任务结果，以及带一个“撤销/重试”动作的可逆操作。

以下场景不使用轻提示：

- 破坏性操作前确认：使用 `showConfirmDialog`。
- 表单字段校验：在字段附近内联显示。
- 必须等待的任务：使用 `runWithLoadingDialog` 或领域进度界面。
- 需要解释原因、展示详情或要求明确选择：使用 Dialog、Sheet 或完整页面。
- 应用退到后台后仍必须触达用户：使用 Android 系统通知。
- 日志中的完整异常、账目原文或凭证：不得塞进提示，也不得泄露敏感内容。

该组件是应用内增强型反馈 Host，不是 Android 系统 Toast、通知或会话气泡。

## 根级结构

`VeriFinApp` 在 `MaterialApp.builder` 中安装一个 `VeriFeedbackHost`，位于
`AppLockGate` 内部、根 Navigator 之上。因此提示在以下行为中保持同一实例：

- 四个根 Tab 之间切换；
- `Navigator.push` 进入详情页；
- `Navigator.pop` 返回上一页。

Host 默认在系统底部安全区之上再避让 100dp，以绕开浮动根导航。应用进入后台时
暂停所有可计时提示，回前台后从原进度继续；常驻提示不创建进度条及其布局占位。

页面通过以下入口取得根控制器：

```dart
final feedback = VeriFeedbackHost.of(context);
```

应用根组件、持久化回调等无页面 `BuildContext` 的位置使用由 `VeriFinApp` 持有的
`VeriFeedbackController`，不得再创建第二个根 Host。

## 基础调用

无需等待结果的普通反馈必须显式使用 `unawaited`：

```dart
unawaited(
  VeriFeedbackHost.of(context).showMessage(
    message: l10n.webdavSaved,
    tone: VeriFeedbackTone.success,
  ),
);
```

需要操作结果时先在 `await` 前取得控制器；`deletedMessage` / `undoLabel` 必须由
调用页从 `AppLocalizations` 取得：

```dart
final feedback = VeriFeedbackHost.of(context);
final result = await feedback.showMessage(
  message: deletedMessage,
  tone: VeriFeedbackTone.warning,
  duration: VeriFeedbackDuration.long,
  actionLabel: undoLabel,
);

if (result == VeriFeedbackResult.action) {
  // 调用领域层提供的真实恢复入口。
}
```

若 `await` 后还要使用 `BuildContext`，仍必须检查 `context.mounted`。组件不会替业务
层记录错误，也不会替业务层恢复数据。

## API 语义

### Tone

| Tone | 用途 | 示例 |
|---|---|---|
| `info` | 中性说明、短状态 | 再按一次退出、正在上传 |
| `success` | 已完成且结果确定 | 已保存、已复制、导出完成 |
| `warning` | 操作受限、需要注意、可撤销删除 | 至少保留一项、已删除可撤销 |
| `error` | 操作失败或数据未保存 | 保存失败、文件格式错误 |

Tone 只决定图标与语义色，不替代日志严重级别。

### Duration

| Duration | 时长 | 使用建议 |
|---|---:|---|
| `short` | 2 秒 | 极短、低风险、无需阅读细节 |
| `standard` | 4 秒 | 默认值，大多数成功/说明反馈 |
| `long` | 8 秒 | 有操作按钮、警告或较长文案 |
| `persistent` | 常驻 | 明确等待用户处理或长任务状态 |

常驻态必须提供关闭入口；组件默认始终显示关闭按钮。带操作按钮的提示通常使用
`long`，只有用户必须处理时才使用 `persistent`。

### Priority

`low / normal / high` 只排序**等待队列**，不会抢占或突然移除已经显示的提示。
同优先级保持 FIFO。错误不应无条件设为高优先级；只有延后展示会误导用户时才用
`high`。

### Result

| Result | 含义 |
|---|---|
| `timedOut` | 展示时间结束 |
| `dismissed` | 用户点击关闭 |
| `action` | 用户点击唯一操作按钮 |
| `replaced` | 本次请求被同 `dedupeKey` 的既有提示合并 |
| `dropped` | 等待队列达到上限，本请求或最低优先级旧请求被丢弃 |
| `cleared` | Host/Controller 清空或销毁 |

调用方只在确实关心结果时 `await`。普通提示不得创建无人处理的裸 Future。

## 堆叠、队列与去重

- 最多同时显示 4 条，最新提示位于底部，旧提示向上堆叠。
- 等待队列默认最多 16 条。
- 队列满时，优先保留更高优先级的新请求；被淘汰请求返回 `dropped`。
- 每条提示拥有独立计时器和关闭动画；关闭一条不会重建或重置其他提示。
- Web 悬停会暂停该条计时，移开后继续；Android 无 Hover，不受影响。

去重必须由调用方显式传入稳定 `dedupeKey`，组件不会按文案自动猜测：

```dart
unawaited(
  feedback.showMessage(
    message: l10n.uploadingWebdav,
    duration: VeriFeedbackDuration.persistent,
    dedupeKey: 'webdav-upload',
  ),
);
```

相同 key 再次出现时会更新文案/tone/时长/操作，计数显示为 `×N`，并从头计算新
时长；重复调用本身返回 `replaced`。任务完成可用同一个 key 更新为成功提示并改用
`standard`，无需另行关闭旧状态。

`dedupeKey` 使用稳定的领域名，如 `save-entry`、`webdav-upload`、
`persist-error`；不要包含账目原文、文件路径、API Key 或动态时间戳。

## 单操作与撤销

每条提示最多一个操作按钮。组件只返回 `VeriFeedbackResult.action`，不直接调用
Controller、repository 或平台桥。

删除场景只有满足以下条件才能提供“撤销”：

1. 删除前取得足以恢复的领域快照，或领域层提供延迟提交/恢复命令；
2. 恢复操作保持 SQLite、内存状态和关联引用一致；
3. 恢复失败会记录 `AppLogger` 并给用户新的错误反馈；
4. 页面销毁后仍能完成恢复，不依赖已失效的 State 或 BuildContext。

不能真实恢复的数据不得只因为组件支持按钮就显示“撤销”。

## 场景映射

| 旧场景 | 推荐配置 |
|---|---|
| 复制、测试通知、配置已保存 | `success + standard` |
| 无可用账户、分类不可移动、至少保留一项 | `warning + standard` |
| 保存失败、导入/导出失败 | `error + long + high`，同类错误给 `dedupeKey` |
| 上传/恢复进行中 | `info + persistent + dedupeKey`，完成后同 key 更新 |
| 批量修改数量 | `success + standard` |
| 返回键二次退出 | `info + short + dedupeKey: root-exit` |
| 可逆删除 | `warning + long + actionLabel`，仅在领域层可恢复时使用 |

## 迁移顺序

历史调用已按以下批次完成迁移：

1. （已完成）根退出与全局持久化失败：验证根级 Host、短提示和错误去重。
2. （已完成）设置、应用锁、日志/卡号复制、截图能力、还款、提醒、小组件等简单反馈。
3. （已完成）账户、分类、汇率、账本、面板、周期记账、公共 Sheet、交易详情和批量操作等限制与结果反馈。
4. （已完成）数据管理中的备份、导入、导出、WebDAV 状态机；进行中提示使用常驻 + 同 key 原位更新。
5. 删除撤销保留为后续增强；启用前必须先补领域层恢复契约和回归测试。

每批迁移后均删除对应旧横条实现、更新本文状态，并运行该领域测试、
`flutter analyze` 和全量 `flutter test`。新代码不得重新引入旧式 Material
反馈横条。

## 测试要求

组件契约集中在 `test/feedback_test.dart`，至少锁定：

- 常驻态无进度占位且内容垂直居中；
- 操作结果；
- push/pop 与 Tab 切换保持；
- 四条可见栈、优先级队列和队列上限；
- `dedupeKey` 更新、计数和计时刷新；
- 前后台暂停/恢复；
- 关闭一条时其他提示不重建、不重置进度；
- 消息/计数/操作和首尾图标的布局对齐。

UI Lab 继续验证深浅主题、连续触发、手动关闭、常驻、操作、去重、优先级和跨路由
视觉。正式迁移后还需在 Android 真机检查系统安全区、手势导航和动画手感。
