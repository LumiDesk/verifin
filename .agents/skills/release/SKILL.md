---
name: release
description: Use when the user asks to publish a new Veri Fin version (patch, minor, or major) — merges the feature branch into main with a real merge commit, deletes merged branches, prepares the CHANGELOG section, runs scripts/publish.dart, watches the tag build to green, fixes trivial failures without asking, and reports the pre-release with its assets.
---

# 发版

把「合并 → 清理 → 发版 → 等 CI → 验收 → 汇报」固化成一条可复现的路径。
这是**用户可见的对外动作**：没有明确授权时，只做到"准备完毕"就停。

## 前提

- 用户明确说了要发版，并给了 `patch` / `minor` / `major`。
- 工作区干净，`main` 与 `origin/main` 同步。

## 1. 合并到 main（非快进）

本仓库**不接受 Pull Request**（见 `CONTRIBUTING.md`），合并只走本地 `--no-ff`，
保证历史里留下一个可回退的合并点：

```bash
git checkout main
git merge --no-ff <branch>
git branch -d <branch>
git push origin main
```

确认 `git log --oneline -1` 是一条 merge commit，而不是被快进吞掉。

## 2. 清理已合并的分支

```bash
git branch --merged main | grep -v '^\*' | xargs -r git branch -d
git fetch --prune
```

## 3. 写 CHANGELOG（CI 从它生成 Release 正文）

`.github/workflows/flutter.yml` 会在 `CHANGELOG.md` 里按 `## [X.Y.Z]` 找段落；找不到就失败。

```markdown
## [X.Y.Z] - YYYY-MM-DD

### 新增

- 一条用户能感知的变化。
```

设计取舍与被否决的方案写进 `.agents/notes/`，不要塞进 `docs/`。

## 4. 跑发版脚本

```bash
dart run scripts/publish.dart patch        # 或 minor / major / X.Y.Z
```

脚本会：递增版本 → 写 `pubspec.yaml` 与 `lib/app/app_version.dart` → `dart format` →
`flutter analyze` → `flutter test` → 提交 `chore: release vX.Y.Z` → 打 tag → 推送 `main` 与 tag。

## 5. 盯着 CI 到绿

```bash
gh run list --limit 3
gh run watch <run-id> --exit-status
```

`.github/workflows/flutter.yml` 会跑设计契约测试、构建 github flavor 的 arm64 APK 与 AAB、
校验 ABI 与 versionCode，然后创建**预发布**（带"待验证"提示）。

### 失败怎么处置

| 情况 | 处置 |
|---|---|
| 格式、lint、测试期望过期 | 直接修，重跑，不用汇报 |
| 依赖下载 5xx、runner 抖动 | 重跑同一 job；连续两次同因失败才升级 |
| CHANGELOG 缺当前版本段 | 补段落后重新发下一个 `patch`（不要移动 tag） |
| versionCode 校验失败 | 停下，检查 `pubspec.yaml` 的 build number |
| 需要改产品行为、数据格式或签名 | **停下来汇报** |
| 同一个错误修了两次还在 | **停下来汇报**，给日志和已试过的方案 |

## 6. 验收预发布

```bash
gh release view vX.Y.Z --json isPrerelease,assets
```

确认预发布、APK 与 AAB 都在。真机上**覆盖安装**（不要卸载旧版本），按
`docs/product/acceptance-checklist.md` 过主链路。

## 7. 提升与清理

验收通过后：

```bash
gh release edit vX.Y.Z --prerelease=false --latest
```

未提升的旧预发布：

```bash
dart run scripts/prune_prereleases.dart
```

## 8. 汇报

1. 版本与 tag，分支合并方式。
2. Release 链接、资产名。
3. CI 结论；修过什么。
4. 验收清单执行情况。
5. 遗留风险 / 需要用户决定的事。

## Never

- Never 未经授权打 tag 或发 release。
- Never `git push --force` 到 `main`；Never 移动、删除、复用已推送的 tag。
- Never squash 或 rebase 合并到 `main`。
- Never 替换已上传的 APK/AAB；验收不通过就用下一个 `patch` 重发。
- Never 在 Release 说明里写内部重构、测试或文档整理。
