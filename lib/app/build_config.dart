/// 构建期分发渠道开关。
///
/// 应用内「检查更新」只用于 GitHub 自分发：检查到新版本后打开该版本的 GitHub
/// Release 页面，由用户在系统浏览器里下载或查看。Google Play 版必须关闭：Play
/// 负责应用更新，也不允许应用引导用户到站外下载。
///
/// CI 构建 Play 版（play flavor 的 AAB）时传 `--dart-define=UPDATE_CHECK=false`；
/// GitHub 版（github flavor 的 APK）默认 `true`，保留检查更新入口。
const bool kUpdateCheckEnabled = bool.fromEnvironment(
  'UPDATE_CHECK',
  defaultValue: true,
);
