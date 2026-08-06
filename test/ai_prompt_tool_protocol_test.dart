import 'package:flutter_test/flutter_test.dart';
import 'package:verifin/app/ai/ai_error.dart';
import 'package:verifin/app/ai/ai_prompt_tool_protocol.dart';

void main() {
  const tools = <String>{'summary', 'queryTransactions'};

  test('parses a marked tool call surrounded by reasoning noise', () {
    final response = parsePromptResponse(
      '<think>先查一下 {这里不是 JSON}</think>\n'
      'VERIFIN_TOOL\n'
      '```json\n'
      '{"tool":"queryTransactions","args":'
      '{"keyword":"包含 { 大括号 } 的备注"}}\n'
      '```\n稍后给结论',
      knownTools: tools,
    );

    expect(response, isA<AiPromptToolCall>());
    final call = response as AiPromptToolCall;
    expect(call.name, 'queryTransactions');
    expect(call.arguments['keyword'], '包含 { 大括号 } 的备注');
  });

  test('keeps compatibility with the previous raw JSON shape', () {
    final response =
        parsePromptResponse(
              '我先查询。 {"tool":"summary","args":{"range":"thisMonth"}}',
              knownTools: tools,
            )
            as AiPromptToolCall;

    expect(response.name, 'summary');
    expect(response.arguments['range'], 'thisMonth');
  });

  test('answer marker strips protocol marker and optional code fence', () {
    final response =
        parsePromptResponse(
              'VERIFIN_ANSWER\n```markdown\n**本月支出** 300 元\n```',
              knownTools: tools,
            )
            as AiPromptAnswer;

    expect(response.text, '**本月支出** 300 元');
  });

  test('plain prose remains a valid direct answer', () {
    final response =
        parsePromptResponse('你好，我是你的财务助理。', knownTools: tools)
            as AiPromptAnswer;

    expect(response.text, '你好，我是你的财务助理。');
  });

  test('malformed tool control never falls through as a visible answer', () {
    expect(
      () => parsePromptResponse(
        'VERIFIN_TOOL\n{"tool":"summary","args":{',
        knownTools: tools,
      ),
      throwsA(
        isA<AiException>().having(
          (error) => error.code,
          'code',
          AiErrorCode.badResponse,
        ),
      ),
    );
  });
}
