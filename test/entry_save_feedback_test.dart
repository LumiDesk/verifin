import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:verifin/app/app_theme.dart';
import 'package:verifin/app/entry_save_feedback.dart';
import 'package:verifin/app/models.dart';
import 'package:verifin/app/veri_fin_controller.dart';
import 'package:verifin/app/veri_fin_scope.dart';
import 'package:verifin/l10n/app_localizations.dart';
import 'package:verifin/pages/transaction_detail_page.dart';

import 'support/test_harness.dart';

void main() {
  useTestDatabases();

  test('交易保存校验错误码映射到对应文案', () {
    final zh = lookupAppLocalizations(const Locale('zh'));
    expect(
      entrySaveValidationMessage(zh, EntryValidationCode.staleDraft),
      zh.entrySaveStaleDraft,
    );
    expect(
      entrySaveValidationMessage(zh, EntryValidationCode.invalidAmounts),
      zh.entrySaveValidationFailed,
    );
    expect(
      entrySaveValidationMessage(zh, EntryValidationCode.invalidRefund),
      zh.entrySaveInvalidRefund,
    );
    expect(
      entrySaveValidationMessage(zh, EntryValidationCode.refundExceedsExpense),
      zh.entrySaveRefundExceedsExpense,
    );
    expect(
      entrySaveValidationMessage(zh, EntryValidationCode.invalidAttachments),
      zh.entrySaveInvalidAttachments,
    );
    expect(
      entrySaveValidationMessage(zh, EntryValidationCode.invalidRememberedRate),
      zh.entrySaveInvalidRememberedRate,
    );
    expect(
      entrySaveValidationMessage(zh, EntryValidationCode.categoryOutOfScope),
      zh.entrySaveInvalidScope,
    );
    expect(
      entrySaveValidationMessage(zh, EntryValidationCode.tagOutOfScope),
      zh.entrySaveInvalidScope,
    );

    final en = lookupAppLocalizations(const Locale('en'));
    expect(
      entrySaveValidationMessage(en, EntryValidationCode.refundExceedsExpense),
      en.entrySaveRefundExceedsExpense,
    );
  });

  testWidgets('交易已删除时保存显示过期提示', (WidgetTester tester) async {
    final controller = await makeController();
    final bookId = controller.activeBook.id;
    controller.addEntry(
      LedgerEntry(
        id: 'stale-entry',
        bookId: bookId,
        type: EntryType.expense,
        amount: 10,
        categoryId: 'dining',
        accountId: '',
        note: '',
        occurredAt: DateTime(2026, 7, 4),
      ),
    );

    await tester.binding.setSurfaceSize(const Size(460, 1600));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      VeriFinScope(
        controller: controller,
        child: zhMaterialApp(
          theme: buildVeriFinTheme(Brightness.light),
          home: const TransactionDetailPage(entryId: 'stale-entry'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // 制造一次草稿修改并触发自动保存；再从别处删除交易，然后修改另一字段。
    final reimbursableSwitch = find.byType(Switch).first;
    await tester.ensureVisible(reimbursableSwitch);
    await tester.pumpAndSettle();
    await tester.tap(reimbursableSwitch);
    await tester.pumpAndSettle();
    await controller.deleteEntry('stale-entry');
    await tester.pumpAndSettle();

    final excludedSwitch = find.byType(Switch).at(1);
    await tester.ensureVisible(excludedSwitch);
    await tester.pumpAndSettle();
    await tester.tap(excludedSwitch);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('保存失败，请重试'), findsOneWidget);
  });
}
