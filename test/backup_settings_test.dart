import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:verifin/app/backup/backup_archive.dart';
import 'package:verifin/app/backup/backup_service.dart';
import 'package:verifin/app/backup/backup_settings.dart';
import 'package:verifin/app/backup/backup_storage.dart';
import 'package:verifin/app/models.dart';
import 'package:verifin/app/veri_fin_scope.dart';
import 'package:verifin/local_storage/local_storage.dart';
import 'package:verifin/pages/data_management_page.dart';

import 'support/test_harness.dart';

void main() {
  useTestDatabases();

  group('BackupSettings 序列化与频率判断', () {
    test('encode/decode 往返保持字段', () {
      const settings = BackupSettings(
        directoryUri: 'content://tree/abc',
        directoryLabel: 'Backups',
        frequency: BackupFrequency.everyNHours,
        intervalHours: 6,
        retention: 5,
      );
      final restored = BackupSettings.decode(settings.encode());
      expect(restored.directoryUri, 'content://tree/abc');
      expect(restored.directoryLabel, 'Backups');
      expect(restored.frequency, BackupFrequency.everyNHours);
      expect(restored.intervalHours, 6);
      expect(restored.retention, 5);
    });

    test('损坏或空配置退回默认', () {
      expect(BackupSettings.decode(null).frequency, BackupFrequency.manual);
      expect(BackupSettings.decode('').hasDirectory, isFalse);
      expect(BackupSettings.decode('not json}').retention, 10);
    });

    test('没有目录时永不自动备份', () {
      const settings = BackupSettings(frequency: BackupFrequency.onOpen);
      expect(settings.shouldAutoBackup(DateTime(2026, 7, 4)), isFalse);
    });

    test('onOpen 仅在打开时触发，onEntry 仅在记账后触发', () {
      const open = BackupSettings(
        directoryUri: 'x',
        frequency: BackupFrequency.onOpen,
      );
      expect(open.shouldAutoBackup(DateTime(2026), afterEntry: false), isTrue);
      expect(open.shouldAutoBackup(DateTime(2026), afterEntry: true), isFalse);

      const entry = BackupSettings(
        directoryUri: 'x',
        frequency: BackupFrequency.onEntry,
      );
      expect(entry.shouldAutoBackup(DateTime(2026), afterEntry: true), isTrue);
      expect(
        entry.shouldAutoBackup(DateTime(2026), afterEntry: false),
        isFalse,
      );
    });

    test('everyNHours 依据间隔判断是否到期', () {
      final base = DateTime(2026, 7, 4, 8);
      final settings = BackupSettings(
        directoryUri: 'x',
        frequency: BackupFrequency.everyNHours,
        intervalHours: 6,
        lastBackupAt: base,
      );
      expect(
        settings.shouldAutoBackup(base.add(const Duration(hours: 5))),
        isFalse,
      );
      expect(
        settings.shouldAutoBackup(base.add(const Duration(hours: 6))),
        isTrue,
      );
      // 从未备份过则立即到期。
      const never = BackupSettings(
        directoryUri: 'x',
        frequency: BackupFrequency.everyNHours,
        intervalHours: 6,
      );
      expect(never.shouldAutoBackup(base), isTrue);
    });
  });

  group('自动备份文件命名与保留', () {
    test('手动与自动文件名前缀区分（未加密 zip / 加密 json）', () {
      final now = DateTime(2026, 7, 4, 9, 8, 7);
      // 默认未加密为 .zip。
      expect(
        BackupService.manualBackupFilename(now),
        'verifin-backup-20260704-090807.zip',
      );
      expect(
        BackupService.autoBackupFilename(now),
        'verifin-auto-20260704-090807.zip',
      );
      // 加密备份沿用文本信封 .json。
      expect(
        BackupService.manualBackupFilename(now, 'json'),
        'verifin-backup-20260704-090807.json',
      );
      expect(
        BackupService.autoBackupFilename(now, 'json'),
        'verifin-auto-20260704-090807.json',
      );
    });

    test('保留最近 N 份自动备份，手动备份不参与清理', () {
      List<BackupFileInfo> file(String name, int day) => <BackupFileInfo>[
        BackupFileInfo(
          uri: name,
          name: name,
          modifiedAt: DateTime(2026, 7, day),
          sizeBytes: 10,
        ),
      ];
      final files = <BackupFileInfo>[
        ...file('verifin-auto-a.json', 1),
        ...file('verifin-auto-b.json', 2),
        ...file('verifin-auto-c.json', 3),
        ...file('verifin-backup-manual.json', 4),
      ];
      final toPrune = autoBackupsToPrune(files, 2);
      expect(toPrune.map((f) => f.name), <String>['verifin-auto-a.json']);
    });

    test('份数未超过保留数则不清理', () {
      final files = <BackupFileInfo>[
        BackupFileInfo(
          uri: 'verifin-auto-a.json',
          name: 'verifin-auto-a.json',
          modifiedAt: DateTime(2026, 7, 1),
          sizeBytes: 1,
        ),
      ];
      expect(autoBackupsToPrune(files, 10), isEmpty);
    });
  });

  group('控制器持久化备份设置', () {
    test('设置目录/频率/保留后重启仍在', () async {
      final store = LocalKeyValueStore();
      final controller = await makeController(store);
      controller.setBackupDirectory('content://tree/xyz', '备份夹');
      controller.setBackupFrequency(BackupFrequency.everyNHours);
      controller.setBackupIntervalHours(12);
      controller.setBackupRetention(7);
      final now = DateTime(2026, 7, 4, 10);
      controller.recordBackupTime(now);

      final reloaded = await makeController(store);
      final settings = reloaded.backupSettings;
      expect(settings.directoryUri, 'content://tree/xyz');
      expect(settings.directoryLabel, '备份夹');
      expect(settings.frequency, BackupFrequency.everyNHours);
      expect(settings.intervalHours, 12);
      expect(settings.retention, 7);
      expect(settings.lastBackupAt, now);
    });

    test('清除目录会同时关闭自动备份', () async {
      final controller = await makeController();
      controller.setBackupDirectory('u', 'l');
      controller.setBackupFrequency(BackupFrequency.onOpen);
      controller.clearBackupDirectory();
      expect(controller.backupSettings.hasDirectory, isFalse);
      expect(controller.backupSettings.frequency, BackupFrequency.manual);
    });

    testWidgets('数据管理页只在明确保存后提交备份频率', (tester) async {
      await tester.binding.setSurfaceSize(const Size(460, 1800));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final controller = await makeController();
      addTearDown(controller.dispose);
      controller.setBackupDirectory('content://tree/backups', '备份目录');

      await tester.pumpWidget(
        VeriFinScope(
          controller: controller,
          child: zhMaterialApp(home: const DataManagementPage()),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('备份频率'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('每次打开应用'));
      await tester.pumpAndSettle();

      expect(controller.backupSettings.frequency, BackupFrequency.manual);
      await tester.tap(find.byTooltip('保存'));
      await tester.pumpAndSettle();
      expect(controller.backupSettings.frequency, BackupFrequency.onOpen);
    });
  });

  group('zip 备份写入目录并读回（桌面 dart:io 路径端到端）', () {
    test('未加密写入为 .zip，读回是 zip，可导入且附件还原', () async {
      final dir = await Directory.systemTemp.createTemp('verifin_backup');
      try {
        final source = await makeController();
        final account = Account(
          id: 'acc-e2e',
          bookId: source.activeBook.id,
          name: '现金账户',
          type: AccountType.cash,
          groupId: null,
          initialBalance: 0,
          iconCode: 'wallet',
          note: '',
          includeInAssets: true,
          hidden: false,
        );
        source
          ..addAccount(account)
          ..addEntry(
            LedgerEntry(
              id: 'e-e2e',
              bookId: source.activeBook.id,
              type: EntryType.expense,
              amount: 15,
              categoryId: 'dining',
              accountId: account.id,
              note: '带票据',
              occurredAt: DateTime(2026, 7, 4, 12),
            ),
          );
        final dataUrl =
            'data:image/jpeg;base64,${base64Encode(List<int>.generate(1024, (i) => i % 256))}';
        source.addAttachment('e-e2e', dataUrl);

        final result = await BackupService.writeManualBackup(
          settings: BackupSettings(directoryUri: dir.path),
          content: source.exportDataJson(),
          now: DateTime(2026, 7, 4, 9, 8, 7),
        );
        expect(result.filename.endsWith('.zip'), isTrue);

        final bytes = await readBackupBytesFile(result.fileUri!);
        expect(bytes, isNotNull);
        expect(looksLikeZipBytes(bytes!), isTrue);

        final target = await makeController();
        final decoded =
            BackupService.decodeBackupBytes(bytes) as PlainBackupJson;
        target.importDataJson(decoded.json);
        expect(target.entries.single.note, '带票据');
        expect(target.attachmentsForEntry('e-e2e').single.dataUrl, dataUrl);

        source.dispose();
        target.dispose();
      } finally {
        await dir.delete(recursive: true);
      }
    });
  });
}
