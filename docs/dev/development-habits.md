# 开发习惯

## 预览方式
日常开发优先使用 Web 预览。需要给用户稳定验收地址时，先执行 `flutter build web --pwa-strategy=none`，再在 `build/web` 下启动静态服务，例如：

```bash
flutter build web --pwa-strategy=none
cd build/web
python3 -m http.server 8080 --bind 0.0.0.0
```

这种方式比 debug web-server 更适合直接验收页面，也能减少 source map 噪声。若用户反馈白屏，先检查 `/`、`/flutter_bootstrap.js`、`/main.dart.js` 是否返回 `200`，再建议用户强制刷新或使用无痕窗口排除缓存影响。

做 UI 调整后，优先执行 `flutter build web --pwa-strategy=none` 并用静态服务截图检查移动端视口。当前常用视口为 `390x844`，重点检查首页、资产、看板、我的、交易列表和交易详情是否有白屏、重叠、底部导航异常或元素过大的问题。需要自动截图时，可以临时在 `/tmp` 使用 Playwright，不要把截图工具加入项目依赖，除非后续明确要建设视觉回归测试。

## 提交节奏
不要把所有改动混到最后一次提交。每完成一个相对独立的模块就提交一次，例如数据模型、页面结构、样式优化、文档同步分别提交。提交信息保持 `type: summary` 格式，不包含 AI 或 Codex 署名。

## CI 与发布
Android 安装包只通过 GitHub Actions 生成，不在本机作为交付依据。`.github/workflows/flutter.yml` 只监听 `v*.*.*` 标签；普通 `main` 推送不触发 Actions，避免每次提交都创建构建。

需要发布版本时使用脚本：

```bash
scripts/publish.sh patch
```

脚本支持 `patch`、`minor`、`major` 或显式版本号，例如 `scripts/publish.sh 1.1.0`。它会更新 `pubspec.yaml` 和 `appVersionLabel`、提交版本号、创建 `vX.Y.Z` 标签并推送。标签触发后，CI 会运行分析、测试、Web 构建、Android release APK 构建，并创建 GitHub Release。APK 文件名使用 `verifin-v1.0.0-短提交号.apk` 形式。发版前仍应确认 README、产品文档、UI 规范和验收清单已经同步。

Release APK 必须使用稳定签名。当前项目使用 `android/app/verifin-release.jks`，不要再使用 CI runner 临时 debug keystore，否则手机会因为签名变化而无法覆盖安装。

## 移动端持久化与权限
非 Web 平台不能使用内存版 `LocalKeyValueStore`。真实 Android/iOS 启动必须先调用 `LocalKeyValueStore.create()`，确保交易、账户、账本、设置等数据写入持久化存储。新增任何本地数据项时，都要确认导出/导入、初始化、进程重启后读取都覆盖到。

Web 专用能力必须有移动端实现或明确提示不可用。本地图片选择使用系统图片选择器，JSON 导入使用系统文件选择器，Android JSON 导出默认写入系统 Downloads，不要只实现 `dart:html` 版本。新增文件、图片、相册、安装包等能力时，要同步检查 Android Manifest 权限、MediaStore/分区存储和 Android 13+ 行为。移动端 data URL 图片预览应使用内存图片渲染，避免 `Image.network`/`NetworkImage` 在真机上黑屏。

测试导入数据放在 `docs/dev/verifin-sample-backup.json`。修改本地数据结构、导入导出字段、资产排序、预算或分类模型后，要同步更新该样例文件，并确保测试能真实导入它。

## 文档同步
每次修改功能、开发流程、数据结构或预览方式，都要同步检查 `README.md`、`AGENTS.md`、`docs/product.md` 和 `docs/dev/`。如果行为或流程变化已经影响用户测试或后续开发，需要在同一次变更里更新文档。
