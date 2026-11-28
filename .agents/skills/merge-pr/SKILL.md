---
name: merge-pr
description: Use when merging a pull request in this repository — feature branch, dependabot bump, or release PR — to check its merge state, merge with a real merge commit, delete the branch, sync main, and roll back with a revert PR if main breaks. GitHub Actions does not run on PRs or on main; run the quality gates locally before merging.
---

# 合并 PR

`main` 受保护：只能经 PR 合并，只允许 merge commit。规则见 `.agents/CONVENTIONS.md`。
**仓库不在 PR / push 上跑 CI**（见 AGENTS.md「CI 与发版」）：测试在提交前本地跑完，
合并前不看远端检查，只有发版标签构建是 GitHub Actions。

## 1. 判定能不能合

```bash
gh pr view <n> --json number,title,mergeStateStatus,mergeable
```

| 状态 | 含义 | 处置 |
|---|---|---|
| `CLEAN` + `MERGEABLE` | 无冲突、可合并 | 可以合 |
| `BLOCKED` | 分支保护未满足（PR/评审） | 检查保护规则；不要等一个不会出现的检查 |
| `DIRTY` / `CONFLICTING` | 与 `main` 冲突 | 见第 4 节 |
| `BEHIND` | 落后 `main`（未强制） | 需要时更新分支 |
| `UNKNOWN` | GitHub 还在算 | 等几秒再查 |

## 2. 合并前看一眼改动

```bash
gh pr diff <n> --stat
```

- 依赖 PR：只应改 `.github/workflows/*`、`pubspec.yaml`、`pubspec.lock`。
- 动了业务代码、Manifest 或签名配置的依赖 PR：停下问用户。
- 记录是否有**大版本跳跃**（如 `checkout 4 → 7`）：合并前本地跑过 `flutter analyze` / `flutter test`，发版构建时验证安装包。

## 3. 合并

```bash
gh pr merge <n> --merge --delete-branch
```

`squash` 与 `rebase` 在仓库设置里已关闭，不要用 `--squash` / `--rebase`。

## 4. 冲突

```bash
git checkout <pr-branch>
git merge origin/main          # 解决冲突
git add -A && git commit
git push
```

合并回 `main` 仍然走 PR，不直接推。

## 5. 合并后

```bash
git checkout main && git pull --ff-only && git fetch --prune
git branch --merged main | grep -v '^\*' | xargs -r git branch -d
```

没有 `main` CI 需要等；改动要到下一次发版标签构建时才会在 GitHub 上打包。

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
- Never 把本地未跑格式 / analyze / 测试的改动合进 `main`。
- Never 为了等一个不存在的远端检查而阻塞合并。
