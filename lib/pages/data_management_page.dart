// 数据管理页：从 profile_pages 拆出。集中导出/导入/初始化与备份子系统
// （本地目录 SAF、加密、WebDAV、账单导入）的入口与流程。
import 'dart:convert';

import 'package:flutter/material.dart';

import '../app/app_theme.dart';
import '../app/backup/backup_archive.dart';
import '../app/backup/backup_crypto.dart';
import '../app/backup/backup_service.dart';
import '../app/backup/backup_settings.dart';
import '../app/backup/payment_import.dart';
import '../app/backup/transaction_import.dart';
import '../app/backup/webdav_client.dart';
import '../app/backup/webdav_config.dart';
import '../app/common_widgets.dart';
import '../app/data_file_port.dart';
import '../l10n/app_localizations.dart';
import '../app/veri_fin_controller.dart';
import '../app/veri_fin_scope.dart';
import 'app_log_page.dart';
import 'import_preview_page.dart';
import 'sheets.dart';

class DataManagementPage extends StatelessWidget {
  const DataManagementPage({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = VeriFinScope.of(context);

    return Scaffold(
      body: SafeArea(
        child: VeriPage(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(14, 8, 14, 28),
            children: <Widget>[
              VeriHeader(
                title: AppLocalizations.of(context).dataManagement,
                subtitle: AppLocalizations.of(context).dataMgmtSubtitle,
                showBack: true,
              ),
              const SizedBox(height: 10),
              _sectionLabel(
                context,
                AppLocalizations.of(context).dataSectionLocalBackup,
              ),
              VeriCard(
                child: Column(
                  children: <Widget>[
                    SettingsRow(
                      icon: Icons.folder_outlined,
                      title: AppLocalizations.of(context).backupDirLabel,
                      trailing: controller.backupSettings.hasDirectory
                          ? controller.backupSettings.directoryLabel
                          : AppLocalizations.of(context).notChosen,
                      trailingIcon: Icons.chevron_right,
                      onTap: () => _chooseBackupDirectory(context, controller),
                    ),
                    const Divider(),
                    SettingsRow(
                      icon: Icons.backup_outlined,
                      title: AppLocalizations.of(context).backupNow,
                      trailing: _lastBackupLabel(
                        AppLocalizations.of(context),
                        controller.backupSettings,
                      ),
                      trailingIcon: Icons.chevron_right,
                      onTap: () => _backupNow(context, controller),
                    ),
                    const Divider(),
                    SettingsRow(
                      icon: Icons.download_outlined,
                      title: AppLocalizations.of(context).exportData,
                      trailing: AppLocalizations.of(context).jsonBackup,
                      trailingIcon: Icons.chevron_right,
                      onTap: () => _exportData(context, controller),
                    ),
                    const Divider(),
                    SettingsRow(
                      icon: Icons.upload_file_outlined,
                      title: AppLocalizations.of(context).importData,
                      trailing: AppLocalizations.of(context).restoreFromFile,
                      trailingIcon: Icons.chevron_right,
                      onTap: () => _confirmImport(context, controller),
                    ),
                    if (controller.backupSettings.hasDirectory) ...<Widget>[
                      const Divider(),
                      SettingsRow(
                        icon: Icons.link_off,
                        title: AppLocalizations.of(context).clearBackupDir,
                        trailing: AppLocalizations.of(context).stopLocalBackup,
                        trailingIcon: Icons.chevron_right,
                        contentColor: veriExpense,
                        onTap: () => controller.clearBackupDirectory(),
                      ),
                    ],
                  ],
                ),
              ),
              if (controller.backupSettings.hasDirectory) ...<Widget>[
                const SizedBox(height: 10),
                _sectionLabel(context, AppLocalizations.of(context).autoBackup),
                VeriCard(
                  child: Column(
                    children: <Widget>[
                      SettingsRow(
                        icon: Icons.schedule_outlined,
                        title: AppLocalizations.of(
                          context,
                        ).backupFrequencyLabel,
                        trailing: controller.backupSettings.frequency.label(
                          AppLocalizations.of(context),
                        ),
                        trailingIcon: Icons.chevron_right,
                        onTap: () => _pickBackupFrequency(context, controller),
                      ),
                      if (controller.backupSettings.frequency ==
                          BackupFrequency.everyNHours) ...<Widget>[
                        const Divider(),
                        SettingsRow(
                          icon: Icons.hourglass_bottom_outlined,
                          title: AppLocalizations.of(
                            context,
                          ).backupIntervalLabel,
                          trailing: AppLocalizations.of(context)
                              .everyNHoursLabel(
                                controller.backupSettings.intervalHours,
                              ),
                          trailingIcon: Icons.chevron_right,
                          onTap: () => _pickBackupInterval(context, controller),
                        ),
                      ],
                      const Divider(),
                      SettingsRow(
                        icon: Icons.inventory_2_outlined,
                        title: AppLocalizations.of(context).retentionLabel,
                        trailing: AppLocalizations.of(
                          context,
                        ).latestNCopies(controller.backupSettings.retention),
                        trailingIcon: Icons.chevron_right,
                        onTap: () => _pickBackupRetention(context, controller),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 10),
              _sectionLabel(
                context,
                AppLocalizations.of(context).backupEncryption,
              ),
              VeriCard(
                child: Column(
                  children: <Widget>[
                    SettingsRow(
                      icon: Icons.enhanced_encryption_outlined,
                      title: AppLocalizations.of(context).encryptionKey,
                      trailing: controller.backupEncryptionEnabled
                          ? AppLocalizations.of(context).enabledLabel
                          : AppLocalizations.of(context).notSet,
                      trailingIcon: Icons.chevron_right,
                      onTap: () => _editBackupPassphrase(context, controller),
                    ),
                    if (controller.backupEncryptionEnabled) ...<Widget>[
                      const Divider(),
                      SettingsRow(
                        icon: Icons.no_encryption_outlined,
                        title: AppLocalizations.of(context).clearEncryptionKey,
                        trailing: AppLocalizations.of(context).noEncryptHint,
                        trailingIcon: Icons.chevron_right,
                        contentColor: veriExpense,
                        onTap: () =>
                            _confirmClearPassphrase(context, controller),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 10),
              _sectionLabel(
                context,
                AppLocalizations.of(context).webdavSection,
              ),
              VeriCard(
                child: Column(
                  children: <Widget>[
                    SettingsRow(
                      icon: Icons.cloud_outlined,
                      title: AppLocalizations.of(context).webdavServer,
                      trailing: controller.webdavConfig.isConfigured
                          ? AppLocalizations.of(context).configuredLabel
                          : AppLocalizations.of(context).notConfigured,
                      trailingIcon: Icons.chevron_right,
                      onTap: () => _editWebdav(context, controller),
                    ),
                    if (controller.webdavConfig.isConfigured) ...<Widget>[
                      const Divider(),
                      SettingsRow(
                        icon: Icons.cloud_upload_outlined,
                        title: AppLocalizations.of(context).uploadToWebdav,
                        trailing: AppLocalizations.of(context).uploadNow,
                        trailingIcon: Icons.chevron_right,
                        onTap: () => _uploadToWebdav(context, controller),
                      ),
                      const Divider(),
                      SettingsRow(
                        icon: Icons.cloud_download_outlined,
                        title: AppLocalizations.of(context).restoreFromWebdav,
                        trailing: AppLocalizations.of(context).chooseBackup,
                        trailingIcon: Icons.chevron_right,
                        onTap: () => _restoreFromWebdav(context, controller),
                      ),
                      const Divider(),
                      CompactSwitchRow(
                        icon: Icons.sync_outlined,
                        title: Text(
                          AppLocalizations.of(context).autoUploadWebdav,
                        ),
                        value: controller.webdavConfig.autoUpload,
                        onChanged: controller.setWebdavAutoUpload,
                      ),
                      const Divider(),
                      SettingsRow(
                        icon: Icons.cloud_off_outlined,
                        title: AppLocalizations.of(context).clearWebdav,
                        trailing: AppLocalizations.of(context).disconnectLabel,
                        trailingIcon: Icons.chevron_right,
                        contentColor: veriExpense,
                        onTap: () => _confirmClearWebdav(context, controller),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 10),
              _sectionLabel(
                context,
                AppLocalizations.of(context).importFromSheets,
              ),
              VeriCard(
                child: Column(
                  children: <Widget>[
                    SettingsRow(
                      icon: Icons.account_balance_wallet_outlined,
                      title: AppLocalizations.of(context).importBillFile,
                      trailing: AppLocalizations.of(context).importBillFileHint,
                      trailingIcon: Icons.chevron_right,
                      onTap: () => _importFromPlatform(context, controller),
                    ),
                    const Divider(),
                    SettingsRow(
                      icon: Icons.file_download_outlined,
                      title: AppLocalizations.of(context).downloadCsvTemplate,
                      trailing: AppLocalizations.of(context).excelHint,
                      trailingIcon: Icons.chevron_right,
                      onTap: () => _downloadCsvTemplate(context),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              _sectionLabel(
                context,
                AppLocalizations.of(context).dataSectionMaintenance,
              ),
              VeriCard(
                child: Column(
                  children: <Widget>[
                    SettingsRow(
                      icon: Icons.description_outlined,
                      title: AppLocalizations.of(context).appLog,
                      trailing: AppLocalizations.of(context).viewLabel,
                      trailingIcon: Icons.chevron_right,
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (context) => const AppLogPage(),
                        ),
                      ),
                    ),
                    const Divider(),
                    SettingsRow(
                      icon: Icons.restart_alt,
                      title: AppLocalizations.of(context).resetData,
                      trailing: AppLocalizations.of(context).deleteAllLocal,
                      trailingIcon: Icons.chevron_right,
                      contentColor: veriExpense,
                      onTap: () => _confirmReset(context, controller),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static Widget _sectionLabel(BuildContext context, String text) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(6, 4, 6, 8),
      child: Text(
        text,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  static String _lastBackupLabel(
    AppLocalizations l10n,
    BackupSettings settings,
  ) {
    final last = settings.lastBackupAt;
    if (last == null) {
      return l10n.neverBackedUp;
    }
    String two(int v) => v.toString().padLeft(2, '0');
    return l10n.lastBackupAt(
      '${last.year}-${two(last.month)}-${two(last.day)} '
      '${two(last.hour)}:${two(last.minute)}',
    );
  }

  Future<void> _chooseBackupDirectory(
    BuildContext context,
    VeriFinController controller,
  ) async {
    try {
      final picked = await BackupService.chooseDirectory();
      if (picked == null || !context.mounted) {
        return;
      }
      controller.setBackupDirectory(picked.uri, picked.label);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppLocalizations.of(context).chosenBackupDir(picked.label),
          ),
        ),
      );
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _backupErrorText(AppLocalizations.of(context), error),
            ),
          ),
        );
      }
    }
  }

  Future<void> _backupNow(
    BuildContext context,
    VeriFinController controller,
  ) async {
    if (!controller.backupSettings.hasDirectory) {
      await _chooseBackupDirectory(context, controller);
      if (!context.mounted || !controller.backupSettings.hasDirectory) {
        return;
      }
    }
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    // 备份含加密（PBKDF2）与文件写入，耗时可感知：期间弹不可关闭的「备份中」转圈，
    // 避免点了没反应的错觉。
    final navigator = Navigator.of(context, rootNavigator: true);
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => _BackupProgressDialog(label: l10n.backingUp),
    );
    try {
      final now = DateTime.now();
      final result = await BackupService.writeManualBackup(
        settings: controller.backupSettings,
        content: controller.exportDataJson(),
        now: now,
        passphrase: controller.backupPassphrase,
      );
      controller.recordBackupTime(now);
      navigator.pop(); // 关闭「备份中」
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.backedUpFile(result.filename))),
      );
    } catch (error) {
      navigator.pop(); // 关闭「备份中」
      messenger.showSnackBar(
        SnackBar(content: Text(_backupErrorText(l10n, error))),
      );
    }
  }

  static String _backupErrorText(AppLocalizations l10n, Object error) {
    // 已知的、面向用户可读的领域异常（加密 / WebDAV）展示其自带消息；
    // FormatException（空文件 / 格式无效，其内部 message 是硬编码中文）与其它
    // 技术异常（平台 / 文件系统等）统一给本地化友好文案，不把原始技术信息暴露给用户。
    if (error is BackupCryptoException) {
      return error.message;
    }
    if (error is WebdavException) {
      return error.message;
    }
    if (error is FormatException) {
      return l10n.backupInvalidFile;
    }
    return l10n.backupFailedRetry;
  }

  Future<void> _pickBackupFrequency(
    BuildContext context,
    VeriFinController controller,
  ) async {
    final selected = await showOptionSheet<BackupFrequency>(
      context: context,
      title: AppLocalizations.of(context).pickBackupFrequency,
      values: BackupFrequency.values,
      selected: controller.backupSettings.frequency,
      labelOf: (value) => value.label(AppLocalizations.of(context)),
    );
    if (selected != null) {
      controller.setBackupFrequency(selected);
    }
  }

  Future<void> _pickBackupInterval(
    BuildContext context,
    VeriFinController controller,
  ) async {
    const options = <int>[1, 3, 6, 12, 24, 48, 72];
    final selected = await showOptionSheet<int>(
      context: context,
      title: AppLocalizations.of(context).backupIntervalTitle,
      values: options,
      selected: options.contains(controller.backupSettings.intervalHours)
          ? controller.backupSettings.intervalHours
          : 24,
      labelOf: (value) => AppLocalizations.of(context).everyNHoursLabel(value),
    );
    if (selected != null) {
      controller.setBackupIntervalHours(selected);
    }
  }

  Future<void> _pickBackupRetention(
    BuildContext context,
    VeriFinController controller,
  ) async {
    const options = <int>[3, 5, 10, 20, 50];
    final selected = await showOptionSheet<int>(
      context: context,
      title: AppLocalizations.of(context).retentionTitle,
      values: options,
      selected: options.contains(controller.backupSettings.retention)
          ? controller.backupSettings.retention
          : 10,
      labelOf: (value) => AppLocalizations.of(context).latestNCopies(value),
    );
    if (selected != null) {
      controller.setBackupRetention(selected);
    }
  }

  Future<void> _exportData(
    BuildContext context,
    VeriFinController controller,
  ) async {
    try {
      // 未加密→zip（附件不膨胀）、加密→文本信封，统一按字节写入下载目录。
      final prepared = await BackupService.prepare(
        json: controller.exportDataJson(),
        passphrase: controller.backupPassphrase,
        now: DateTime.now(),
        auto: false,
      );
      final saved = await downloadBytesFile(
        filename: prepared.filename,
        bytes: prepared.bytes,
        mimeType: controller.backupEncryptionEnabled
            ? 'application/json'
            : 'application/zip',
      );
      if (saved && context.mounted) {
        final hint = controller.backupEncryptionEnabled
            ? AppLocalizations.of(context).encryptedSuffix
            : '';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context).exportedTo(hint)),
          ),
        );
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context).exportFailed)),
        );
      }
    }
  }

  /// 从备份字节导入：zip（新版精简备份）直接解包导入；否则按文本处理，加密的先
  /// 解密再导入。返回是否成功导入；用户取消解密返回 false。空/坏文件抛
  /// FormatException 由调用方提示。
  Future<bool> _importBackupBytes(
    BuildContext context,
    VeriFinController controller,
    List<int> bytes,
  ) async {
    if (bytes.isEmpty) {
      throw const FormatException('空备份文件');
    }
    if (looksLikeZipBytes(bytes)) {
      controller.importBackupBytes(bytes);
      return true;
    }
    var text = utf8.decode(bytes);
    if (text.trim().isEmpty) {
      throw const FormatException('空备份文件');
    }
    if (isEncryptedBackup(text)) {
      if (!context.mounted) {
        return false;
      }
      final decrypted = await _decryptForImport(context, controller, text);
      if (decrypted == null) {
        return false;
      }
      text = decrypted;
    }
    controller.importDataJson(text);
    return true;
  }

  /// 处理加密备份的解密：先尝试已保存口令，失败或未设置则弹窗要求输入，
  /// 输入错误可重试。返回明文；用户取消返回 null。
  Future<String?> _decryptForImport(
    BuildContext context,
    VeriFinController controller,
    String content,
  ) async {
    final saved = controller.backupPassphrase;
    if (saved.isNotEmpty) {
      try {
        return await decryptBackup(content, saved);
      } on BackupCryptoException {
        // 已保存口令不匹配（可能来自其他设备/旧口令），改为手动输入。
      }
    }
    var errorText = '';
    while (true) {
      if (!context.mounted) {
        return null;
      }
      final passphrase = await _promptPassphrase(
        context,
        title: AppLocalizations.of(context).enterBackupKeyTitle,
        message: AppLocalizations.of(context).enterBackupKeyMessage,
        errorText: errorText,
      );
      if (passphrase == null) {
        return null;
      }
      try {
        return await decryptBackup(content, passphrase);
      } on BackupCryptoException catch (error) {
        errorText = error.message;
      }
    }
  }

  Future<String?> _promptPassphrase(
    BuildContext context, {
    required String title,
    required String message,
    String errorText = '',
  }) {
    return showDialog<String>(
      context: context,
      builder: (context) => _PassphrasePromptDialog(
        title: title,
        message: message,
        errorText: errorText,
      ),
    );
  }

  Future<void> _editBackupPassphrase(
    BuildContext context,
    VeriFinController controller,
  ) async {
    final isChange = controller.backupEncryptionEnabled;
    final result = await showDialog<String>(
      context: context,
      builder: (context) => _SetPassphraseDialog(isChange: isChange),
    );
    if (result != null && result.isNotEmpty) {
      controller.setBackupPassphrase(result);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context).keySet)),
        );
      }
    }
  }

  Future<void> _confirmClearPassphrase(
    BuildContext context,
    VeriFinController controller,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(AppLocalizations.of(context).clearKeyTitle),
        content: Text(AppLocalizations.of(context).clearKeyMessage),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(AppLocalizations.of(context).commonCancel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: veriExpense),
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(AppLocalizations.of(context).clearLabel),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      controller.clearBackupPassphrase();
    }
  }

