import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:verifin/app/account_icon_assets.dart';
import 'package:verifin/app/app_theme.dart';
import 'package:verifin/app/common_widgets.dart';
import 'package:verifin/app/icon_catalog.dart';

class AccountIconPreview extends StatefulWidget {
  const AccountIconPreview({super.key});

  @override
  State<AccountIconPreview> createState() => _AccountIconPreviewState();
}

class _AccountIconPreviewState extends State<AccountIconPreview> {
  double _paddingFactor = 0.10;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      key: const Key('account_icon_preview'),
      backgroundColor: scheme.surface,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 28),
          children: <Widget>[
            Text(
              '账户图标白底方案',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 6),
            Text(
              '品牌 Logo 与默认账户图标统一收口为白底 SVG；品牌 Logo 不改色、不拉伸。',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: scheme.onSurface.withValues(alpha: 0.60),
              ),
            ),
            const SizedBox(height: 16),
            _PreviewCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: Text(
                          '候选内边距',
                          style: Theme.of(context).textTheme.titleSmall
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                      ),
                      Text(
                        '${(_paddingFactor * 100).round()}%',
                        key: const Key('account_icon_padding_value'),
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          color: veriRoyal,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: <Widget>[
                      for (final factor in const <double>[
                        0.18,
                        0.12,
                        0.10,
                        0.08,
                      ])
                        ChoiceChip(
                          key: Key(
                            'account_icon_padding_${(factor * 100).round()}',
                          ),
                          label: Text('${(factor * 100).round()}%'),
                          selected: _paddingFactor == factor,
                          showCheckmark: false,
                          onSelected: (_) {
                            setState(() => _paddingFactor = factor);
                          },
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '10% 是建议值：36dp 容器内边距约 3.6dp，对比当前约 6.5dp。',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: scheme.onSurface.withValues(alpha: 0.54),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Expanded(
                  child: _StyleComparisonCard(
                    title: '当前样式',
                    subtitle: '深色下近乎透明 · 18%',
                    currentStyle: true,
                    paddingFactor: 0.18,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _StyleComparisonCard(
                    title: '候选样式',
                    subtitle: '纯白背景 · ${(_paddingFactor * 100).round()}%',
                    currentStyle: false,
                    paddingFactor: _paddingFactor,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _PreviewCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    '七个默认图标 SVG 替代',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '当前 Material 色块 → Phosphor Duotone 白底双色层次',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: scheme.onSurface.withValues(alpha: 0.52),
                    ),
                  ),
                  const SizedBox(height: 10),
                  for (final spec in _genericIconSpecs.indexed) ...<Widget>[
                    _GenericIconComparisonRow(
                      spec: spec.$2,
                      paddingFactor: _paddingFactor,
                    ),
                    if (spec.$1 < _genericIconSpecs.length - 1)
                      const Divider(height: 10),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 12),
            _PreviewCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    '真实账户行对比',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 10),
                  _AccountRowComparison(
                    currentStyle: true,
                    paddingFactor: 0.18,
                    label: '当前',
                  ),
                  const Divider(height: 18),
                  _AccountRowComparison(
                    currentStyle: false,
                    paddingFactor: _paddingFactor,
                    label: '候选',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            _PreviewCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    '尺寸检查',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: <Widget>[
                      for (final size in const <double>[28, 32, 36])
                        Column(
                          children: <Widget>[
                            _PreviewAccountIconBox(
                              key: Key('account_icon_size_${size.round()}'),
                              iconCode: 'asset:payment_006',
                              size: size,
                              currentStyle: false,
                              paddingFactor: _paddingFactor,
                            ),
                            const SizedBox(height: 6),
                            Text(
                              '${size.round()}dp',
                              style: Theme.of(context).textTheme.labelSmall,
                            ),
                          ],
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StyleComparisonCard extends StatelessWidget {
  const _StyleComparisonCard({
    required this.title,
    required this.subtitle,
    required this.currentStyle,
    required this.paddingFactor,
  });

  final String title;
  final String subtitle;
  final bool currentStyle;
  final double paddingFactor;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    const samples = <String>[
      'asset:credit_001',
      'asset:payment_001',
      'asset:payment_004',
      'asset:bank_016',
    ];
    return _PreviewCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            maxLines: 2,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: scheme.onSurface.withValues(alpha: 0.52),
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: <Widget>[
              for (final code in samples)
                _PreviewAccountIconBox(
                  key: Key(
                    '${currentStyle ? 'current' : 'proposed'}_icon_$code',
                  ),
                  iconCode: code,
                  size: 36,
                  currentStyle: currentStyle,
                  paddingFactor: paddingFactor,
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _AccountRowComparison extends StatelessWidget {
  const _AccountRowComparison({
    required this.currentStyle,
    required this.paddingFactor,
    required this.label,
  });

  final bool currentStyle;
  final double paddingFactor;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        SizedBox(
          width: 38,
          child: Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: currentStyle ? null : veriRoyal,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        _PreviewAccountIconBox(
          iconCode: 'asset:payment_006',
          size: 32,
          currentStyle: currentStyle,
          paddingFactor: paddingFactor,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                '支付宝',
                style: Theme.of(
                  context,
                ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
              ),
              Text(
                '网络支付 · CNY',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurface.withValues(alpha: 0.48),
                ),
              ),
            ],
          ),
        ),
        Text(
          '¥8,320.00',
          style: Theme.of(
            context,
          ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
        ),
      ],
    );
  }
}

class _PreviewAccountIconBox extends StatelessWidget {
  const _PreviewAccountIconBox({
    super.key,
    required this.iconCode,
    required this.size,
    required this.currentStyle,
    required this.paddingFactor,
  });

  final String iconCode;
  final double size;
  final bool currentStyle;
  final double paddingFactor;

  @override
  Widget build(BuildContext context) {
    final option = accountAssetIconByCode(iconCode)!;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final padding = currentStyle
        ? (size * 0.18).clamp(4, 8).toDouble()
        : (size * paddingFactor).clamp(2, 6).toDouble();
    return Container(
      width: size,
      height: size,
      padding: EdgeInsets.all(padding),
      decoration: BoxDecoration(
        color: currentStyle
            ? (isDark
                  ? Colors.white.withValues(alpha: 0.08)
                  : Colors.white.withValues(alpha: 0.92))
            : Colors.white,
        borderRadius: BorderRadius.circular(veriRadiusSm),
        border: Border.all(
          color: currentStyle
              ? Theme.of(
                  context,
                ).colorScheme.onSurface.withValues(alpha: isDark ? 0.08 : 0.06)
              : Colors.black.withValues(alpha: 0.08),
        ),
      ),
      child: SvgPicture.asset(
        option.assetPath,
        package: 'verifin',
        fit: BoxFit.contain,
      ),
    );
  }
}

class _GenericIconComparisonRow extends StatelessWidget {
  const _GenericIconComparisonRow({
    required this.spec,
    required this.paddingFactor,
  });

  final _GenericIconSpec spec;
  final double paddingFactor;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        SizedBox(
          width: 48,
          child: Text(
            spec.label,
            style: Theme.of(
              context,
            ).textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
        ),
        KeyedSubtree(
          key: Key('current_generic_${spec.code}'),
          child: VeriIconBox(
            icon: iconForCode(spec.code),
            size: 36,
            color: veriRoyal,
          ),
        ),
        const SizedBox(width: 12),
        Icon(
          Icons.arrow_forward_rounded,
          size: 16,
          color: Theme.of(
            context,
          ).colorScheme.onSurface.withValues(alpha: 0.34),
        ),
        const SizedBox(width: 12),
        _PreviewGenericSvgBox(
          key: Key('proposed_generic_${spec.code}'),
          assetPath: spec.assetPath,
          size: 36,
          paddingFactor: paddingFactor,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            spec.description,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: Theme.of(
                context,
              ).colorScheme.onSurface.withValues(alpha: 0.50),
            ),
          ),
        ),
      ],
    );
  }
}

class _PreviewGenericSvgBox extends StatelessWidget {
  const _PreviewGenericSvgBox({
    super.key,
    required this.assetPath,
    required this.size,
    required this.paddingFactor,
  });

  final String assetPath;
  final double size;
  final double paddingFactor;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      padding: EdgeInsets.all((size * paddingFactor).clamp(2, 6).toDouble()),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(veriRadiusSm),
        border: Border.all(color: Colors.black.withValues(alpha: 0.08)),
      ),
      child: SvgPicture.asset(assetPath, fit: BoxFit.contain),
    );
  }
}

