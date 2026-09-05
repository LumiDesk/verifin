# 真实应用 Web 开发预览

状态：恢复根项目 Web 平台用于开发预览，Android 仍为 APK/AAB 交付渠道。
Web 与 Android 共用页面布局，不在页面插入开发预览或平台说明卡片；平台限制集中记录
在本文，仅在用户触发不支持的操作时反馈。
此次只恢复预览能力，没有实施全局视觉重构。设计评审使用真实页面，不再复制一套实验 UI。

## 运行与构建

```bash
flutter pub get
flutter run -d chrome --web-port 7357
# 使用 Codex 内置浏览器或其他浏览器时：
flutter run -d web-server --web-hostname 127.0.0.1 --web-port 7357
flutter build web --no-web-resources-cdn
```

始终使用同一个主机名和端口；`localhost`、`127.0.0.1`、不同端口属于不同 origin，
各自有独立存储。构建输出在 `build/web/`，可用普通静态 HTTP 服务预览。
不需要新服务器、账号或 Flutter flavor；Android 运行仍必须显式指定 flavor。
浏览器页面评审默认设为 393 × 852 逻辑像素（iPhone 15 尺寸），保证比较的是手机布局。
`--no-web-resources-cdn` 将 Flutter 渲染运行时放在本地构建中；首次中文字体回退仍可能
由 Flutter 请求公共字体资源，当前不承诺浏览器首次离线加载或 PWA 离线缓存。

## 存储与历史

早期提交 `65d14cd` 使用过 Web SQLite；`4bc7b61` 删除了 Web 平台。
本次复用该架构而非恢复旧业务代码：`database_factory_web.dart` 选择
`sqflite_common_ffi_web`，底层 SQLite WASM 文件系统写入 IndexedDB；上层继续使用
当前 schema、迁移、`SqliteLedgerRepository` 和 Controller。
没有 IndexedDB 对象模型的第二套实现，也没有整份 JSON/KV 账目回退。

偏好共用 `local_storage_preferences.dart` 的 SharedPreferences 适配，Web 后端使用
localStorage；图片共用 ImagePicker 与纯 Dart 压缩/裁剪实现。测试宿主仍可注入内存实现。
浏览器账目不会与 Android 同步，需要显式导出/导入；清理网站数据会同时清掉这些本地数据。

只使用一个标签页编辑。Worker 能串行执行数据库操作，但 Controller 的表快照与内存集合
没有跨标签刷新机制，不能把 Worker 的跨标签支持等同于应用多标签一致性。
开发预览无需更改 schemaVersion；已有历史 schema 仍按当前迁移矩阵升级。

## 平台能力

| 能力 | Web 预览 |
|---|---|
| 首页、资产、看板、我的、管理页、预算、手动记账 | 正式页面与 Controller；真实本地持久化 |
| 主题、语言、设置偏好 | 浏览器持久化；刷新可恢复 |
| 头像、资产图片、附件 | 浏览器文件选择，复用压缩/裁剪；拍照由浏览器/设备支持情况决定 |
| 备份/CSV 下载、账单导入、备份恢复 | 浏览器文件适配；下载成功提示只承诺请求已交给浏览器 |
| AI 请求、WebDAV | 当前不实现浏览器网络传输；不能用客户端绕过 CORS，更不引入转发服务器 |
| OCR、分享 Intent、SAF、自动目录备份 | Android 专属；Web 手动导出替代目录备份 |
| 系统提醒、生物解锁、防截屏、桌面小组件、APK 更新 | 不支持；自更新入口强制隐藏，其他页面注明不可用 |

应用锁 PIN/图案的 UI 与偏好可以预览，但浏览器没有 Android `FLAG_SECURE` 与系统级
生物认证保障。不要据此宣称拥有 Android 相同的安全能力。

## Web 资源维护

`web/sqlite3.wasm` 与 `web/sqflite_sw.js` 由当前锁定依赖生成并提交，CI 不在每次构建
临时下载另一版本。更新 `sqlite3` / `sqflite_common_ffi_web` 后运行：

```bash
dart run sqflite_common_ffi_web:setup --force
```

同时提交锁文件与两个配套资源，并验证冷启动和保存后刷新。不要混用历史 Worker。
官方说明：[sqflite_common_ffi_web](https://pub.dev/packages/sqflite_common_ffi_web)。

## 测试迁移与验证

原实验工程的候选图标、页面副本、设计对比图片、嵌套 package 与构建配置已退出仓库。
记账表单、分类/附件、图标等行为由 `test/entry_form_layout_test.dart`、`test/entries_test.dart`、
`test/account_icon_test.dart` 等正式组件测试承担。导航按压、边界点击、远端追踪和 Hover
断言迁入 `test/root_navigation_test.dart`；提示悬停暂停迁入 `test/feedback_test.dart`。
过时实验布局与候选比例切换不再作为验收契约；历史审查报告保留当时的测试事实。

每次执行根项目 format、analyze、test 和 Web build；存储改动另在真实浏览器验证
保存、刷新、重新打开页面和导入/导出。Android CI debug 编译门禁及 release APK 真机
验收继续保留，Web 无法替代通知、OCR/R8、SAF、生命周期和触控性能测试。

浏览器存储回归测试使用 Flutter SDK 的 `integration_test`，测试数据库/偏好键与正式
数据隔离。覆盖真实工厂选择、IndexedDB 关闭重开、事务回滚与后续写入、偏好读取/
删除以及 Web 自更新关闭。可以在浏览器打开以下测试入口，成功后显示 `Web storage PASS`：

```bash
flutter run -d web-server --web-hostname 127.0.0.1 --web-port 7358 --target integration_test/web_storage_test.dart
```

已有匹配版本 ChromeDriver 的机器也可使用官方驱动方式：

```bash
# 在另一终端运行 chromedriver --port=4444
flutter drive -d web-server --driver test_driver/integration_test.dart --target integration_test/web_storage_test.dart
```

不要使用旧的 `flutter test --platform chrome` 宿主：本轮在 Flutter 3.44.8 本地环境中
发现它与加载的 test Browser Host 不兼容（缺少 `#play` 节点并在加载阶段停滞）。
CI 保留普通测试、正式 Web 编译和 Android 编译门禁，浏览器端使用以上集成测试验收。

2026-09-05 本轮验证：根项目 analyze、910 项测试、正式 Web build 通过；
浏览器集成测试显示 `Web storage PASS`。真实应用完成账户/支出创建、刷新后账目与
余额读回、锚点菜单、图片附件选择和保存、浏览器下载请求验证。没有运行 Android
真机验收，也没有把浏览器下载请求提示当作已经取得最终磁盘文件的证明。
