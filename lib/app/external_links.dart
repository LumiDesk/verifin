import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';

/// 应用内「打开外部链接」的唯一出口。
///
/// 全项目只从这里打开链接，且地址只能是本文件里的常量：不接受用户输入、账目文本或
/// AI 回答拼出来的 URL，避免形成任意跳转入口。
///
/// 一律交给**系统默认浏览器**（`LaunchMode.platformDefault`）：赞助、发布说明这类页面
/// 需要用户自己的登录态与支付环境，系统浏览器比内嵌 WebView 更稳，也不用在应用里
/// 维护第二套网络与渲染栈；Android 侧落到的就是 `Intent.ACTION_VIEW`（官方插件封装）。
///
/// 包一层而不是让页面直接调插件，是为了给 widget 测试留注入点：测试宿主没有插件
/// 实现，直接调用会抛 `MissingPluginException`。
class ExternalLinks {
  ExternalLinks._();

  /// 爱发电赞助主页：与 `.github/FUNDING.yml`、README 的赞助入口保持同一地址。
  static const String donationUrl = 'https://afdian.com/a/talyra42';

  /// Veri Fin 的 GitHub Releases 页面（检查更新的跳转目标）。
  static const String verifinReleasesUrl =
      'https://github.com/LumiDesk/verifin/releases';

  /// 测试注入点：替换真正打开浏览器的动作，返回是否成功。
  @visibleForTesting
  static Future<bool> Function(Uri url)? debugOpener;

  /// 打开赞助主页，返回是否真的把链接交给了浏览器。
  static Future<bool> openDonation() => open(Uri.parse(donationUrl));

  /// 打开指定 tag 的 Release 页面，返回是否真的把链接交给了浏览器。
  ///
  /// [tag] 来自远端 JSON，因此先按版本号形态严格校验，只有合法 tag 才拼成
  /// `/releases/tag/<tag>`；不合法时回落到 Releases 列表页。这样「只打开本文件
  /// 定义的地址」这条约定不被远端数据绕过。
  static Future<bool> openVerifinRelease(String tag) {
    final normalized = tag.trim();
    final safeTag = RegExp(r'^v?\d+(?:\.\d+)*$').hasMatch(normalized)
        ? normalized
        : null;
    final url = safeTag == null
        ? Uri.parse(verifinReleasesUrl)
        : Uri.parse('$verifinReleasesUrl/tag/${Uri.encodeComponent(safeTag)}');
    return open(url);
  }

  /// 只接受 `https`：其余 scheme（http、intent、file…）一律拒绝并返回 false。
  static Future<bool> open(Uri url) async {
    if (url.scheme != 'https') {
      return false;
    }
    final opener = debugOpener;
    if (opener != null) {
      return opener(url);
    }
    try {
      return await launchUrl(url, mode: LaunchMode.platformDefault);
    } on Exception {
      // 没有能处理该链接的浏览器（或宿主没有插件实现）属于可接受的降级：这里只把
      // 结果归一为 false，日志与用户可见反馈由调用方负责。
      return false;
    }
  }
}