  Future<void> _editWebdav(
    BuildContext context,
    VeriFinController controller,
  ) async {
    final existing = controller.webdavConfig;
    final saved = await showDialog<WebdavConfig>(
      context: context,
      builder: (context) => _WebdavEditDialog(existing: existing),
    );
    if (saved != null && saved.isConfigured) {
      if (!context.mounted) return;
      // http 发往公网主机会明文暴露账号密码，保存前提醒确认。
      if (!await confirmCleartextIfRisky(context, saved.url)) return;
      controller.setWebdavConfig(saved);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context).webdavSaved)),
        );
      }
    }
  }

  Future<void> _uploadToWebdav(
    BuildContext context,
    VeriFinController controller,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final l10n = AppLocalizations.of(context);
    messenger.showSnackBar(
      SnackBar(content: Text(AppLocalizations.of(context).uploadingWebdav)),
    );
    try {
      final now = DateTime.now();
      final prepared = await BackupService.prepare(
        json: controller.exportDataJson(),
        passphrase: controller.backupPassphrase,
        now: now,
        auto: false,
      );
      await webdavUpload(
        controller.webdavConfig,
        prepared.filename,
        prepared.bytes,
      );
      controller.recordBackupTime(now);
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.uploadedFile(prepared.filename))),
      );
    } catch (error) {
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.uploadFailed('$error'))),
      );
    }
  }

  Future<void> _restoreFromWebdav(
    BuildContext context,
    VeriFinController controller,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final l10n = AppLocalizations.of(context);
    List<WebdavRemoteFile> files;
    try {
      files = await webdavList(controller.webdavConfig);
    } catch (error) {
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.readFailed('$error'))),
      );
      return;
    }
    if (!context.mounted) {
      return;
    }
    if (files.isEmpty) {
      messenger.showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context).noWebdavBackups)),
      );
      return;
    }
    files.sort((a, b) {
      final at = a.modifiedAt;
      final bt = b.modifiedAt;
      if (at == null || bt == null) {
        return b.name.compareTo(a.name);
      }
      return bt.compareTo(at);
    });
    final chosen = await showModalBottomSheet<WebdavRemoteFile>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(14, 0, 14, 16),
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                AppLocalizations.of(context).chooseRestoreBackup,
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
              ),
            ),
            for (final file in files)
              ListTile(
                leading: const Icon(Icons.insert_drive_file_outlined),
                title: Text(file.name),
                subtitle: file.modifiedAt == null
                    ? null
                    : Text(file.modifiedAt!.toLocal().toString()),
                onTap: () => Navigator.of(context).pop(file),
              ),
          ],
        ),
      ),
    );
    if (chosen == null || !context.mounted) {
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(AppLocalizations.of(context).restoreFromThisTitle),
        content: Text(
          AppLocalizations.of(context).restoreFromThisMessage(chosen.name),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(AppLocalizations.of(context).commonCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(AppLocalizations.of(context).restoreLabel),
          ),
        ],
      ),
    );
    if (confirmed != true) {
      return;
    }
    try {
      final bytes = await webdavDownload(controller.webdavConfig, chosen.href);
      if (!context.mounted) {
        return;
      }
      final imported = await _importBackupBytes(context, controller, bytes);
      if (imported && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context).restoredFromWebdav),
          ),
        );
      }
    } on FormatException {
      messenger.showSnackBar(SnackBar(content: Text(l10n.restoreFailedFormat)));
    } catch (error) {
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.restoreFailedError('$error'))),
      );
    }
  }

  Future<void> _confirmClearWebdav(
    BuildContext context,
    VeriFinController controller,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(AppLocalizations.of(context).clearWebdavTitle),
        content: Text(AppLocalizations.of(context).clearWebdavMessage),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(AppLocalizations.of(context).commonCancel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: veriExpense),
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(AppLocalizations.of(context).clearLabel),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      controller.clearWebdavConfig();
    }
  }

  Future<void> _downloadCsvTemplate(BuildContext context) async {
    try {
      final saved = await downloadTextFile(
        filename: 'verifin-import-template.csv',
        content: transactionCsvTemplate(),
        mimeType: 'text/csv',
      );
      if (saved && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context).csvTemplateSaved),
          ),
        );
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context).csvTemplateSaveFailed),
          ),
        );
      }
    }
  }

  /// 平台优先导入流程：先选账单来源，再看导出引导，最后选文件解析。
  Future<void> _importFromPlatform(
    BuildContext context,
    VeriFinController controller,
  ) async {
    final platform = await _pickImportPlatform(context);
    if (platform == null || !context.mounted) {
      return;
    }
    final proceed = await _showBillImportGuide(context, platform);
    if (proceed != true || !context.mounted) {
      return;
    }
    await _runPlatformImport(context, controller, platform);
  }

  Future<ImportPlatform?> _pickImportPlatform(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final items = <_PlatformOption>[
      _PlatformOption(
        ImportPlatform.alipay,
        Icons.account_balance_wallet_outlined,
        l10n.platformAlipay,
        l10n.platformAlipayHint,
        assetPath: 'assets/import_icons/alipay.png',
      ),
      _PlatformOption(
        ImportPlatform.wechat,
        Icons.chat_bubble_outline,
        l10n.platformWechat,
        l10n.platformWechatHint,
        assetPath: 'assets/import_icons/wechat.png',
      ),
      _PlatformOption(
        ImportPlatform.mint,
        Icons.eco_outlined,
        l10n.platformMint,
        l10n.platformMintHint,
        assetPath: 'assets/import_icons/mint.png',
      ),
      _PlatformOption(
        ImportPlatform.yimuBill,
        Icons.menu_book_outlined,
        l10n.platformYimuBill,
        l10n.platformYimuBillHint,
        assetPath: 'assets/import_icons/yimu.png',
      ),
      _PlatformOption(
        ImportPlatform.yimuTransfer,
        Icons.swap_horiz_outlined,
        l10n.platformYimuTransfer,
        l10n.platformYimuTransferHint,
        assetPath: 'assets/import_icons/yimu.png',
      ),
      _PlatformOption(
        ImportPlatform.genericCsv,
        Icons.table_chart_outlined,
        l10n.platformGenericCsv,
        l10n.platformGenericCsvHint,
      ),
    ];
    return showModalBottomSheet<ImportPlatform>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 2),
              child: Text(
                l10n.selectBillSource,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Text(
                l10n.selectBillSourceHint,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
            for (final item in items)
              InkWell(
                onTap: () => Navigator.of(context).pop(item.platform),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 12,
                  ),
                  // 图标与「标题+副标题」整体垂直居中（Row 默认 center 对齐），
                  // 不依赖 ListTile 带副标题时的内部对齐规则。
                  child: Row(
                    children: <Widget>[
                      _platformLeading(item),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              item.title,
                              style: Theme.of(context).textTheme.bodyLarge,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              item.subtitle,
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onSurfaceVariant,
                                  ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  /// 平台选项前的图标：有品牌图标用圆角 PNG，否则回退矢量图标；统一占 32×32 方框，
  /// 各行文字左边缘对齐。
  Widget _platformLeading(_PlatformOption item) {
    final Widget child = item.assetPath == null
        ? Icon(item.icon, size: 28)
        : ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.asset(
              item.assetPath!,
              width: 32,
              height: 32,
              fit: BoxFit.cover,
              filterQuality: FilterQuality.medium,
            ),
          );
    return SizedBox(width: 32, height: 32, child: Center(child: child));
  }

  String _platformLabel(BuildContext context, ImportPlatform platform) {
    final l10n = AppLocalizations.of(context);
    return switch (platform) {
      ImportPlatform.alipay => l10n.platformAlipay,
      ImportPlatform.wechat => l10n.platformWechat,
      ImportPlatform.mint => l10n.platformMint,
      ImportPlatform.yimuBill => l10n.platformYimuBill,
      ImportPlatform.yimuTransfer => l10n.platformYimuTransfer,
      ImportPlatform.genericCsv => l10n.platformGenericCsv,
    };
  }

  String _platformGuide(BuildContext context, ImportPlatform platform) {
    final l10n = AppLocalizations.of(context);
    return switch (platform) {
      ImportPlatform.alipay => l10n.alipayImportGuide,
      ImportPlatform.wechat => l10n.wechatImportGuide,
      ImportPlatform.mint => l10n.mintImportGuide,
      ImportPlatform.yimuBill => l10n.yimuBillImportGuide,
      ImportPlatform.yimuTransfer => l10n.yimuTransferImportGuide,
      ImportPlatform.genericCsv => l10n.genericCsvImportGuide,
    };
  }

  Future<bool?> _showBillImportGuide(
    BuildContext context,
    ImportPlatform platform,
  ) {
    final l10n = AppLocalizations.of(context);
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          l10n.billImportGuideTitle(_platformLabel(context, platform)),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(_platformGuide(context, platform)),
              const SizedBox(height: 12),
              Text(
                l10n.billImportCommonNote,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.commonCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.chooseFile),
          ),
        ],
      ),
    );
  }

  Future<void> _runPlatformImport(
    BuildContext context,
    VeriFinController controller,
    ImportPlatform platform,
  ) async {
    try {
      final bytes = await pickImportBytes(
        extensions: platform.fileExtensions,
        label: _platformLabel(context, platform),
      );
      if (bytes == null) {
        return;
      }
      if (bytes.isEmpty) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(AppLocalizations.of(context).fileEmptyError),
            ),
          );
        }
        return;
      }
      // 先只解析、不落库，进入导入预览页让用户核对 / 排除 / 编辑后再确认。
      final plan = controller.parsePlatformImport(platform, bytes);
      if (!context.mounted) {
        return;
      }
      if (plan.importedCount == 0) {
        // 无可导入交易：有错误行则列出，否则提示空。
        if (plan.errorCount > 0) {
          await _showImportResult(context, plan);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                AppLocalizations.of(context).importPreviewNothingToImport,
              ),
            ),
          );
        }
        return;
      }
      final result = await Navigator.of(context).push<ImportPreviewResult>(
        MaterialPageRoute<ImportPreviewResult>(
          builder: (_) => ImportPreviewPage(
            plan: plan,
            sourceLabel: _platformLabel(context, platform),
          ),
        ),
      );
      if (result == null || result.entries.isEmpty || !context.mounted) {
        return;
      }
      controller.applyImportEntries(
        entries: result.entries,
        candidateAccounts: result.candidateAccounts,
        candidateCategories: result.candidateCategories,
      );
      if (!context.mounted) {
        return;
      }
      final suffix = plan.errorCount > 0
          ? AppLocalizations.of(context).skippedRows(plan.errorCount)
          : '';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${AppLocalizations.of(context).importedEntries(result.entries.length)}$suffix',
          ),
        ),
      );
    } on FormatException catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              AppLocalizations.of(
                context,
              ).importFailedWithMessage(error.message),
            ),
          ),
        );
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context).importFailedCheckFile),
          ),
        );
      }
    }
  }

  Future<void> _showImportResult(BuildContext context, ImportPlan plan) {
    final lines = plan.errors
        .take(10)
        .map((e) => AppLocalizations.of(context).lineError(e.line, e.message))
        .join('\n');
    final more = plan.errorCount > 10
        ? AppLocalizations.of(context).moreLines(plan.errorCount - 10)
        : '';
    return showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          AppLocalizations.of(context).importDoneTitle(plan.importedCount),
        ),
        content: SingleChildScrollView(
          child: Text(
            plan.errorCount == 0
                ? AppLocalizations.of(context).allImported
                : AppLocalizations.of(context).skippedFollowing('$lines$more'),
          ),
        ),
        actions: <Widget>[
          FilledButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(AppLocalizations.of(context).gotIt),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmImport(
    BuildContext context,
    VeriFinController controller,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(AppLocalizations.of(context).importLocalTitle),
        content: Text(AppLocalizations.of(context).importLocalMessage),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(AppLocalizations.of(context).commonCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(AppLocalizations.of(context).chooseFile),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) {
      return;
    }
    final fileTypeLabel = AppLocalizations.of(context).backupFileTypeLabel;

    try {
      final bytes = await pickBackupBytes(label: fileTypeLabel);
      if (bytes == null) {
        return;
      }
      if (!context.mounted) {
        return;
      }
      final imported = await _importBackupBytes(context, controller, bytes);
      if (imported && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context).importedLocal)),
        );
      }
    } on FormatException {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context).importFailedFormat),
          ),
        );
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context).importFailedCheckFile),
          ),
        );
      }
    }
  }

  Future<void> _confirmReset(
    BuildContext context,
    VeriFinController controller,
  ) async {
    final firstConfirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(AppLocalizations.of(context).resetAllTitle),
        content: Text(AppLocalizations.of(context).resetAllMessage),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(AppLocalizations.of(context).commonCancel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: veriExpense),
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(AppLocalizations.of(context).continueLabel),
          ),
        ],
      ),
    );
    if (firstConfirmed != true || !context.mounted) {
      return;
    }

    final secondConfirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(AppLocalizations.of(context).resetConfirmTitle),
        content: Text(AppLocalizations.of(context).resetConfirmMessage),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(AppLocalizations.of(context).commonCancel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: veriExpense),
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(AppLocalizations.of(context).resetConfirmAction),
          ),
        ],
      ),
    );
    if (secondConfirmed == true) {
      controller.resetAllData();
      if (context.mounted) {
        Navigator.of(context).pop();
      }
    }
  }
}

