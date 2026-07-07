import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../app/ai/ai_client.dart';
import '../app/ai/ai_entry_parser.dart';
import '../app/models.dart';
import '../app/platform_bridge.dart';
import '../app/screenshot_recognizer.dart';
import '../app/veri_fin_controller.dart';
import '../app/veri_fin_scope.dart';
import '../l10n/app_localizations.dart';
import 'ai_settings_page.dart';
import 'entry_detail_page.dart';

/// 截图识账 / 外部采集记账：把「用户主动送进来的内容」（分享的截图、分享的账单
/// 文本、自动化工具经意图接口送入的文本）识别成交易草稿，交记账页确认后落账。
/// 应用本体不监听任何通知或屏幕，一切入口都由用户（或用户自配的自动化工具）触发。

/// AI 未配置时弹引导（去 AI 设置页），返回是否已配置可继续。
Future<bool> ensureAiConfigured(BuildContext context) async {
  final controller = VeriFinScope.of(context);
  if (controller.aiSettings.isConfigured) {
    return true;
  }
  final l10n = AppLocalizations.of(context);
  final goToSettings = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(l10n.aiEntryNotConfiguredTitle),
      content: Text(l10n.aiEntryNotConfiguredBody),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: Text(l10n.commonCancel),
        ),
        FilledButton(
          onPressed: () => Navigator.of(dialogContext).pop(true),
          child: Text(l10n.aiEntryGoToSettings),
        ),
      ],
    ),
  );
  if (goToSettings == true && context.mounted) {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(builder: (_) => const AiSettingsPage()),
    );
  }
  return false;
}

/// 从 controller 组装喂给 AI 的账本上下文（分类/账户清单、当前时刻、账本）。
AiEntryContext buildAiEntryContext(VeriFinController controller) {
  List<AiOption> optionsFor(EntryType type) => controller
      .categoriesForType(type)
      .map(
        (category) => AiOption(
          id: category.id,
          label: controller.categoryPathLabel(category.id),
        ),
      )
      .toList();
  final accounts = controller.accounts
      .where((account) => !account.hidden)
      .map((account) => AiOption(id: account.id, label: account.name))
      .toList();
  return AiEntryContext(
    expenseCategories: optionsFor(EntryType.expense),
    incomeCategories: optionsFor(EntryType.income),
    accounts: accounts,
    today: DateTime.now(),
    bookId: controller.activeBook.id,
  );
}

/// 原生侧有待处理的分享/采集内容时调用（开屏冷启动主动拉取、运行中被通知）。
/// 图片优先于文本；取走即清，无内容则静默返回。
Future<void> startSharedCaptureEntry(BuildContext context) async {
  final imageBytes = await AppPlatformBridge.consumeCaptureImage();
  if (!context.mounted) {
    return;
  }
  if (imageBytes != null && imageBytes.isNotEmpty) {
    await startScreenshotEntry(context, sharedImageBytes: imageBytes);
    return;
  }
  final text = await AppPlatformBridge.consumeCaptureText();
  if (!context.mounted || text == null || text.trim().isEmpty) {
    return;
  }
  await startCapturedTextEntry(context, text);
}

