<div align="center">

<img src="assets/brand/verifin_icon_1024.png" width="112" alt="Veri Fin" />

# Veri Fin

**完全免费 · 数据自主 · 本地优先的 Android 记账应用**

你的每一笔账都只保存在你自己的手机里——没有服务器、没有账号、没有广告、不收集任何数据。

[![Flutter](https://img.shields.io/badge/Flutter-3.x-02569B?logo=flutter&logoColor=white)](https://flutter.dev)
[![Dart](https://img.shields.io/badge/Dart-3.x-0175C2?logo=dart&logoColor=white)](https://dart.dev)
[![Platform](https://img.shields.io/badge/平台-Android-3DDC84?logo=android&logoColor=white)](#)
[![Release](https://img.shields.io/github/v/release/LumiDesk/verifin?label=版本&color=346edb)](https://github.com/LumiDesk/verifin/releases)
[![License](https://img.shields.io/badge/许可证-GPL--3.0--or--later-blue)](LICENSE)

[功能亮点](#-功能亮点) · [界面预览](#-界面预览) · [技术栈](#-技术栈) · [快速开始](#-快速开始) · [文档](#-文档)

</div>

---

## 📱 界面预览

<div align="center">

| 首页 | 资产 | 数据看板 |
| :---: | :---: | :---: |
| <img src="docs/screenshots/home.jpg" width="240" alt="首页" /> | <img src="docs/screenshots/assets.jpg" width="240" alt="资产" /> | <img src="docs/screenshots/reports.jpg" width="240" alt="数据看板" /> |

</div>

## ✨ 功能亮点

### 📒 记账

- 首页 FAB 数字键盘**快速记账**，支持支出 / 收入 / 转账三种类型；可选**「无账户」**只记金额、不计入任何账户余额；数字键盘支持**四则运算算式**（如 `500+800`），实时显示结果、算式不完整时提示；
- **默认付款账户**：在「我的 → 设置」或账户详情页把某账户设为默认，记账时（含 AI 未识别到账户时）自动预选它，每个账本各自设置；
- **AI 对话记账**（可选）：把「记一笔」按钮设为 AI 模式，用一句话（如「昨天打车 32」）自动解析出类型 / 金额 / 分类 / 账户 / 备注草稿，确认后落账；也可设为**点击手动、长按 AI**，一个按钮两种入口；自带 API Key + 请求地址（OpenAI 兼容），配置只存本机；
- **截图识账 / 分享识账**（可选，需先配置 AI）：把账单**截图「分享」给 Veri Fin**（或在 AI 记账弹层里选相册截图），文字识别在**本机离线完成、图片绝不上传**，识别文本由 AI 解析成草稿确认落账；账单**文本**同样可分享识别。Veri Fin 本体**不监听任何通知或屏幕**——Tasker 等自动化工具可经 Intent 接口把账单文本送进来（见 [`docs/automation.md`](docs/automation.md)）；
- **多级分类**（任意层级树形结构）+ **多标签**（多对多，可筛选、可统计）；
- 交易可附**图片票据**（拍照或相册，压缩后本地存储，随备份导出）；
- **周期记账**（每天 / 周 / 月 / 年自动补记，如房租、工资）、**批量操作**（多选删除、改分类、改账户）；
- **报销 / 退款冲抵**：记账时即可标记支出为待报销，回款按净额计入所有统计，交易列表可按报销状态（待报销 / 已报销）筛选与搜索；转账支持**手续费**。

### 💰 资产

- 账户按类型或自定义分组展示，净资产卡片带趋势图、可换背景；账户类型含**信用账户**（花呗 / 白条等有额度、账单日、还款但无实体卡号的信用类账户）；
- 账户详情：余额趋势（日 / 月）、余额调整（可选是否计入收支）、账户报告；
- **信用卡 / 信用账户**：账单日 / 还款日设置与还款倒计时提醒；设**信用额度**后展示已用 / 可用额度、使用进度条与本期账单；一键**还款**（金额预填欠款、扣款账户可选或「无账户」代还）；
- **完整卡号**（信用卡 / 储蓄卡，选填）：可录入完整卡号并在详情页一键复制，后四位可跟随卡号自动填充；列表仍只显示后四位；
- 银行 / 支付平台**品牌图标**自动匹配，支持隐藏账户与多账本隔离。

### 📊 报表

- **预算**：月度总预算、分类预算，以及**按日预算**（每日花销上限 + 今日进度）；
- 数据看板：预算执行、分类环形图、分类明细、标签统计、日趋势、月度收支，面板可开关排序；
- **统计分析**：本月 / 本年 / 自定义范围 × 支出 / 收入维度，趋势曲线 + 分类排行 + **同比 · 环比**；
- **AI 对话查询**（可选，需先配置 AI）：看板页「问 AI」进入聊天页，用自然语言问账目（「这个月花最多的是哪些分类」「最近三个月的大额支出」等），AI 调只读工具查你**当前账本**的真实数据，以柱状图 / 折线 / 可点击交易列表 + Markdown（含表格）流式作答；聊天记录只存本机、可清空，AI 全程**只读**不改数据；
- 全部图表**自绘且可交互**：点击 / 滑动查看数据气泡，环形图点选分段。

### 🔐 数据与安全

- 账目数据只存本地 **SQLite**，进程被杀数据不丢；
- 备份体系：手动 / 自动备份到本地目录（SAF）、**AES-GCM 加密**、**WebDAV 云备份**、zip 打包附件；
- **账单导入**：平台优先（先选来源再选文件）导入**支付宝**（CSV）、**微信**（xlsx）、**薄荷记账**（CSV）、**一木记账**（.xls，账单与转账还款两个入口；账单还原一级 → 二级分类层级、导入逗号分隔的多标签与备注）、**钱迹**（完整明细 CSV，覆盖支出/收入/转账/还款/退款/报销/债务全类型：退款自动冲抵原支出，债务把「对方」当账户记净欠款）、**Tally 记账**（备份 zip，无损保留精确时间与收支/转账、二级分类，并一并导入各账户当前余额与类型、含无流水的账户）账单，以及本应用 **CSV 模板**（第三方软件与 CSV 模板在选择器里分组展示；CSV 模板入口严格校验表头只允许模板列，各第三方软件各走独立入口、不再混用同一套表头识别）；自动跳过还款、理财等「不计收支/中性交易」，各平台附「如何导出账单」引导；导入预览页可对待新建的账户 / 分类 / 标签逐个改名或映射到现有条目；
- **应用锁**：6 位 PIN / 3×3 图案 + 生物解锁（密钥仅加盐哈希存本机，不保存任何生物特征数据）；启用后应用内容不可截屏、并从「最近任务」缩略图隐藏；
- **备份范围**：备份包含全部账目数据与个人资料、主题/视图/面板等展示偏好；**不包含**机密凭证（应用锁、备份口令、WebDAV 与 AI 密钥）和设备本地设置（语言、金额小数位、默认账户、FAB 行为、记账提醒、备份目录）——换机后这些需重设（完整清单见 [`docs/dev/tech-decisions.md`](docs/dev/tech-decisions.md)）；
- 无账号、无服务器、无第三方 SDK；隐私政策与用户协议应用内可查。

### 🌍 体验

- **中英双语**：跟随系统 / 简体中文 / English，即时切换；
- 浅色 / 深色 / 跟随系统主题，紧凑型移动端工具风格；
- Android **桌面小组件**（今日支出 + 记一笔）、下拉快捷开关「快速记账」、每日**记账提醒**通知；
- 新用户引导：建首个账户、设本月预算，几步上手。

> 完整功能断言清单见 [`docs/acceptance-checklist.md`](docs/acceptance-checklist.md)。

## 🛠 技术栈

| 领域 | 方案 |
| --- | --- |
| 框架 | Flutter 3 / Dart 3（仅 Android 交付） |
| 状态管理 | 单一 `ChangeNotifier` Controller + `InheritedNotifier` 注入，无第三方状态库 |
| 数据存储 | `sqflite`（账目类，含版本迁移）+ `SharedPreferences`（偏好类） |
| 国际化 | Flutter 官方 gen-l10n（ARB，中文模板 + 英文） |
| 备份加密 | `cryptography`（纯 Dart AES-GCM + PBKDF2-SHA256） |
| 云备份 | `dart:io HttpClient` 手写 WebDAV 客户端（PUT / GET / PROPFIND / MKCOL） |
| 图表 | 全部 `CustomPainter` 自绘（趋势 / 柱状 / 环形，带命中测试与数据气泡） |
| 平台能力 | `local_auth`（生物解锁）、`flutter_local_notifications`（提醒）、`image_picker`（附件）、原生 `AppWidgetProvider`（桌面小组件）、MethodChannel 桥（SAF / 磁贴 / 更新检查） |
| 测试 | 322 例 widget / 单元测试（内存仓储）+ ffi 真实 SQLite 数据层测试 |
| CI / 发布 | GitHub Actions：推 `vX.Y.Z` 标签 → analyze + test + release APK + GitHub Release |

## 🚀 快速开始

**普通用户**：直接到 [Releases](https://github.com/LumiDesk/verifin/releases) 下载最新 APK 安装（Android 手机）。

**开发者**：

```bash
git clone git@github.com:LumiDesk/verifin.git
cd verifin
flutter pub get                      # 安装依赖（自动生成 l10n）
flutter run -d <android-device-id>   # Android 模拟器或真机预览
flutter analyze && flutter test      # 静态检查 + 全部测试
```

Android 包名 `top.talyra42.verifin`。本地不构建交付 APK——正式安装包由 GitHub CI 生成。

## 📦 构建与发布

- CI（`.github/workflows/flutter.yml`）只在推送 `vX.Y.Z` 标签时触发：analyze → test → `flutter build apk --release --target-platform android-arm64` → 创建 GitHub Release（APK 命名 `verifin-vX.Y.Z-arm64-短提交号.apk`）。**只出 arm64-v8a 单架构包**（覆盖 2019 年后绝大多数机型、比 universal 约减半；极老 32 位设备装不了）；release 开启 R8 代码/资源裁剪，反射依赖点由 `android/app/proguard-rules.pro` 的 keep 规则保护。
- 发版一条命令：

  ```bash
  scripts/publish.sh patch   # macOS/Linux；也支持 minor / major / 显式版本号
  ```

  ```powershell
  ./scripts/publish.ps1 patch  # Windows/PowerShell 等价脚本
  ```

  脚本会更新版本号、提交、打标签并推送。
- Release APK 使用项目内稳定 keystore（`android/app/verifin-release.jks`）签名，版本间可覆盖安装。

## 📁 项目结构

```text
lib/
├── main.dart            # 应用入口与根组件
├── pages/               # 页面模块（首页 / 资产 / 看板 / 我的 / 交易 / 预算…）
├── app/                 # 模型、Controller、主题、图表、备份子系统、通用组件
├── l10n/                # ARB 文案（zh 模板 + en）与生成的 AppLocalizations
├── data/                # SQLite 数据层（建表迁移 + 仓储接口/实现）
└── local_storage/       # 偏好类 KV 存储适配（SharedPreferences / 测试 stub）
```

## 📚 文档

| 文档 | 内容 |
| --- | --- |
| [`docs/product.md`](docs/product.md) | 产品定位与数据策略 |
| [`docs/ui-guidelines.md`](docs/ui-guidelines.md) | UI 规范（Header、弹窗、金额展示、图表交互） |
| [`docs/acceptance-checklist.md`](docs/acceptance-checklist.md) | 功能验收清单 |
| [`docs/automation.md`](docs/automation.md) | 自动化接入（Intent 接口，配 Tasker 示例） |
| [`docs/dev/i18n-verification.md`](docs/dev/i18n-verification.md) | 多语言真机验证清单 |
| [`docs/dev/verifin-sample-backup.json`](docs/dev/verifin-sample-backup.json) | 可导入的测试备份数据 |
| [`CONTRIBUTING.md`](CONTRIBUTING.md) | 贡献指南（上手路线 + 提交前检查清单） |
| [`AGENTS.md`](AGENTS.md) | 贡献与 Agent 开发规范（含代码规范·组件化） |
| [`docs/dev/components.md`](docs/dev/components.md) | 组件清单（写新组件前先查） |
| [`docs/dev/tech-decisions.md`](docs/dev/tech-decisions.md) | 关键技术决策与选型理由 |
| [`docs/dev/known-limitations.md`](docs/dev/known-limitations.md) | 已知限制与技术债台账 |

## 📄 许可证

Veri Fin 是自由软件，基于 **GNU 通用公共许可证 v3.0 或更高版本（GPL-3.0-or-later）** 发布，完整条款见 [`LICENSE`](LICENSE)。

> Copyright (C) 2026 Talyra42
>
> This program is free software: you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation, either version 3 of the License, or (at your option) any later version.
>
> This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.

---

<div align="center">

如果这个项目对你有帮助，欢迎点一颗 ⭐

</div>
