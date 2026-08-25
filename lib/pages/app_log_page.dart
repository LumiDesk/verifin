import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app/app_theme.dart';
import '../app/common_widgets.dart';
import '../app/feedback.dart';
import '../app/logging/app_logger.dart';
import '../app/veri_fin_scope.dart';
import '../l10n/app_localizations.dart';

/// 软件日志页：倒序展示最近的错误与关键事件，支持一键复制全部（方便用户反馈时
/// 发给开发者）与清空。日志为设备本地、不进备份。
class AppLogPage extends StatelessWidget {
  const AppLogPage({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = VeriFinScope.of(context);
    final l10n = AppLocalizations.of(context);
    final logger = controller.logger;

    return Scaffold(
      body: SafeArea(
        child: VeriPage(
          child: logger == null
              ? _buildEmpty(context, l10n)
              : AnimatedBuilder(
                  animation: logger,
                  builder: (context, _) => _buildContent(context, l10n, logger),
                ),
        ),
      ),
    );
  }

  Widget _buildEmpty(BuildContext context, AppLocalizations l10n) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 28),
      children: <Widget>[
        VeriHeader(
          title: l10n.appLog,
          subtitle: l10n.appLogSubtitle,
          showBack: true,
        ),
        const SizedBox(height: 40),
        Center(
          child: Text(
            l10n.appLogEmpty,
            style: TextStyle(color: Theme.of(context).hintColor),
          ),
        ),
      ],
    );
  }

  Widget _buildContent(
    BuildContext context,
    AppLocalizations l10n,
    AppLogger logger,
  ) {
    final records = logger.records;
    return ListView(
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 28),
      children: <Widget>[
        VeriHeader(
          title: l10n.appLog,
          subtitle: l10n.appLogSubtitle,
          showBack: true,
          actions: <Widget>[
            IconButton(
              tooltip: l10n.appLogCopyAll,
              onPressed: records.isEmpty
                  ? null
                  : () => _copyAll(context, l10n, logger),
              icon: const Icon(Icons.copy_all_outlined),
            ),
            IconButton(
              tooltip: l10n.appLogClear,
              onPressed: records.isEmpty
                  ? null
                  : () => _confirmClear(context, l10n, logger),
              icon: const Icon(Icons.delete_outline),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (records.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 40),
            child: Center(
              child: Text(
                l10n.appLogEmpty,
                style: TextStyle(color: Theme.of(context).hintColor),
              ),
            ),
          )
        else ...<Widget>[
          Text(
            l10n.appLogCount(records.length),
            style: TextStyle(fontSize: 12, color: Theme.of(context).hintColor),
          ),
          const SizedBox(height: 8),
          VeriCard(
            child: Column(
              children: <Widget>[
                for (var i = 0; i < records.length; i++) ...<Widget>[
                  if (i > 0) const Divider(height: 1),
                  _LogTile(record: records[i]),
                ],
              ],
            ),
          ),
        ],
      ],
    );
  }

  Future<void> _copyAll(
    BuildContext context,
    AppLocalizations l10n,
    AppLogger logger,
  ) async {
    final feedback = VeriFeedbackHost.of(context);
    await Clipboard.setData(ClipboardData(text: logger.exportText()));
    unawaited(
      feedback.showMessage(
        message: l10n.appLogCopied,
        tone: VeriFeedbackTone.success,
        duration: VeriFeedbackDuration.short,
      ),
    );
  }

  Future<void> _confirmClear(
    BuildContext context,
    AppLocalizations l10n,
    AppLogger logger,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        content: Text(l10n.appLogClearConfirm),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.commonCancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.appLogClear),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      logger.clear();
    }
  }
}

class _LogTile extends StatelessWidget {
  const _LogTile({required this.record});

  final AppLogRecord record;

  @override
  Widget build(BuildContext context) {
    final color = switch (record.level) {
      AppLogLevel.error => veriExpense,
      AppLogLevel.warning => const Color(0xFFE8A33D),
      AppLogLevel.info => Theme.of(context).hintColor,
    };
    final time = record.time;
    final stamp =
        '${time.year}-${_two(time.month)}-${_two(time.day)} '
        '${_two(time.hour)}:${_two(time.minute)}:${_two(time.second)}';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            margin: const EdgeInsets.only(top: 4, right: 10),
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Text(
                      record.level.name.toUpperCase(),
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: color,
                      ),
                    ),
                    if (record.source != null &&
                        record.source!.isNotEmpty) ...<Widget>[
                      const SizedBox(width: 6),
                      Text(
                        record.source!,
                        style: TextStyle(
                          fontSize: 11,
                          color: Theme.of(context).hintColor,
                        ),
                      ),
                    ],
                    const Spacer(),
                    Text(
                      stamp,
                      style: TextStyle(
                        fontSize: 11,
                        color: Theme.of(context).hintColor,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(record.message, style: const TextStyle(fontSize: 13)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _two(int value) => value.toString().padLeft(2, '0');
}
