import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app/app_lock.dart';
import '../app/app_theme.dart';
import '../app/biometric_auth.dart';
import '../app/common_widgets.dart';
import '../app/veri_fin_controller.dart';
import '../app/veri_fin_scope.dart';

/// 6 位 PIN 输入视图：圆点指示 + 数字键盘。输满 [kAppLockPinLength] 位自动回调
/// [onCompleted] 并清空输入，由上层判定成功/失败并通过 [errorText] 反馈。
///
/// [footer] 用于在键盘左下角放置额外操作（如生物识别解锁按钮）。
class PinInputView extends StatefulWidget {
  const PinInputView({
    super.key,
    required this.onCompleted,
    this.errorText,
    this.hapticsEnabled = true,
    this.footer,
  });

  final ValueChanged<String> onCompleted;
  final String? errorText;
  final bool hapticsEnabled;
  final Widget? footer;

  @override
  State<PinInputView> createState() => _PinInputViewState();
}

class _PinInputViewState extends State<PinInputView> {
  String _input = '';

  void _press(String digit) {
    if (_input.length >= kAppLockPinLength) {
      return;
    }
    if (widget.hapticsEnabled) {
      HapticFeedback.lightImpact();
    }
    setState(() => _input += digit);
    if (_input.length == kAppLockPinLength) {
      final value = _input;
      setState(() => _input = '');
      widget.onCompleted(value);
    }
  }

  void _backspace() {
    if (_input.isEmpty) {
      return;
    }
    if (widget.hapticsEnabled) {
      HapticFeedback.selectionClick();
    }
    setState(() => _input = _input.substring(0, _input.length - 1));
  }

  @override
  Widget build(BuildContext context) {
    final error = widget.errorText;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            for (var i = 0; i < kAppLockPinLength; i += 1)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: _PinDot(filled: i < _input.length),
              ),
          ],
        ),
        const SizedBox(height: 14),
        SizedBox(
          height: 20,
          child: error == null
              ? null
              : Text(
                  error,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: veriExpense,
                    fontWeight: FontWeight.w700,
                  ),
                ),
        ),
        const SizedBox(height: 8),
        _Keypad(
          onDigit: _press,
          onBackspace: _backspace,
          footer: widget.footer,
        ),
      ],
    );
  }
}

class _PinDot extends StatelessWidget {
  const _PinDot({required this.filled});

  final bool filled;

  @override
  Widget build(BuildContext context) {
    final base = Theme.of(context).colorScheme.onSurface;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 120),
      width: 14,
      height: 14,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: filled ? veriRoyal : Colors.transparent,
        border: Border.all(
          color: filled ? veriRoyal : base.withValues(alpha: 0.32),
          width: 1.6,
        ),
      ),
    );
  }
}

class _Keypad extends StatelessWidget {
  const _Keypad({
    required this.onDigit,
    required this.onBackspace,
    this.footer,
  });

  final ValueChanged<String> onDigit;
  final VoidCallback onBackspace;
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 300),
      child: GridView.count(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisCount: 3,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 1.3,
        children: <Widget>[
          for (var digit = 1; digit <= 9; digit += 1)
            _DigitKey(digit: '$digit', onTap: () => onDigit('$digit')),
          footer ?? const SizedBox.shrink(),
          _DigitKey(digit: '0', onTap: () => onDigit('0')),
          // 不用 IconButton 的 tooltip：锁屏覆盖在根 Navigator 之上，
          // Tooltip 找不到 Overlay 祖先会报错。
          Semantics(
            label: '删除',
            button: true,
            child: IconButton(
              key: const Key('pin_backspace'),
              onPressed: onBackspace,
              icon: const Icon(Icons.backspace_outlined),
            ),
          ),
        ],
      ),
    );
  }
}

class _DigitKey extends StatelessWidget {
  const _DigitKey({required this.digit, required this.onTap});

