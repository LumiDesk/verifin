# Android 高级材质崩溃调查

## 2026-09-05 历史证据

- 手机：REDMI K90 Pro Max（25102RKBEC / myron），SM8850，Android 17 / API 37。
- 当前正式安装：v1.16.1，versionCode 115；用户确认覆盖安装后可以启动。
- v1.16.0 发布构建 [33955430264](https://github.com/LumiDesk/verifin/actions/runs/33955430264)
  与 v1.16.1 发布构建 [33956814463](https://github.com/LumiDesk/verifin/actions/runs/33956814463)
  均成功。随后失败的普通 CI 涉及格式差异，最新
  [33957023009](https://github.com/LumiDesk/verifin/actions/runs/33957023009) 已通过。
- 发布 CI 使用 Flutter 3.47.2；电脑原有 Flutter 3.44.8。版本不同的结果必须分别记录。
- 设备 crash buffer 保留了 16:46–17:01 的多次正式应用崩溃：`1.raster` 线程
  `SIGSEGV / SEGV_MAPERR`，空指针地址 `0x14`；栈顶为 `vulkan.adreno.so`，
  下层为 `libflutter.so`。其中一次明确经过 `vkBeginCommandBuffer`。
  首次记录另有 `pthread_create ... failed` 的 `OutOfMemoryError`。
- 日志定位到了原生图形路径，但仅凭栈不能确定是驱动自身缺陷、引擎缺陷还是应用绘制
  放大了资源压力，也不能把伴随的线程创建失败直接认定为唯一根因。

完整设备日志只保存在本地 `build/graphics-investigation/`，不提交可能含设备信息的原始日志。

## 高光绘制资源检查

旧 `VeriGlassLightPainter` 沿轮廓每 2dp 提取小段，逐段执行 `MaskFilter.blur`。
360×180 卡片的记录画布测得 **513 次独立模糊绘制**。多卡片叠加且随交互重绘时，
资源工作量进一步放大。回归测试先在旧实现失败，再在修复实现通过。

候选修复沿原边界法线和光照公式构建连续透明度网格，以两次绘制表示柔光与细高光，
不再为每个微小段申请模糊。保留左上/右下方向、深色亮度、拖动光照和原有页面布局。
该修复随后通过了下面的同机、同引擎 release/R8 对照。

## 本地工具链

Java 21 在本机默认临时目录下建立 AF_UNIX 回环失败；使用独立临时目录后可以继续。
Kotlin 增量缓存因 C 盘 pub cache 与 D 盘项目产生跨根路径异常，本地诊断命令暂时关闭
Kotlin 增量编译。两项均只通过当前终端环境传入，不改 CI 或用户全局设置：

```powershell
$env:JAVA_TOOL_OPTIONS='-Djava.io.tmpdir=C:/Dev/java-tmp -Djdk.net.unixdomain.tmpdir=C:/Dev/java-tmp -Dorg.gradle.project.kotlin.incremental=false'
$env:FLUTTER_STORAGE_BASE_URL='https://storage.flutter-io.cn'
```

该镜像见 [Flutter 官方中国网络说明](https://docs.flutter.dev/community/china)。
本地诊断 flavor 的 applicationId 为 `top.talyra42.verifin.graphicsdiagnostic`，
与正式应用隔离。不得卸载或清除正式应用数据来验证材质。

## 同机 release/R8 对照结果

使用 Flutter 3.47.2，保持 Impeller Vulkan，不通过关闭 Impeller 绕过问题。

| 场景 | 结果 |
| --- | --- |
| 旧高光，先运行 Shader 加载和单次纹理折射 | B/C 正常；随后 A 高光崩溃 |
| 旧高光，强停重开后只运行 A，完全不加载 Shader | 再次崩溃 |
| 新高光 A，反复上下滚动 20 次 | 进程保持，未见 GPU 分配失败或 fatal |
| 新实现 B/C，反复采样/清空 10 轮 | 正常，未见上述错误 |
| 完整正式入口，诊断 applicationId | 开启、保存、强停冷启、四页、拖动、前后台、深浅色及关闭后冷启均正常 |
| `integration_test/glass_navigation_test.dart` 原机 release | `All tests passed!`，验证实际 Shader/纹理就绪、拖动切页、松手恢复实时文字 |

18:34:36 和 18:35:21 的两次旧高光复现均先记录 `kgsl_sharedmem_alloc() failed`
（32 KB 分配失败），随后 `1.raster` 在 `vulkan.adreno.so` 地址 `0x1296b4`
发生 `SIGSEGV / 0x14`；驱动 BuildId 与 `libflutter.so` BuildId 均与历史正式版
崩溃相同。第二次未加载 Shader，证明旧高光路径足以独立触发本次故障。
这是应用绘制负载与该驱动/引擎组合的复现证据，不能扩大为所有 Adreno 的统一根因。

新高光压力测试后的 `dumpsys meminfo` 快照：TOTAL PSS 136737 KB，Graphics 47308 KB。
这是单点资源记录，不是帧率、功耗或长期内存稳定性结论。
最终 Android 开关直接恢复，无临时 `ANDROID_GLASS_VALIDATION` 参数；其余未验收平台
继续受保护。测试覆盖历史 KV 开启时保留交易并恢复 Android 绘制，以及 Windows 降级。

最终源码静态检查通过；默认全量 925 项通过、13 项预览/平台测试跳过，发布外观专项
26 项通过。原机截图与过程日志留在本地调查目录；公开 `docs/screenshots/` 仍保留
已发布版本截图，未用空账本诊断图替换它们。
`github` flavor 本地 release/R8 APK 与正式入口 Web 构建也已通过；本轮未推送、打标签或发布。

## 复现与后续验收

CI 两个工作流固定 Flutter 3.47.2，并在普通 CI 增加发布材质参数下的专项测试。
锁文件随同版 SDK 的约束解析；升级 Flutter 时同步修改两个工作流并重做下列真机步骤。

```powershell
# 分别运行 A 高光 / B 加载 / C 纹理折射。
& C:/Dev/flutter-3.47.2/bin/flutter.bat build apk --release --flavor diagnostic --target-platform android-arm64 -t tool/advanced_material_diagnostic.dart

# 真正的应用入口、独立数据目录；不是复制的演示页面。
& C:/Dev/flutter-3.47.2/bin/flutter.bat build apk --release --flavor diagnostic --target-platform android-arm64 --dart-define=UNIFIED_DESIGN_PREVIEW=true --dart-define=GLASS_DESIGN_PREVIEW=true

# 原机 Shader 集成验收入口；断言必须实际就绪，不能以 fallback 通过。
& C:/Dev/flutter-3.47.2/bin/flutter.bat build apk --release --flavor diagnostic --target-platform android-arm64 -t integration_test/glass_navigation_test.dart --dart-define=UNIFIED_DESIGN_PREVIEW=true --dart-define=GLASS_DESIGN_PREVIEW=true
```

旧绘制基线可从 `03b31e4:lib/app/glass_lighting.dart` 取出，用诊断 target 的 import
替换为该文件后单独构建；不要把旧高光重新放回正式入口。原始本地对照 APK/日志均在
`build/graphics-investigation/`，不提交旧的不安全渲染副本。

诊断应用显示名称为“Veri Fin 图形诊断”，完整入口会在它自己的数据目录建立空账本。
本轮正式 `top.talyra42.verifin` 仍为 v1.16.1 / 115，未覆盖或清除其数据；
本地验收包不是正式交付包。后续需用户授权触发 CI 发布，以同签名、更高 versionCode
覆盖安装，补做真实账目下的滚动、冷启及升级验收，再提升预发布。

尚未完成：其他 GPU/系统、长时间帧率与功耗、Play 专属系统能力，以及新 CI 包覆盖安装。
不要将本机通过描述成这些项目也已通过。