class _PreviewCard extends StatelessWidget {
  const _PreviewCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(veriRadiusMd),
        border: Border.all(
          color: Theme.of(
            context,
          ).colorScheme.onSurface.withValues(alpha: 0.08),
        ),
      ),
      child: child,
    );
  }
}

class _GenericIconSpec {
  const _GenericIconSpec({
    required this.code,
    required this.label,
    required this.assetPath,
    required this.description,
  });

  final String code;
  final String label;
  final String assetPath;
  final String description;
}

const _genericIconSpecs = <_GenericIconSpec>[
  _GenericIconSpec(
    code: 'wallet',
    label: '钱包',
    assetPath: 'assets/account_icon_candidates/wallet.svg',
    description: 'Wallet Duotone',
  ),
  _GenericIconSpec(
    code: 'credit',
    label: '信用',
    assetPath: 'assets/account_icon_candidates/credit.svg',
    description: 'Credit Card Duotone',
  ),
  _GenericIconSpec(
    code: 'bank',
    label: '银行',
    assetPath: 'assets/account_icon_candidates/bank.svg',
    description: 'Bank Duotone',
  ),
  _GenericIconSpec(
    code: 'cash',
    label: '现金',
    assetPath: 'assets/account_icon_candidates/cash.svg',
    description: 'Money Duotone',
  ),
  _GenericIconSpec(
    code: 'investment',
    label: '投资',
    assetPath: 'assets/account_icon_candidates/investment.svg',
    description: 'Chart Line Up Duotone',
  ),
  _GenericIconSpec(
    code: 'savings',
    label: '储蓄',
    assetPath: 'assets/account_icon_candidates/savings.svg',
    description: 'Piggy Bank Duotone',
  ),
  _GenericIconSpec(
    code: 'card',
    label: '卡片',
    assetPath: 'assets/account_icon_candidates/card.svg',
    description: 'Cards Duotone',
  ),
];