  final String digit;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Material(
      key: Key('pin_key_$digit'),
      color: isDark
          ? Theme.of(context).colorScheme.surfaceContainerHighest
          : const Color(0xFFEAF0F8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(veriRadiusMd),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(veriRadiusMd),
        onTap: onTap,
        child: Center(
          child: Text(
            digit,
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
          ),
        ),
      ),
    );
  }
}

/// 图案区域边长（正方形），供绘制与测试计算点位。
const double kPatternAreaSize = 264;

/// 索引 [index]（0-8，行优先）在边长 [size] 的图案区域内的圆心坐标。
Offset patternDotCenter(int index, double size) {
  final cell = size / 3;
  return Offset((index % 3 + 0.5) * cell, (index ~/ 3 + 0.5) * cell);
}

/// 3×3 图案输入视图：拖动连接圆点。松手时若连接点数 ≥ [kAppLockPatternMinPoints]
/// 则回调 [onCompleted]（点序列以 `-` 连接，如 `0-1-2-4-8`），否则提示过短并重置。
class PatternInputView extends StatefulWidget {
  const PatternInputView({
    super.key,
    required this.onCompleted,
    this.errorText,
    this.hapticsEnabled = true,
  });

  final ValueChanged<String> onCompleted;
  final String? errorText;
  final bool hapticsEnabled;

  @override
  State<PatternInputView> createState() => _PatternInputViewState();
}

class _PatternInputViewState extends State<PatternInputView> {
  final List<int> _selected = <int>[];
  Offset? _pointer;
  String? _tooShort;

  void _hitTest(Offset local) {
    for (var i = 0; i < 9; i += 1) {
      final center = patternDotCenter(i, kPatternAreaSize);
      if ((local - center).distance <= kPatternAreaSize / 6 * 0.62) {
        if (!_selected.contains(i)) {
          if (widget.hapticsEnabled) {
            HapticFeedback.selectionClick();
          }
          setState(() => _selected.add(i));
        }
        return;
      }
    }
  }

  void _start(Offset local) {
    setState(() {
      _selected.clear();
      _tooShort = null;
      _pointer = local;
    });
    _hitTest(local);
  }

  void _update(Offset local) {
    setState(() => _pointer = local);
    _hitTest(local);
  }

  void _end() {
    final sequence = _selected.join('-');
    final count = _selected.length;
    if (count < kAppLockPatternMinPoints) {
      setState(() {
        _selected.clear();
        _pointer = null;
        _tooShort = '至少连接 $kAppLockPatternMinPoints 个点';
      });
      return;
    }
    setState(() {
      _selected.clear();
      _pointer = null;
    });
    widget.onCompleted(sequence);
  }

  @override
  Widget build(BuildContext context) {
    final error = widget.errorText ?? _tooShort;
    final dotColor = Theme.of(context).colorScheme.onSurface;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        SizedBox(
          width: kPatternAreaSize,
          height: kPatternAreaSize,
          child: GestureDetector(
            key: const Key('pattern_area'),
            behavior: HitTestBehavior.opaque,
            onPanStart: (details) => _start(details.localPosition),
            onPanUpdate: (details) => _update(details.localPosition),
            onPanEnd: (_) => _end(),
            child: CustomPaint(
              painter: _PatternPainter(
                selected: _selected,
                pointer: _pointer,
                accent: veriRoyal,
                dotColor: dotColor,
              ),
            ),
          ),
        ),
        const SizedBox(height: 14),
        SizedBox(
          height: 20,
          child: error == null
              ? null
              : Text(
                  error,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: veriExpense,
                    fontWeight: FontWeight.w700,
                  ),
                ),
        ),
      ],
    );
  }
}

class _PatternPainter extends CustomPainter {
  _PatternPainter({
    required this.selected,
    required this.pointer,
    required this.accent,
    required this.dotColor,
  });

  final List<int> selected;
  final Offset? pointer;
  final Color accent;
  final Color dotColor;

