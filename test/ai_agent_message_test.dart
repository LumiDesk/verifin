import 'package:flutter_test/flutter_test.dart';
import 'package:verifin/app/ai/ai_agent_message.dart';

void main() {
  test('text messages serialize with their explicit role', () {
    expect(const AiTextMessage.system('system').toJson(), <String, Object?>{
      'role': 'system',
      'content': 'system',
    });
    expect(const AiTextMessage.user('hello').toJson(), <String, Object?>{
      'role': 'user',
      'content': 'hello',
    });
  });

  test('native tool call keeps protocol fields and decodes arguments', () {
    const call = AiNativeToolCall(
      id: 'call_1',
      name: 'summary',
      arguments: '{"range":"thisMonth"}',
    );
    final message = const AiAssistantToolMessage(
      reasoningContent: 'private reasoning',
      toolCalls: <AiNativeToolCall>[call],
    ).toJson();

    expect(call.decodeArguments(), <String, Object?>{'range': 'thisMonth'});
    expect(message['role'], 'assistant');
    expect(message['reasoning_content'], 'private reasoning');
    expect(message['tool_calls'], hasLength(1));
    expect(
      const AiToolResultMessage(
        toolCallId: 'call_1',
        content: 'result',
      ).toJson(),
      <String, Object?>{
        'role': 'tool',
        'tool_call_id': 'call_1',
        'content': 'result',
      },
    );
  });

  test('malformed native arguments are rejected', () {
    expect(
      const AiNativeToolCall(
        id: 'call_1',
        name: 'summary',
        arguments: '{',
      ).decodeArguments(),
      isNull,
    );
  });
}
