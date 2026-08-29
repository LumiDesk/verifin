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

## 品牌扩充与分组

选择器依次展示“通用、支付、信用、投资理财、卡组织、跨境与数字账户、银行”；银行数量最多，因此固定放在最后。组内由 `AccountIconOption.priority` 与银行常用项优先表排序，换组或调整顺序不得修改已发布 code。

| 分组 | 新增资源 | 来源/处理 |
|---|---|---|
| 支付 | 云闪付、美团 | 云闪付来自 Wikimedia Commons 候选并使用确认色 `#F8322B`；美团使用 `#FBC327` 底和黑字 |
| 投资理财 | 余额宝、国泰海通、Interactive Brokers | 余额宝按用户参考图重绘纯图形；国泰海通从完整标志保留左侧图形；IBKR 来自 Iconify selfhst |
| 卡组织 | Visa、American Express、JCB、Diners Club、Discover | Simple Icons；American Express 在 SVG 内增加圆角裁切 |
| 跨境与数字账户 | Wise、Revolut、Payoneer、Monzo、N26 | Simple Icons；Wise 按确认色 `#8DEA61` |

所有资源都把预览确认过的视觉缩放、位移与裁切固化在 SVG `viewBox` 中；正式渲染层不按品牌增加 padding、Transform 或兼容分支。

## 维护规则

- 新增或替换 SVG 时同步 `account_icon_assets.dart`，并保持已发布 code 稳定。
- 不在页面直接解析 SVG 路径或调用 `iconForCode` 渲染账户图标。
- 资源不得包含脚本、外链图片或网络引用；`test/account_icon_test.dart` 会检查目录与注册表一一对应及安全边界。
- 历史 `alipay`、`wechat`、`folder` 仅在 SQLite v16 迁移与导入/读取边界转换为当前 code；渲染层不保留历史分支。
