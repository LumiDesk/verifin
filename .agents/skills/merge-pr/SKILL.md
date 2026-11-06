---
name: merge-pr
description: Use when merging a pull request in this repository — feature branch, dependabot bump, or release PR — to decide from merge state whether it is safe, merge with a merge commit, delete the branch, sync main, and roll back with a revert PR if main breaks.
---

# 合并 PR

`main` 受保护：只能经 PR 合并，只允许 merge commit。规则见 `.agents/CONVENTIONS.md`。

## 1. 判定能不能合

```bash
gh pr view <n> --json number,title,mergeStateStatus,mergeable,statusCheckRollup
```

| 状态 | 含义 | 处置 |
|---|---|---|
| `CLEAN` + `MERGEABLE` | 必需检查全绿、无冲突 | 可以合 |
| `BLOCKED` | 必需检查没跑完或失败 | `gh pr checks <n> --watch`；失败看日志 |
| `DIRTY` / `CONFLICTING` | 与 `main` 冲突 | 见第 5 节 |
| `BEHIND` | 落后 `main`（未强制） | 需要时更新分支 |
| `UNKNOWN` | GitHub 还在算 | 等几秒再查 |

不要凭"看起来绿了"判断：`statusCheckRollup` 里可能有非必需检查，也可能有仍在跑的。

## 2. 合并前看一眼改动

```bash
gh pr diff <n> --stat
```

- 依赖 PR：只应改 `.github/workflows/*`、`pubspec.yaml`、`pubspec.lock`。
- 动了业务代码、Manifest 或签名配置的依赖 PR：停下问用户。
- 记录是否有**大版本跳跃**（如 `checkout 4 → 7`）：PR 上不构建安装包，合并后要盯 `main`。

## 3. 合并

```bash
gh pr checks <n> --watch
gh pr merge <n> --merge --delete-branch
```

`squash` 与 `rebase` 在仓库设置里已关闭，不要用 `--squash` / `--rebase`。

## 4. 合并后

```bash
git checkout main && git pull --ff-only && git fetch --prune
gh run list --limit 3
```

等 `main` 的 CI 出结论。它构建安装包；PR 上不构建，所以这是唯一能证明"包还能打出来"的环节。
失败则见第 6 节。

## 5. 冲突

```bash
git checkout <pr-branch>
git merge origin/main          # 解决冲突
git add -A && git commit
git push
```

合并回 `main` 仍然走 PR，不直接推。

## 6. 回滚

`main` 受保护，不能 reset，只能 revert：

```bash
git checkout -b revert/<topic>
git revert -m 1 <merge-sha>    # -m 1 保留 main 那一侧
git push -u origin revert/<topic>
gh pr create --fill --base main
gh pr merge <new-pr> --merge --delete-branch
```

## Never

- Never squash / rebase 合并。
- Never `git push --force` 到 `main`。
- Never 在必需检查未通过时合并。
- Never 因为"改动很小"就跳过合并后的 `main` CI。