class _PlatformOption {
  const _PlatformOption(
    this.platform,
    this.icon,
    this.title,
    this.subtitle, {
    this.assetPath,
  });

  final ImportPlatform platform;

  /// 无品牌图标时的回退矢量图标（如「其他 CSV」）。
  final IconData icon;
  final String title;
  final String subtitle;

  /// 软件品牌图标资源路径；为 null 时回退到 [icon]。
  /// 注意：这是记账/支付软件的品牌图标，与账户图标（`assets/account_icons/`）不同。
  final String? assetPath;
}

/// 备份进行中的不可关闭转圈弹窗。
class _BackupProgressDialog extends StatelessWidget {
  const _BackupProgressDialog({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      content: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          const SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(strokeWidth: 2.4),
          ),
          const SizedBox(width: 16),
          Flexible(child: Text(label)),
        ],
      ),
    );
  }
}

/// 输入解密口令的对话框。用 StatefulWidget 在 [State.dispose]（退出动画结束后）
/// 释放控制器，避免退出动画期间 TextField 用到已释放控制器。
class _PassphrasePromptDialog extends StatefulWidget {
  const _PassphrasePromptDialog({
    required this.title,
    required this.message,
    required this.errorText,
  });

  final String title;
  final String message;
  final String errorText;

  @override
  State<_PassphrasePromptDialog> createState() =>
      _PassphrasePromptDialogState();
}

