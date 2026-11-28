import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../app/ai/ai_capabilities.dart';
import '../app/ai/ai_client.dart';
import '../app/ai/ai_entry_parser.dart';
import '../app/ai/ai_vision_entry.dart';
import '../app/ai/ai_vision_image.dart';
import '../app/common_widgets.dart';
import '../app/models.dart';
import '../app/platform_bridge.dart';
import '../app/veri_fin_controller.dart';
import '../app/veri_fin_scope.dart';
import '../l10n/app_localizations.dart';
import 'ai_settings_page.dart';
import 'entry_detail_page.dart';

/// 截图识账 / 外部采集记账：把「用户主动送进来的内容」（分享的截图、分享的账单
/// 文本、自动化工具经意图接口送入的文本）交给用户自配的 AI 生成交易草稿，
/// 交记账页确认后落账。应用本体不监听任何通知或屏幕。
///
/// 图片路径是一次视觉请求：选图 → 压缩 → `image_url` → 解析 JSON → 记账页，
/// 没有 OCR、没有第二次解析、没有独立页面。

/// AI 未配置时弹引导（去 AI 设置页），返回是否已配置可继续。
Future<bool> ensureAiConfigured(BuildContext context) async {
  final controller = VeriFinScope.of(context);
  if (controller.aiSettings.isConfigured) {
    return true;
  }
  final l10n = AppLocalizations.of(context);
  final goToSettings = await showConfirmDialog(
    context,
    title: l10n.aiEntryNotConfiguredTitle,
    message: l10n.aiEntryNotConfiguredBody,
    confirmLabel: l10n.aiEntryGoToSettings,
  );
  if (goToSettings && context.mounted) {
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
      .map(
        (account) => AiOption(
          id: account.id,
          label: account.name,
          currencyCode: account.currencyCode,
        ),
      )
      .toList();
  return AiEntryContext(
    expenseCategories: optionsFor(EntryType.expense),
    incomeCategories: optionsFor(EntryType.income),
    accounts: accounts,
    today: DateTime.now(),
    bookId: controller.activeBook.id,
    baseCurrencyCode: controller.activeBook.baseCurrencyCode,
  );
}

/// 原生侧有待处理的分享/采集内容时调用（开屏冷启动主动拉取、运行中被通知）。
/// 图片优先于文本；取走即清，无内容则静默返回。
Future<void> startSharedCaptureEntry(BuildContext context) async {
  final imageBytes = await AppCaptureBridge.consumeCaptureImage();
  if (!context.mounted) {
    return;
  }
  if (imageBytes != null && imageBytes.isNotEmpty) {
    // 图片优先时把同一批分享残留的文本消费掉，避免下一次分享误读旧文本。
    await AppCaptureBridge.consumeCaptureText();
    if (!context.mounted) {
      return;
    }
    await startImageEntry(context, sharedImageBytes: imageBytes);
    return;
  }
  final text = await AppCaptureBridge.consumeCaptureText();
  if (!context.mounted || text == null || text.trim().isEmpty) {
    return;
  }
  await startCapturedTextEntry(context, text);
}

/// 图片识账：分享进来的图片字节（[sharedImageBytes]）或 App 内相册选图。
/// 选图后直接发一次视觉请求；成功进记账页，失败走现有错误提示。
Future<void> startImageEntry(
  BuildContext context, {
  Uint8List? sharedImageBytes,
}) async {
  final l10n = AppLocalizations.of(context);
  if (!await ensureAiConfigured(context) || !context.mounted) {
    return;
  }
  final controller = VeriFinScope.of(context);
  final settings = controller.aiSettings;
  final profile = controller.aiCapabilityProfile;
  if (profile != null &&
      profile.matches(settings) &&
      profile.vision == AiVisionCapability.unsupported) {
    await _showVisionUnsupported(context);
    return;
  }

  Uint8List? imageBytes = sharedImageBytes;
  if (imageBytes == null || imageBytes.isEmpty) {
    imageBytes = await pickVisionImage();
    if (imageBytes == null || imageBytes.isEmpty || !context.mounted) {
      return;
    }
  }
  final bytes = imageBytes;

  final draft = await _runCaptureParse(
    context,
    noResultText: l10n.visionEntryNoResult,
    task: () async {
      try {
        return await requestVisionEntryDraft(
          settings: controller.aiSettings,
          imageBytes: bytes,
          context: buildAiEntryContext(controller),
        );
      } on AiException catch (error) {
        if (error.code == AiErrorCode.visionUnsupported) {
          _markVisionUnsupported(controller);
        }
        rethrow;
      }
    },
  );
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
  final draft = await _runCaptureParse(
    context,
    task: () {
      return requestCapturedEntryDraft(
        settings: controller.aiSettings,
        capturedText: text,
        context: buildAiEntryContext(controller),
      );
    },
  );
  if (draft == null || !context.mounted) {
    return;
  }
  await _confirmDraft(context, controller, draft);
}

Future<void> _showVisionUnsupported(BuildContext context) async {
  final l10n = AppLocalizations.of(context);
  final goToSettings = await showConfirmDialog(
    context,
    title: l10n.captureEntryFailedTitle,
    message: l10n.visionEntryUnsupported,
    confirmLabel: l10n.aiEntryGoToSettings,
  );
  if (goToSettings && context.mounted) {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(builder: (_) => const AiSettingsPage()),
    );
  }
}

void _markVisionUnsupported(VeriFinController controller) {
  final settings = controller.aiSettings;
  final current = controller.aiCapabilityProfile;
  controller.setAiCapabilityProfile(
    AiCapabilityProfile.forSettings(
      settings: settings,
      nativeToolCalls: current?.matches(settings) == true
          ? current!.nativeToolCalls
          : AiNativeToolCapability.unknown,
      vision: AiVisionCapability.unsupported,
    ),
  );
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

/// 带模态加载态执行「识别 + 解析」，失败弹本地化错误提示，成功返回草稿。
Future<AiEntryDraft?> _runCaptureParse(
  BuildContext context, {
  String? noResultText,
  required Future<AiEntryDraft> Function() task,
}) async {
  final l10n = AppLocalizations.of(context);
  final rootNavigator = Navigator.of(context, rootNavigator: true);
  // 识别中禁止返回/点穿，避免用户在等待中重复触发。进度弹窗随后由 rootNavigator.pop
  // 关闭，故不 await（fire-and-forget）。
  unawaited(
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
    ),
  );

  AiEntryDraft? draft;
  String? errorText;
  try {
    draft = await task();
  } on AiEntryException catch (error) {
    errorText = switch (error.error) {
      AiEntryError.emptyResult => noResultText ?? l10n.aiEntryNoResult,
      AiEntryError.noAmount => l10n.captureEntryNoTransaction,
    };
  } on VisionImageException catch (error) {
    errorText = switch (error.error) {
      VisionImageError.invalid => l10n.visionEntryImageInvalid,
      VisionImageError.tooLarge => l10n.visionEntryImageTooLarge,
    };
  } on AiException catch (error) {
    errorText = aiErrorMessage(l10n, error);
  } catch (error) {
    errorText = '$error';
  } finally {
    rootNavigator.pop();
  }

  if (errorText != null && context.mounted) {
    await showInfoDialog(
      context: context,
      title: l10n.captureEntryFailedTitle,
      message: errorText,
    );
  }
  return draft;
}