  @override
  void paint(Canvas canvas, Size size) {
    final linePaint = Paint()
      ..color = accent
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    for (var i = 0; i < selected.length - 1; i += 1) {
      canvas.drawLine(
        patternDotCenter(selected[i], size.width),
        patternDotCenter(selected[i + 1], size.width),
        linePaint,
      );
    }
    if (selected.isNotEmpty && pointer != null) {
      canvas.drawLine(
        patternDotCenter(selected.last, size.width),
        pointer!,
        linePaint,
      );
    }

    for (var i = 0; i < 9; i += 1) {
      final center = patternDotCenter(i, size.width);
      final active = selected.contains(i);
      canvas.drawCircle(
        center,
        active ? 9 : 6,
        Paint()..color = active ? accent : dotColor.withValues(alpha: 0.28),
      );
      if (active) {
        canvas.drawCircle(
          center,
          16,
          Paint()
            ..color = accent
            ..strokeWidth = 2
            ..style = PaintingStyle.stroke,
        );
      }
    }
  }

  @override
  bool shouldRepaint(_PatternPainter oldDelegate) {
    return oldDelegate.selected != selected || oldDelegate.pointer != pointer;
  }
}

/// 按锁类型构建输入视图。[footer]（如生物识别按钮）仅数字密码键盘支持。
Widget buildAppLockInput({
  required AppLockKind kind,
  required ValueChanged<String> onCompleted,
  String? errorText,
  bool hapticsEnabled = true,
  Widget? footer,
}) {
  if (kind == AppLockKind.pattern) {
    return PatternInputView(
      onCompleted: onCompleted,
      errorText: errorText,
      hapticsEnabled: hapticsEnabled,
    );
  }
  return PinInputView(
    onCompleted: onCompleted,
    errorText: errorText,
    hapticsEnabled: hapticsEnabled,
    footer: footer,
  );
}

/// 全屏锁定界面（由 AppLockGate 覆盖在应用之上）。校验通过后回调 [onUnlocked]。
/// 开启生物识别（仅指纹）时，出现锁屏即自动发起一次指纹验证，并提供手动重试按钮。
class AppLockScreen extends StatefulWidget {
  const AppLockScreen({super.key, required this.onUnlocked});

  final VoidCallback onUnlocked;

  @override
  State<AppLockScreen> createState() => _AppLockScreenState();
}