class _PassphrasePromptDialogState extends State<_PassphrasePromptDialog> {
  final TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(widget.title),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(widget.message),
          const SizedBox(height: 12),
          TextField(
            controller: _controller,
            autofocus: true,
            obscureText: true,
            decoration: InputDecoration(
              labelText: l10n.backupKeyLabel,
              errorText: widget.errorText.isEmpty ? null : widget.errorText,
            ),
          ),
        ],
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.commonCancel),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(_controller.text),
          child: Text(l10n.okLabel),
        ),
      ],
    );
  }
}

/// 设置 / 修改加密口令的对话框（两次输入 + 校验）。控制器由 State 管理并释放。
class _SetPassphraseDialog extends StatefulWidget {
  const _SetPassphraseDialog({required this.isChange});

  final bool isChange;

  @override
  State<_SetPassphraseDialog> createState() => _SetPassphraseDialogState();
}

class _SetPassphraseDialogState extends State<_SetPassphraseDialog> {
  final TextEditingController _keyController = TextEditingController();
  final TextEditingController _confirmController = TextEditingController();
  String? _errorText;

  @override
  void dispose() {
    _keyController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(widget.isChange ? l10n.changeKeyTitle : l10n.setKeyTitle),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(l10n.setKeyMessage),
          const SizedBox(height: 12),
          TextField(
            controller: _keyController,
            autofocus: true,
            obscureText: true,
            decoration: InputDecoration(labelText: l10n.keyMinLabel),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _confirmController,
            obscureText: true,
            decoration: InputDecoration(
              labelText: l10n.keyRepeatLabel,
              errorText: _errorText,
            ),
          ),
        ],
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.commonCancel),
        ),
        FilledButton(
          onPressed: () {
            final key = _keyController.text;
            if (key.length < 4) {
              setState(() => _errorText = l10n.keyTooShort);
              return;
            }
            if (key != _confirmController.text) {
              setState(() => _errorText = l10n.keyMismatch);
              return;
            }
            Navigator.of(context).pop(key);
          },
          child: Text(l10n.commonSave),
        ),
      ],
    );
  }
}

