import 'ai_agent_message.dart';
import 'ai_completion_event.dart';
import 'ai_error.dart';
import 'ai_settings.dart';

export 'ai_error.dart' show AiException, AiErrorCode, aiErrorMessage;

Future<AiCompletionResult> aiAgentComplete({
  required AiSettings settings,
  required List<AiAgentMessage> messages,
  List<Map<String, Object?>> tools = const <Map<String, Object?>>[],
  double temperature = 0,
  Duration connectionTimeout = const Duration(seconds: 20),
  Duration responseTimeout = const Duration(seconds: 60),
}) async {
  throw AiException(AiErrorCode.notSupported);
}

Stream<AiCompletionEvent> aiAgentStream({
  required AiSettings settings,
  required List<AiAgentMessage> messages,
  List<Map<String, Object?>> tools = const <Map<String, Object?>>[],
  double temperature = 0,
  Duration connectionTimeout = const Duration(seconds: 20),
  Duration responseTimeout = const Duration(seconds: 60),
  Duration idleTimeout = const Duration(seconds: 45),
}) async* {
  throw AiException(AiErrorCode.notSupported);
}

Future<String> aiChatComplete({
  required AiSettings settings,
  String? systemPrompt,
  String? userPrompt,
  List<Map<String, String>>? messages,
  double temperature = 0,
  Duration timeout = const Duration(seconds: 45),
}) async {
  throw AiException(AiErrorCode.notSupported);
}
