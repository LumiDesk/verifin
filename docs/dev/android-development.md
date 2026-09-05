# Android 本地开发与真机验收

2026-09-05 起只维护 Android 应用，移除 Web 工程、WASM/浏览器存储、下载适配和浏览器门禁。
电脑上的单元/widget/ffi 测试继续保留；WebDAV 是 Android 备份能力，不在移除范围内。
设计评审直接使用正式 `lib/main.dart`，不复制页面。公共规范由 `AGENTS.md` 和 docs 维护，
`CLAUDE.md` 只链接 AGENTS。

## 环境检测与自动补齐

每次 Android 任务先检查工作树、`flutter --version`、`flutter doctor -v`、
`adb devices -l`、Java 和 `android/local.properties`。Flutter 版本以两个 CI 工作流
的 `flutter-version` 为准，当前 **3.47.2**。不要静默升级到其他 stable 版本。

**工具缺失时 Agent 必须先自动尝试安装/补齐并重新检测，不能只以“没有 Android 环境”结束。**
用户已授权正常开发所需工具的安装。优先复用现有安装，不覆盖其他项目的 SDK、不改签名，
不把管理员机器的固定路径写进已提交配置。只在下载/权限/设备授权确实阻塞时说明具体原因。

Windows 安装顺序：

1. 用 `Get-Command flutter,java,adb,git,gh`、`JAVA_HOME`、`ANDROID_HOME` 和
   `android/local.properties` 找现有工具；本机验证路径列在下面。
2. 缺 Git/JDK 时优先使用系统包管理器，例如 winget 的 `Git.Git`、
   `EclipseAdoptium.Temurin.17.JDK`。CI 使用 Java 17，本机已有 Java 21 也已验证可构建。
   重新定位可执行文件，不假定新安装立即刷新了当前进程 PATH。
3. 缺匹配 Flutter 时，从 [官方归档](https://docs.flutter.dev/install/archive) 的
   `releases_windows.json` 找 CI 指定版本，下载对应 archive 并核对其 SHA-256，
   解压到独立版本目录。Git clone 对应标签也是官方支持的源码安装方式。
   慢网可用 [官方文档列出的 CFUG 镜像](https://docs.flutter.dev/community/china)，
   在当前终端设置 `FLUTTER_STORAGE_BASE_URL=https://storage.flutter-io.cn`。
4. 缺 Android SDK 时，从 [Android 官方工具页](https://developer.android.com/tools)
   下载 Windows Command-line Tools，核对官方校验值，将工具放入
   `<sdk>/cmdline-tools/latest/`；不得从不明镜像下载执行文件。
   用 [sdkmanager](https://developer.android.com/tools/sdkmanager) 安装 platform-tools、
   与 Flutter/Gradle 配置相匹配的 platforms/build-tools/NDK/CMake；版本从本地 Flutter
   Gradle 插件及构建报错读取，不能把手机 API 版本直接当作 compileSdk。
   完成 SDK 许可流程，再用 `flutter doctor --android-licenses` 检查。
5. 为当前终端设置 PATH/JAVA_HOME/ANDROID_HOME，运行 `flutter pub get`、
   `flutter doctor -v` 和 `adb devices -l` 复核。macOS/Linux 同样使用官方 Flutter
   归档、JDK 与对应平台 Command-line Tools，不执行 Windows 安装命令。

本机已验证的工具（供发现已有安装，不能作为其他环境的硬依赖）：

```powershell
$env:PATH='C:\Dev\flutter-3.47.2\bin;C:\Dev\android-sdk\platform-tools;'+$env:PATH
$env:ANDROID_HOME='C:\Dev\android-sdk'
# 本机 Java AF_UNIX 临时目录和跨盘 Kotlin 缓存问题的局部绕过：
New-Item -ItemType Directory -Force C:/Dev/java-tmp | Out-Null
$env:JAVA_TOOL_OPTIONS='-Djava.io.tmpdir=C:/Dev/java-tmp -Djdk.net.unixdomain.tmpdir=C:/Dev/java-tmp -Dorg.gradle.project.kotlin.incremental=false'
flutter doctor -v
adb devices -l
```

仅在复现同类错误时使用上述 Java/Kotlin 绕过，不复制到 CI 全局配置。`local.properties`
由 Flutter 维护且不提交；正式 keystore 永远不替换或输出。

## 日常真机开发

手机开启 USB 调试并授权电脑；某些 ROM 还需允许 USB 安装。`unauthorized`、锁屏或
`INSTALL_FAILED_USER_RESTRICTED` 时请用户解锁/允许，不能绕过设备安全机制。
出现多个设备时必须显式选择 `-s <serial>` / `-d <device-id>`，不得盲装。

```powershell
flutter run -d <device-id> --flavor diagnostic --dart-define=UNIFIED_DESIGN_PREVIEW=true --dart-define=GLASS_DESIGN_PREVIEW=true
```

默认调试使用独立 applicationId `top.talyra42.verifin.graphicsdiagnostic`，显示名称
“Veri Fin 图形诊断”；仍是正式页面、Controller、SQLite 和原生插件，数据与用户正式应用隔离。
debug 支持 hot reload；最终图形/OCR/插件行为必须另外用 release/R8 检查。
用户明确要求在正式应用目录调试时使用 `--flavor github`，先核对签名/版本号；不得为
解决签名不一致卸载正式应用。GitHub/Play 的发布差异仍以 AGENTS 为准。

采集日志先保存历史 crash buffer，再启动目标应用；记录 package、pid、版本、引擎和时间。
按目标 pid 保存本次 logcat，避免把其他应用日志混入结论。日志和截图放在被忽略的
`build/`，不提交账目、凭证或原始敏感内容。图形问题分离绘制路径复现，见
[玻璃调查](android-glass-investigation.md)。

需要持续亮屏时，先记录 `adb shell settings get global stay_on_while_plugged_in`，
可临时 `adb shell svc power stayon usb`；任务结束恢复原值，不改变用户永久息屏习惯。

## 验收与交付

- 使用两个设计参数与发布包一致；widget 测试保留 393×852 和 360dp 布局检查，
  真机按其实际逻辑尺寸截图，不能把桌面测试当作原生验收。
- 高级材质开/关都验证：设置保存/取消、强停冷启、四页/导航拖动、深浅色、前后台。
  release/R8 下实际 Shader/纹理必须就绪；命令见玻璃调查中的集成测试入口。
- 提交前 format、analyze、全量测试及发布外观专项；数据库相关改动跑 ffi 持久化/迁移矩阵。
- 正式 APK/AAB 只由授权后的 CI 发布生成。本地 APK 是诊断证据，不作为正式交付。
- CI 成功后下载同签名、更高 versionCode APK 覆盖安装，保留账目；用户验收后才提升 Latest。
- 清理测试应用前先列出并核对 package。只卸载确认为本任务测试用途的
  `top.talyra42.verifin.graphicsdiagnostic`；**不得卸载 `top.talyra42.verifin` 或清数据**。
  如果测试应用里已有用户新录入的数据，先明确处理方式再删除。
