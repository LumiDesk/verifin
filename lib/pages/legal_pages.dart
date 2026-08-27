import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app/app_theme.dart';
import '../app/common_widgets.dart';
import '../app/legal_content.dart';
import '../app/veri_fin_scope.dart';
import '../l10n/app_localizations.dart';

/// 展示单份法律文档（隐私政策 / 用户协议）。可再次查看，也用于首启动同意弹窗的详情。
class LegalDocumentPage extends StatelessWidget {
  const LegalDocumentPage({super.key, required this.document});

  final LegalDocument document;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: VeriPage(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(14, 8, 14, 28),
            children: <Widget>[
              VeriHeader(
                title: document.title(AppLocalizations.of(context)),
                subtitle: AppLocalizations.of(
                  context,
                ).legalUpdated(legalUpdatedAt),
                showBack: true,
              ),
              const SizedBox(height: 10),
              VeriCard(child: LegalBody(body: document.body)),
            ],
          ),
        ),
      ),
    );
  }
}

/// 将法律文档正文按段落渲染，章节标题（如「一、…」）加粗。
class LegalBody extends StatelessWidget {
  const LegalBody({super.key, required this.body});

  final String body;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final lines = body.trim().split('\n');
    final children = <Widget>[];
    for (final raw in lines) {
      final line = raw.trim();
      if (line.isEmpty) {
        children.add(const SizedBox(height: 10));
        continue;
      }
      final isHeading = _headingPattern.hasMatch(line);
      children.add(
        Padding(
          padding: EdgeInsets.only(top: isHeading ? 6 : 0, bottom: 4),
          child: Text(
            line,
            style: isHeading
                ? theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  )
                : theme.textTheme.bodyMedium?.copyWith(
                    height: 1.6,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.82),
                  ),
          ),
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: children,
    );
  }
}

final RegExp _headingPattern = RegExp(r'^[一二三四五六七八九十]+、');

/// 首启动的隐私政策 / 用户协议同意页（全屏、不可通过返回键关闭）。
///
/// 由 [PrivacyConsentGate] 在未同意时呈现，取代旧的一次性弹窗，避免
/// 「拒绝退出后进程未死、热启动回到前台时不再询问」的问题：门卫每次 build
/// 都按 `privacyConsentAccepted` 决定是否显示本页。
///
/// 「同意并继续」记录同意（门卫随即切换到主界面）；「不同意并退出」退出应用。
class PrivacyConsentPage extends StatelessWidget {
  const PrivacyConsentPage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return PopScope(
      canPop: false,
      child: Scaffold(
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 32, 24, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  AppLocalizations.of(context).privacyAndTerms,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 20),
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          legalConsentSummary,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            height: 1.7,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 6,
                          children: <Widget>[
                            for (final document in LegalDocument.values)
                              TextButton(
                                style: TextButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                  ),
                                  minimumSize: const Size(0, 36),
                                  tapTargetSize:
                                      MaterialTapTargetSize.shrinkWrap,
                                ),
                                onPressed: () {
                                  Navigator.of(context).push<void>(
                                    MaterialPageRoute<void>(
                                      builder: (context) =>
                                          LegalDocumentPage(document: document),
                                    ),
                                  );
                                },
                                child: Text(
                                  '《${document.title(AppLocalizations.of(context))}》',
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    key: const Key('privacy_consent_accept'),
                    style: FilledButton.styleFrom(
                      backgroundColor: veriRoyal,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    onPressed: () async {
                      await VeriFinScope.of(context).acceptPrivacyConsent();
                    },
                    child: Text(AppLocalizations.of(context).agreeContinue),
                  ),
                ),
                const SizedBox(height: 6),
                SizedBox(
                  width: double.infinity,
                  child: TextButton(
                    onPressed: () => SystemNavigator.pop(),
                    child: Text(
                      AppLocalizations.of(context).disagreeExit,
                      style: TextStyle(color: theme.colorScheme.onSurface),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