/// 截图识账：分享进来的图片字节（[sharedImageBytes]）或 App 内从相册选图，
/// 本地 OCR 出文本后交 AI 解析成草稿，push 记账页确认。图片识别完即弃、不留存。
Future<void> startScreenshotEntry(
  BuildContext context, {
  Uint8List? sharedImageBytes,
}) async {
  final l10n = AppLocalizations.of(context);
  if (!screenshotRecognitionSupported) {
    ScaffoldMessenger.maybeOf(
      context,
    )?.showSnackBar(SnackBar(content: Text(l10n.screenshotEntryUnsupported)));
    return;
  }
  if (!await ensureAiConfigured(context) || !context.mounted) {
    return;
  }
  final controller = VeriFinScope.of(context);

  String? imagePath;
  if (sharedImageBytes == null) {
    try {
      imagePath = await pickScreenshotPath();
    } catch (_) {
      // 选择器不可用（测试宿主/异常）按取消处理。
      imagePath = null;
    }
    if (imagePath == null || !context.mounted) {
      return;
    }
  }

  final draft = await _runCaptureParse(context, () async {
    final ocrText = sharedImageBytes != null
        ? await recognizeTextFromBytes(sharedImageBytes)
        : await recognizeTextFromPath(imagePath!);
    if (ocrText.trim().isEmpty) {
      throw _CaptureNoTextException();
    }
    return requestCapturedEntryDraft(
      settings: controller.aiSettings,
      capturedText: ocrText,
      context: buildAiEntryContext(controller),
    );
  });
  if (draft == null || !context.mounted) {
    return;
  }
  await _confirmDraft(context, controller, draft);
}

/// 外部采集文本记账：分享的账单文本或自动化意图送入的原文，AI 解析成草稿确认。
Future<void> startCapturedTextEntry(BuildContext context, String text) async {
  if (!await ensureAiConfigured(context) || !context.mounted) {
    return;
  }
  final controller = VeriFinScope.of(context);
  final draft = await _runCaptureParse(context, () {
    return requestCapturedEntryDraft(
      settings: controller.aiSettings,
      capturedText: text,
      context: buildAiEntryContext(controller),
    );
  });
  if (draft == null || !context.mounted) {
    return;
  }
  await _confirmDraft(context, controller, draft);
}

Future<void> _confirmDraft(
  BuildContext context,
  VeriFinController controller,
  AiEntryDraft draft,
) {
  return Navigator.of(context).push<void>(
    MaterialPageRoute<void>(
      builder: (_) => EntryDetailPage(
        initialAmount: draft.amount,
        // 未识别到账户时，记账页回落到默认付款账户（未设则为「无账户」）。
        initialAccountId: controller.defaultAccountId,
        initialDraft: draft,
      ),
    ),
  );
}

/// 内部信号：图片里没识别到任何文字（与「识别到文字但不是交易」区分提示）。
class _CaptureNoTextException implements Exception {}

/// 带模态加载态执行「识别 + 解析」，失败弹本地化错误提示，成功返回草稿。
Future<AiEntryDraft?> _runCaptureParse(
  BuildContext context,
  Future<AiEntryDraft> Function() task,
) async {
  final l10n = AppLocalizations.of(context);
  final rootNavigator = Navigator.of(context, rootNavigator: true);
  // 识别中禁止返回/点穿，避免用户在等待中重复触发。
  showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => PopScope(
      canPop: false,
      child: AlertDialog(
        content: Row(
          children: <Widget>[
            const SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(strokeWidth: 2.5),
            ),
            const SizedBox(width: 16),
            Expanded(child: Text(l10n.captureEntryRecognizing)),
          ],
        ),
      ),
    ),
  );

  AiEntryDraft? draft;
  String? errorText;
  try {
    draft = await task();
  } on _CaptureNoTextException {
    errorText = l10n.screenshotEntryNoText;
  } on AiEntryException catch (error) {
    errorText = switch (error.error) {
      AiEntryError.emptyResult => l10n.aiEntryNoResult,
      AiEntryError.noAmount => l10n.captureEntryNoTransaction,
    };
  } on AiException catch (error) {
    errorText = aiErrorMessage(l10n, error);
  } on UnsupportedError {
    errorText = l10n.screenshotEntryUnsupported;
  } catch (error) {
    errorText = '$error';
  } finally {
    rootNavigator.pop();
  }

  if (errorText != null && context.mounted) {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.captureEntryFailedTitle),
        content: Text(errorText!),
        actions: <Widget>[
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(l10n.commonConfirm),
          ),
        ],
      ),
    );
  }
  return draft;
}
