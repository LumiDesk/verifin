# 体系约定

本文件描述 LumiDesk 的 Android 项目共用的约定：`flutter-android-template` 与由它生成的 App。
三处仓库保持同一份文本（模板仓库为源），改这里时三个仓库一起改。

项目自己的规则在 `AGENTS.md`；可执行流程在 `.agents/skills/`。冲突时：流程 > 本文件 > `AGENTS.md`。

## 分支与合并

- `main` 受保护：要求 PR + 必需状态检查，禁止强推与删除。
- 合并只用 **merge commit**（仓库已关闭 squash / rebase），保留可回退的合并点。
- 合并后删除分支（仓库已开启自动删除）。
- 合并前三件事：必需检查全绿、`mergeStateStatus=CLEAN`、`mergeable`。
- 合坏了：`git revert -m 1 <merge-sha>` 开 PR 回滚；不 force push、不 reset 远端。
- 完整步骤见 `.agents/skills/merge-pr/SKILL.md`。

## 依赖更新

- dependabot 每周开一个分组 PR（actions 一组、pub 一组，最多 1 个未合并）。
- 依赖 PR 只应改 `.github/workflows/*`、`pubspec.yaml`、`pubspec.lock`；动了别的就停下问。
- 大版本跳跃：PR 上的 CI 不构建安装包，**合并后必须确认 `main` 的 CI**。
- 升级让旧注释过期时，一并改掉（例：pubspec 里"显式锁某版本"的说明）。

## 文档分层

| 位置 | 放什么 | 谁读 |
|---|---|---|
| `AGENTS.md` | 项目级规则与红线 | AI 每次会话必读 |
| `docs/` | 当前事实：架构、设计、口径、验收 | 人和 AI |
| `.agents/notes/` | 决策的来龙去脉（proposed → implemented → rejected） | 想知道"为什么"时 |
| `.agents/skills/` | 可执行流程（发版、合并 PR） | 执行具体动作前 |

过程材料不进 `docs/`；`docs/` 里不保留"曾经打算这么做"的叙述。

## 授权边界

- 发版（打 tag、创建 Release、提升 Latest）必须用户明确授权。
- 合并 PR：依赖更新、文档、测试类可以直接合；涉及产品行为、数据格式、依赖大版本、模板骨架的，先问。
- 拿不准时按"需要授权"处理。

## 汇报

中文；先结论后细节；只报实际跑过的命令与结果，不写"应该没问题"。
