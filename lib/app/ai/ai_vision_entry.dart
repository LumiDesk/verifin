import 'dart:typed_data';

import 'ai_agent_message.dart';
import 'ai_client.dart';
import 'ai_completion_event.dart';
import 'ai_entry_parser.dart';
import 'ai_error.dart';
import 'ai_settings.dart';
import 'ai_vision_image.dart';

/// 图片识账的补充说明最多带 2000 字；图片本身已占请求体，不再叠过长文本。
const int visionEntryNoteMaxLength = 2000;

/// 构造图片识账的系统提示词：复用文字记账的分类/账户/日期上下文，再追加
/// “从图片中挑出主要交易、忽略余额/优惠等噪音”的规则。
String buildVisionEntryPrompt(AiEntryContext context) {
  final base = buildAiEntryPrompt(context);
  return '''
$base

补充：本次用户输入不是亲手打的一句话，而是一张用户主动选择的账单截图、支付页面或小票照片。图片里可能包含余额、优惠、积分、广告、按钮、导航栏等噪音，请按下面规则提取最主要的一笔交易：
- 金额只取「交易金额/付款金额/收款金额」本身；余额、优惠、积分、红包、手续费上限等其他数字一律忽略。
- 到账、收款、入账、退款、工资、报销 → "income"；付款、消费、支出、扣款 → "expense"；账户间转账、还款、提现 → "transfer"。
- 图片里出现的交易日期与时分优先于当前时间，填入 date 与 time；看不清时间就留空或使用当前时间。
- 对方名称/商户名/备注摘要放进 note，保留图片中的原语言。
- 如果整张图根本不含一笔交易（如聊天记录、营销图、纯界面文字），把 amount 置为 0。
- 用户可能额外输入一句补充说明；以图片内容为主，补充说明用于消歧。
- 只输出一个 JSON 对象，不要任何解释、不要 Markdown 代码块。
''';
}

/// 把图片直接交给用户配置的视觉模型，返回交易草稿。
///
/// 这是图片识账唯一的一次 AI 请求：图片先压到 1600px/≤1.5MB，再以 data URL
/// 放进 OpenAI-compatible `image_url` 内容块。上游明确表示不支持图片时转成
/// [AiErrorCode.visionUnsupported]，由入口提示换模型。
Future<AiEntryDraft> requestVisionEntryDraft({
  required AiSettings settings,
  required Uint8List imageBytes,
  required AiEntryContext context,
  String note = '',
}) async {
  final prepared = await prepareVisionImage(imageBytes);
  final trimmedNote = note.trim();
  final input = trimmedNote.length > visionEntryNoteMaxLength
      ? trimmedNote.substring(0, visionEntryNoteMaxLength)
      : trimmedNote;

  final AiCompletionResult result;
  try {
    result = await aiAgentComplete(
      settings: settings,
      messages: <AiAgentMessage>[
        AiTextMessage.system(buildVisionEntryPrompt(context)),
        AiVisionMessage(
          text: input.isEmpty ? '请识别这张图片中的交易。' : input,
          imageDataUrl: visionImageDataUrl(prepared),
        ),
      ],
    );
  } on AiException catch (error) {
    if (isUnsupportedVisionError(error)) {
      throw AiException(AiErrorCode.visionUnsupported, detail: error.detail);
    }
    rethrow;
  }
  return parseAiEntryDraft(result.content, context);
}
