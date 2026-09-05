import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:verifin/app/glass_lighting.dart';
import 'package:verifin/app/navigation_glass_lens.dart';

/// 单独安装的 Android 图形诊断入口。
///
/// 这个 target 只渲染高级材质的候选图层，不初始化 Controller、SQLite、KV 或平台业务。
/// 配合 `--flavor diagnostic` 构建时使用独立 applicationId，不能访问正式应用数据。
void main() => runApp(const _AdvancedMaterialDiagnosticApp());

class _AdvancedMaterialDiagnosticApp extends StatelessWidget {
  const _AdvancedMaterialDiagnosticApp();

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Veri Fin 图形诊断',
    theme: ThemeData(
      brightness: Brightness.dark,
      colorSchemeSeed: const Color(0xff346edb),
      useMaterial3: true,
    ),
    home: const _DiagnosticPage(),
  );
}

class _DiagnosticPage extends StatefulWidget {
  const _DiagnosticPage();

  @override
  State<_DiagnosticPage> createState() => _DiagnosticPageState();
}

class _DiagnosticPageState extends State<_DiagnosticPage> {
  final _sourceKey = GlobalKey();
  ui.FragmentShader? _shader;
  ui.Image? _source;
  var _showDirectionLights = false;
  var _showRefraction = false;
  var _status = '尚未运行高级图层。';

  @override
  void dispose() {
    _source?.dispose();
    _shader?.dispose();
    super.dispose();
  }

  void _showLights() {
    setState(() {
      _showDirectionLights = true;
      _showRefraction = false;
      _status = '场景 A：16 张卡片的方向高光已绘制；未加载导航 Shader。';
    });
  }

  Future<void> _loadShader({required bool drawRefraction}) async {
    setState(() {
      _showDirectionLights = false;
      _showRefraction = false;
      _status = drawRefraction ? '正在读取导航纹理并绘制 Shader…' : '正在加载导航 Shader…';
    });
    try {
      final program = await ui.FragmentProgram.fromAsset(
        'shaders/navigation_lens.frag',
      );
      final nextShader = program.fragmentShader();
      if (!mounted) {
        nextShader.dispose();
        return;
      }
      final previous = _shader;
      setState(() {
        _shader = nextShader;
        _status = drawRefraction
            ? 'Shader 已加载，等待导航源图层完成绘制。'
            : '场景 B：Shader 已加载，未发起纹理读回或绘制。';
      });
      previous?.dispose();
      if (drawRefraction) {
        WidgetsBinding.instance.addPostFrameCallback((_) => _captureAndDraw());
      }
    } catch (error) {
      if (!mounted) return;
      setState(() => _status = 'Shader 加载失败：$error');
    }
  }

  void _captureAndDraw() {
    final boundary = _sourceKey.currentContext?.findRenderObject();
    if (boundary is! RenderRepaintBoundary || !boundary.hasSize) {
      if (mounted) setState(() => _status = '导航源图层尚未准备好。');
      return;
    }
    try {
      final nextSource = boundary.toImageSync(
        pixelRatio: MediaQuery.devicePixelRatioOf(context) * 2,
      );
      if (!mounted) {
        nextSource.dispose();
        return;
      }
      final previous = _source;
      setState(() {
        _source = nextSource;
        _showRefraction = true;
        _status = '场景 C：Shader 已加载，并完成一次 2× 像素比导航纹理读回与折射绘制。';
      });
      previous?.dispose();
    } catch (error) {
      if (!mounted) return;
      setState(() => _status = '导航纹理读回失败：$error');
    }
  }

  void _clear() {
    setState(() {
      _showDirectionLights = false;
      _showRefraction = false;
      _status = '已清空高级图层；Shader 对象保留在内存中，便于验证仅绘制差异。';
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Veri Fin 图形诊断')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text('Android 高级材质隔离复现', style: theme.textTheme.titleLarge),
            const SizedBox(height: 6),
            Text(
              '此应用没有 Controller、账目或数据库。每次只开启一种候选渲染路径。',
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            _DiagnosticControls(
              onShowLights: _showLights,
              onCompileShader: () => _loadShader(drawRefraction: false),
              onDrawRefraction: () => _loadShader(drawRefraction: true),
              onClear: _clear,
            ),
            const SizedBox(height: 16),
            _StatusCard(status: _status),
            const SizedBox(height: 20),
            RepaintBoundary(
              key: _sourceKey,
              child: const _NavigationSourceSample(),
            ),
            if (_showRefraction && _source != null && _shader != null) ...[
              const SizedBox(height: 12),
              SizedBox(
                height: 64,
                child: CustomPaint(
                  painter: VeriNavigationLensPainter(
                    shader: _shader!,
                    source: _source!,
                    origin: Offset.zero,
                    sourceSize: const Size(328, 64),
                    activity: 1,
                    motion: 0.55,
                  ),
                ),
              ),
            ],
            if (_showDirectionLights) ...[
              const SizedBox(height: 20),
              for (var index = 0; index < 16; index++)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _LightProbeCard(index: index),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

class _DiagnosticControls extends StatelessWidget {
  const _DiagnosticControls({
    required this.onShowLights,
    required this.onCompileShader,
    required this.onDrawRefraction,
    required this.onClear,
  });

  final VoidCallback onShowLights;
  final VoidCallback onCompileShader;
  final VoidCallback onDrawRefraction;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) => Wrap(
    spacing: 8,
    runSpacing: 8,
    children: [
      FilledButton.tonal(
        key: const Key('probe_direction_lights'),
        onPressed: onShowLights,
        child: const Text('A · 方向高光 × 16'),
      ),
      FilledButton.tonal(
        key: const Key('probe_shader_compile'),
        onPressed: onCompileShader,
        child: const Text('B · 仅加载 Shader'),
      ),
      FilledButton(
        key: const Key('probe_shader_refraction'),
        onPressed: onDrawRefraction,
        child: const Text('C · Shader + 纹理读回'),
      ),
      TextButton(
        key: const Key('probe_clear'),
        onPressed: onClear,
        child: const Text('清空'),
      ),
    ],
  );
}

class _StatusCard extends StatelessWidget {
  const _StatusCard({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) => Container(
    key: const Key('probe_status'),
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(16),
    ),
    child: Text(status),
  );
}

class _NavigationSourceSample extends StatelessWidget {
  const _NavigationSourceSample();

  @override
  Widget build(BuildContext context) => Container(
    height: 64,
    padding: const EdgeInsets.symmetric(horizontal: 18),
    decoration: BoxDecoration(
      color: const Color(0xff202735),
      borderRadius: BorderRadius.circular(32),
    ),
    child: const Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: [
        _NavItem(icon: Icons.home, label: '首页'),
        _NavItem(icon: Icons.account_balance_wallet_outlined, label: '资产'),
        _NavItem(icon: Icons.bar_chart_outlined, label: '看板'),
        _NavItem(icon: Icons.person_outline, label: '我的'),
      ],
    ),
  );
}

class _NavItem extends StatelessWidget {
  const _NavItem({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icon, size: 20),
      Text(label, style: const TextStyle(fontSize: 11)),
    ],
  );
}

class _LightProbeCard extends StatelessWidget {
  const _LightProbeCard({required this.index});

  final int index;

  @override
  Widget build(BuildContext context) => CustomPaint(
    foregroundPainter: const VeriGlassLightPainter(
      radius: 16,
      brightness: Brightness.dark,
    ),
    child: Container(
      height: 70,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xff202735),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text('方向高光样本 ${index + 1}'),
      ),
    ),
  );
}
