# 贡献指南

感谢使用 Veri Fin——一个免费、数据自主、本地优先的 Flutter 记账应用。

## 本仓库不接受 Pull Request

Veri Fin 不启用 GitHub Pull Request 功能，也不接受外部代码补丁或实现 PR。Issues 是唯一的外部贡献渠道。

- Bug：使用 [Bug 反馈](https://github.com/LumiDesk/verifin/issues/new?template=bug_report.md) 提供复现步骤、实际结果和运行环境。
- 功能建议：使用 [功能建议](https://github.com/LumiDesk/verifin/issues/new?template=feature_request.md) 说明使用场景、期望行为和备选方案。
- 可以 Fork 仓库用于个人研究和构建，但 Fork 不等于接受贡献，也不能用于提交 PR。

## Issue 的定位

- Issue 用于报告问题、描述需求和支持维护者确认范围，不代表已经批准实施。
- 请勿附完整实现或要求维护者评审代码分支；项目不接受外部代码补丁。
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

- 发版必须经明确同意；打 `vX.Y.Z` 标签会触发 CI 构建并发预发布，不可逆。
- 流程：先 `dart run scripts/doctor.dart` 确认环境；提升并提交 `CHANGELOG.md`；确认当前分支为 `main` 且工作树干净后，运行 `dart run scripts/publish.dart patch`。
- CI 默认创建**预发布**（不标 Latest）；真机验收通过后由维护者手动提升为正式版并标记 Latest。
- 未被提升的预发布用 `dart run scripts/prune_prereleases.dart` 清理；先加 `--dry-run` 核对，默认保留 git 标签。