/// 编辑 WebDAV 配置的对话框（含连通性测试）。控制器由 State 管理并释放。
class _WebdavEditDialog extends StatefulWidget {
  const _WebdavEditDialog({required this.existing});

  final WebdavConfig existing;

  @override
  State<_WebdavEditDialog> createState() => _WebdavEditDialogState();
}

class _WebdavEditDialogState extends State<_WebdavEditDialog> {
  late final TextEditingController _urlController = TextEditingController(
    text: widget.existing.url,
  );
  late final TextEditingController _userController = TextEditingController(
    text: widget.existing.username,
  );
  late final TextEditingController _passController = TextEditingController(
    text: widget.existing.password,
  );
  String? _statusText;
  bool _testing = false;

  WebdavConfig _current() => WebdavConfig(
    url: _urlController.text.trim(),
    username: _userController.text.trim(),
    password: _passController.text,
    autoUpload: widget.existing.autoUpload,
  );

  @override
  void dispose() {
    _urlController.dispose();
    _userController.dispose();
    _passController.dispose();
    super.dispose();
  }

  Future<void> _test() async {
    final l10n = AppLocalizations.of(context);
    setState(() {
      _testing = true;
      _statusText = l10n.testingConnection;
    });
    try {
      await webdavTestConnection(_current());
      if (mounted) setState(() => _statusText = l10n.connectionOk);
    } catch (error) {
      if (mounted) {
        setState(() => _statusText = l10n.connectionFailed('$error'));
      }
    } finally {
      if (mounted) setState(() => _testing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(l10n.webdavServer),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            TextField(
              controller: _urlController,
              autofocus: true,
              keyboardType: TextInputType.url,
              decoration: InputDecoration(
                labelText: l10n.webdavUrlLabel,
                hintText: 'https://dav.example.com/verifin/',
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _userController,
              decoration: InputDecoration(labelText: l10n.webdavUserLabel),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _passController,
              obscureText: true,
              decoration: InputDecoration(labelText: l10n.webdavPassLabel),
            ),
            if (_statusText != null) ...<Widget>[
              const SizedBox(height: 10),
              Text(_statusText!, style: Theme.of(context).textTheme.bodySmall),
            ],
          ],
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.commonCancel),
        ),
        TextButton(
          onPressed: _testing || _urlController.text.trim().isEmpty
              ? null
              : _test,
          child: Text(l10n.testConnection),
        ),
        FilledButton(
          onPressed: () {
            if (_urlController.text.trim().isEmpty) {
              setState(() => _statusText = l10n.fillServerUrl);
              return;
            }
            Navigator.of(context).pop(_current());
          },
          child: Text(l10n.commonSave),
        ),
      ],
    );
  }
}
