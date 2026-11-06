# 贡献指南

感谢使用 Veri Fin——一个免费、数据自主、本地优先的 Flutter 记账应用。

## Pull Request 仅限维护者

仓库允许 PR，但只接受维护者自己提交的 PR（GitHub 侧已限制为仅协作者创建）。外部贡献请走 Issue，不要直接开 PR——包含代码补丁的外部 PR 会被关闭。Issues 是唯一的外部贡献渠道。

- Bug：使用 [Bug 反馈](https://github.com/LumiDesk/verifin/issues/new?template=bug_report.md) 提供复现步骤、实际结果和运行环境。
- 功能建议：使用 [功能建议](https://github.com/LumiDesk/verifin/issues/new?template=feature_request.md) 说明使用场景、期望行为和备选方案。
- 可以 Fork 仓库用于个人研究和构建，但 Fork 不等于接受贡献，也不能用于提交 PR。

## Issue 的定位

- Issue 用于报告问题、描述需求和支持维护者确认范围，不代表已经批准实施。
- 请勿附完整实现或要求维护者评审代码分支。
- 新依赖、全局架构、设计系统、发布流程或数据口径变化，需要维护者明确确认后才可能实施。
- 维护者会根据问题价值、项目方向和验证成本决定是否实现、何时实现以及采用什么方案。

## 维护者开发

- 仓库内的开发、设计、测试和提交规范统一见 [`AGENTS.md`](AGENTS.md)。
- 架构与源码导航见 [`docs/dev/architecture.md`](docs/dev/architecture.md)；组件复用前先查 [`docs/design/components.md`](docs/design/components.md)。
- 维护者直接向 `main` 提交；`main` 的 CI 只由 push 触发。

### 已确认的 Code Review 取舍

以下两项是维护者明确接受的产品与供应链取舍，后续 Code Review 默认不再作为缺陷重复报告：

- **发布签名材料可入库**：维护者接受开源仓库包含正式 keystore 与构建口令，允许用户自行签名和构建；不要求按私钥泄露问题整改。
- **GitHub Actions 使用 GitHub 托管信任边界**：维护者接受发布工作流依赖 GitHub 与上游 Actions 的信任模型，不要求把工作流权限或第三方 Action 改造为独立供应链防护方案。

上述豁免只覆盖这两项明确取舍，不影响对 APK 完整性校验、用户数据安全、远端输入边界和运行时权限的审查。

## 发版（仅维护者）

可执行的分步流程（开 PR、合并、清理分支、写发布说明、等 CI、失败处置、汇报）见
[`.agents/skills/release/SKILL.md`](.agents/skills/release/SKILL.md)；本节写规则与红线。

- 发版必须经明确同意；打 `vX.Y.Z` 标签会触发 CI 构建并发预发布，不可逆。
- 发版前必须齐两份材料：`CHANGELOG.md` 的 `## [X.Y.Z]` 段（用户可见变化）、
  `docs/release-notes/vX.Y.Z.md`（**Release 正文的唯一来源**，模板见 `docs/release-notes/_template.md`）。
  缺发布说明时 `scripts/publish.dart` 在改版本号之前就退出，CI 也会在构建前再查一次。
- 流程：先 `dart run scripts/doctor.dart` 确认环境；确认当前分支为 `main` 且工作树干净后，
  运行 `dart run scripts/publish.dart patch`。
- CI 默认创建**预发布**（不标 Latest）；真机验收通过后由维护者手动提升为正式版并标记 Latest，
  同时把发布说明里仅适用于预发布的那行删掉。
- 未被提升的预发布用 `dart run scripts/prune_prereleases.dart` 清理；先加 `--dry-run` 核对，默认保留 git 标签。
