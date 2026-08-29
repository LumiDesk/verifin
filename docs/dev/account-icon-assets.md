# 账户图标资源

账户图标统一放在 `assets/account_icons/`，由 `AccountIconBox` 负责白底、10% 内边距和描边；SVG 自身负责图形与颜色。品牌图标保留品牌色，通用图标使用与含义相符的固定颜色，不跟随主题主色。

## 七个通用图标

| code | 文件 | 图形 | 主色 |
|---|---|---|---|
| `wallet` | `generic_wallet.svg` | Wallet | `#346EDB` |
| `credit` | `generic_credit.svg` | Credit Card | `#7B61D1` |
| `bank` | `generic_bank.svg` | Bank | `#2F6F8A` |
| `cash` | `generic_cash.svg` | Money | `#16A36F` |
| `investment` | `generic_investment.svg` | Chart Line Up | `#E9862D` |
| `savings` | `generic_savings.svg` | Piggy Bank | `#D95C8A` |
| `card` | `generic_card.svg` | Cards | `#2A8FB0` |

图形来自 [Phosphor Icons Core](https://github.com/phosphor-icons/core) 的 Duotone SVG，按其 MIT License 使用；本项目仅把 `currentColor` 固化为上表语义色，以保证 Flutter SVG 与不同主题下结果一致。

## 维护规则

- 新增或替换 SVG 时同步 `account_icon_assets.dart`，并保持已发布 code 稳定。
- 不在页面直接解析 SVG 路径或调用 `iconForCode` 渲染账户图标。
- 资源不得包含脚本、外链图片或网络引用；`test/account_icon_test.dart` 会检查目录与注册表一一对应及安全边界。
- 历史 `alipay`、`wechat`、`folder` 仅在 SQLite v16 迁移与导入/读取边界转换为当前 code；渲染层不保留历史分支。