class _AppLockScreenState extends State<AppLockScreen> {
  final BiometricAuth _biometric = const BiometricAuth();
  String? _error;
  bool _biometricAvailable = false;
  bool _authInProgress = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _initBiometric());
  }

  Future<void> _initBiometric() async {
    if (!mounted) {
      return;
    }
    if (!VeriFinScope.of(context).biometricUnlockEnabled) {
      return;
    }
    final available = await _biometric.isAvailable();
    if (!mounted) {
      return;
    }
    setState(() => _biometricAvailable = available);
    if (available) {
      _runBiometric();
    }
  }

  Future<void> _runBiometric() async {
    if (_authInProgress) {
      return;
    }
    setState(() => _authInProgress = true);
    final ok = await _biometric.authenticate(reason: '验证指纹以解锁 Veri Fin');
    if (!mounted) {
      return;
    }
    setState(() => _authInProgress = false);
    if (ok) {
      widget.onUnlocked();
    }
  }

  void _submit(String secret) {
    final controller = VeriFinScope.of(context);
    if (controller.verifyAppLock(secret)) {
      widget.onUnlocked();
      return;
    }
    setState(() => _error = '验证失败，请重试');
  }

  @override
  Widget build(BuildContext context) {
    final controller = VeriFinScope.of(context);
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                const Icon(Icons.lock_outline, size: 40, color: veriRoyal),
                const SizedBox(height: 12),
                Text(
                  '输入密码',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 6),
                Text(
                  controller.appLockKind == AppLockKind.pattern
                      ? '请绘制图案解锁'
                      : '请输入 6 位数字密码解锁',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                ),
                const SizedBox(height: 28),
                buildAppLockInput(
                  kind: controller.appLockKind,
                  onCompleted: _submit,
                  errorText: _error,
                  hapticsEnabled: controller.hapticsEnabled,
                ),
                if (_biometricAvailable) ...<Widget>[
                  const SizedBox(height: 16),
                  TextButton.icon(
                    onPressed: _authInProgress ? null : _runBiometric,
                    icon: const Icon(Icons.fingerprint),
                    label: const Text('指纹解锁'),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 设置或修改密钥：输入两遍确认后保存。保存成功 pop(true)。支持数字密码与图案。
class AppLockSetupPage extends StatefulWidget {
  const AppLockSetupPage({super.key, this.kind = AppLockKind.pin});

  final AppLockKind kind;

  @override
  State<AppLockSetupPage> createState() => _AppLockSetupPageState();
}

class _AppLockSetupPageState extends State<AppLockSetupPage> {
  String? _first;
  String? _error;

  bool get _isPattern => widget.kind == AppLockKind.pattern;

  void _onCompleted(String secret) {
    final first = _first;
    if (first == null) {
      setState(() {
        _first = secret;
        _error = null;
      });
      return;
    }
    if (secret != first) {
      setState(() {
        _first = null;
        _error = _isPattern ? '两次图案不一致，请重新绘制' : '两次输入不一致，请重新设置';
      });
      return;
    }
    VeriFinScope.of(context).setAppLock(kind: widget.kind, secret: secret);
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final controller = VeriFinScope.of(context);
    final confirming = _first != null;
    final String hint;
    if (_isPattern) {
      hint = confirming ? '再次绘制以确认' : '绘制解锁图案（至少 4 个点）';
    } else {
      hint = confirming ? '再次输入以确认' : '设置 6 位数字密码';
    }
    return Scaffold(
      body: SafeArea(
        child: VeriPage(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(14, 8, 14, 28),
            children: <Widget>[
              VeriHeader(title: _isPattern ? '设置图案' : '设置密码', showBack: true),
              const SizedBox(height: 30),
              Text(
                hint,
                textAlign: TextAlign.center,
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 28),
              buildAppLockInput(
                kind: widget.kind,
                onCompleted: _onCompleted,
                errorText: _error,
                hapticsEnabled: controller.hapticsEnabled,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 验证当前应用锁密钥。验证通过 pop(true)。用于关闭应用锁、修改密码前的校验。
class AppLockVerifyPage extends StatefulWidget {
  const AppLockVerifyPage({super.key, this.title = '验证密码'});

  final String title;

  @override
  State<AppLockVerifyPage> createState() => _AppLockVerifyPageState();
}

class _AppLockVerifyPageState extends State<AppLockVerifyPage> {
  String? _error;

  void _onCompleted(String secret) {
    if (VeriFinScope.of(context).verifyAppLock(secret)) {
      Navigator.of(context).pop(true);
      return;
    }
    setState(() => _error = '验证失败，请重试');
  }

  @override
  Widget build(BuildContext context) {
    final controller = VeriFinScope.of(context);
    final isPattern = controller.appLockKind == AppLockKind.pattern;
    return Scaffold(
      body: SafeArea(
        child: VeriPage(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(14, 8, 14, 28),
            children: <Widget>[
              VeriHeader(title: widget.title, showBack: true),
              const SizedBox(height: 30),
              Text(
                isPattern ? '请绘制当前解锁图案' : '请输入当前 6 位数字密码',
                textAlign: TextAlign.center,
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 28),
              buildAppLockInput(
                kind: controller.appLockKind,
                onCompleted: _onCompleted,
                errorText: _error,
                hapticsEnabled: controller.hapticsEnabled,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 应用锁设置页：开关应用锁、修改锁定方式与密码、开关指纹解锁。
class AppLockSettingsPage extends StatefulWidget {
  const AppLockSettingsPage({super.key});

  @override
  State<AppLockSettingsPage> createState() => _AppLockSettingsPageState();
}

class _AppLockSettingsPageState extends State<AppLockSettingsPage> {
  final BiometricAuth _biometric = const BiometricAuth();
  bool _biometricAvailable = false;

  @override
  void initState() {
    super.initState();
    _loadBiometricAvailability();
  }

  Future<void> _loadBiometricAvailability() async {
    final available = await _biometric.isAvailable();
    if (mounted) {
      setState(() => _biometricAvailable = available);
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = VeriFinScope.of(context);
    final enabled = controller.appLockEnabled;

    return Scaffold(
      body: SafeArea(
        child: VeriPage(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(14, 8, 14, 28),
            children: <Widget>[
              const VeriHeader(
                title: '应用锁',
                subtitle: '启动和回到前台时校验',
                showBack: true,
              ),
              const SizedBox(height: 10),
              VeriCard(
                child: Column(
                  children: <Widget>[
                    CompactSwitchRow(
                      icon: Icons.lock_outline,
                      title: const Text('应用锁'),
                      value: enabled,
                      onChanged: (value) => _toggle(controller, value),
                    ),
                    if (enabled) ...<Widget>[
                      const Divider(height: 1),
                      SettingsRow(
                        icon: Icons.password_outlined,
                        title: '锁定方式与密码',
                        trailing: controller.appLockKind.label,
                        trailingIcon: Icons.chevron_right,
                        onTap: () => _change(controller),
                      ),
                      if (_biometricAvailable) ...<Widget>[
                        const Divider(height: 1),
                        CompactSwitchRow(
                          icon: Icons.fingerprint,
                          title: const Text('指纹解锁'),
                          value: controller.biometricUnlockEnabled,
                          onChanged: (value) =>
                              _toggleBiometric(controller, value),
                        ),
                      ],
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 10),
              Text(
                '支持 6 位数字密码或 3×3 图案。密钥仅以加盐哈希保存在本机，不会上传，也无法找回；忘记时可在设置页初始化数据后重新设置。'
                '指纹解锁调用系统指纹，本应用不保存任何指纹数据；系统指纹变化后需重新验证。',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurface.withValues(alpha: 0.5),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _toggleBiometric(
    VeriFinController controller,
    bool value,
  ) async {
    if (!value) {
      controller.setBiometricUnlockEnabled(false);
      return;
    }
    // 开启前先验证一次指纹，确认可用。
    final ok = await _biometric.authenticate(reason: '验证指纹以开启指纹解锁');
    if (ok) {
      controller.setBiometricUnlockEnabled(true);
    } else if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('指纹验证未通过，未开启')));
    }
  }

  Future<void> _toggle(VeriFinController controller, bool value) async {
    if (value) {
      final kind = await _pickKind();
      if (kind == null || !mounted) {
        return;
      }
      await Navigator.of(context).push<bool>(
        MaterialPageRoute<bool>(
          builder: (context) => AppLockSetupPage(kind: kind),
        ),
      );
      return;
    }
    final verified = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (context) => const AppLockVerifyPage(title: '关闭应用锁'),
      ),
    );
    if (verified == true) {
      controller.disableAppLock();
    }
  }

  Future<void> _change(VeriFinController controller) async {
    final verified = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (context) => const AppLockVerifyPage(title: '修改应用锁'),
      ),
    );
    if (verified != true || !mounted) {
      return;
    }
    final kind = await _pickKind();
    if (kind == null || !mounted) {
      return;
    }
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (context) => AppLockSetupPage(kind: kind),
      ),
    );
    if (changed == true && mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('应用锁已更新')));
    }
  }

  /// 选择锁定方式（数字密码 / 图案）。
  Future<AppLockKind?> _pickKind() {
    return showModalBottomSheet<AppLockKind>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            ListTile(
              key: const Key('pick_lock_pin'),
              leading: const Icon(Icons.password_outlined),
              title: Text(AppLockKind.pin.label),
              subtitle: const Text('6 位数字'),
              onTap: () => Navigator.of(context).pop(AppLockKind.pin),
            ),
            ListTile(
              key: const Key('pick_lock_pattern'),
              leading: const Icon(Icons.pattern),
              title: Text(AppLockKind.pattern.label),
              subtitle: const Text('3×3 连线图案'),
              onTap: () => Navigator.of(context).pop(AppLockKind.pattern),
            ),
          ],
        ),
      ),
    );
  }
}
