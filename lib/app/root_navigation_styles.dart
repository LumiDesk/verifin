import 'root_navigation.dart';
import 'root_navigation_docked.dart';

/// 默认样式：新安装、偏好缺失或读到未知标识时的回退。
///
/// 必须出现在 [veriRootNavigationStyles] 中（测试会断言）。
const VeriRootNavigationStyle veriRootDefaultNavigationStyle =
    VeriDockedRootNavigationStyle();

/// 已注册的根导航样式。顺序即设置页样式选择列表的展示顺序。
///
/// 新增样式时：实现 [VeriRootNavigationStyle]、在 `NavigationStylePreference` 里加同名
/// 枚举值、在这里登记，并让测试覆盖新样式的契约（不透明表面、无模糊、条目 key、
/// 安全区下限、避让自洽）。
const List<VeriRootNavigationStyle> veriRootNavigationStyles =
    <VeriRootNavigationStyle>[VeriDockedRootNavigationStyle()];

/// 按持久化标识取样式；缺失或未知标识一律回退 [veriRootDefaultNavigationStyle]。
VeriRootNavigationStyle veriRootNavigationStyleFor(String? id) {
  if (id == null || id.isEmpty) {
    return veriRootDefaultNavigationStyle;
  }
  for (final style in veriRootNavigationStyles) {
    if (style.id == id) {
      return style;
    }
  }
  return veriRootDefaultNavigationStyle;
}
