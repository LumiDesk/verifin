/// 构建期分发渠道开关。
///
/// 应用内自更新（检查 GitHub Release → 下载 APK → 拉起安装）仅用于 GitHub 自分发。
/// Google Play 版必须关闭：Play 负责更新，且政策禁止应用自行下载 APK 更新，同时对应
/// 的 `REQUEST_INSTALL_PACKAGES` 权限在 play flavor 清单里被移除。
///
/// CI 构建 Play 版（play flavor 的 AAB）时传 `--dart-define=SELF_UPDATE=false`；
/// GitHub 版（github flavor 的 APK）默认 `true`，保留自更新。
const bool kSelfUpdateEnabled = bool.fromEnvironment(
  'SELF_UPDATE',
  defaultValue: true,
);
