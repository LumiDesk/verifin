// AI 对话查询页：用户用自然语言询问账目，AI 调用只读工具查询后以图表 / 列表 / 卡片 +
// Markdown 文字作答。全屏聊天页，消息气泡 + 底部输入框 + 清空历史。
//
// 网络传输默认用 `aiChatStream`（SSE）；`debugTransport` 供测试注入假流，避免真实网络。
import 'package:flutter/material.dart';
import 'package:gpt_markdown/gpt_markdown.dart';

import '../app/ai/ai_chat_engine.dart';
import '../app/ai/ai_client.dart';
import '../app/ai/ai_query_tool.dart';
import '../app/app_theme.dart';
import '../app/common_widgets.dart';
import '../app/veri_fin_scope.dart';
import '../l10n/app_localizations.dart';
import 'ai_result_view.dart';
import 'ai_settings_page.dart';

enum _Role { user, assistant }

enum _MsgStatus { streaming, done, error }

/// 一条聊天消息的 UI 状态。助手消息可同时含若干结果卡片与流式 Markdown 文本。
class _ChatMessage {
  _ChatMessage({
    required this.role,
    this.text = '',
    this.status = _MsgStatus.done,
  });

  final _Role role;
  String text;
  final List<AiResultDisplay> displays = <AiResultDisplay>[];
  _MsgStatus status;

  /// 助手正在查询 / 思考时的状态标签（有值即显示带转圈的提示）。
  String? statusLabel;
}

class AiChatPage extends StatefulWidget {
  const AiChatPage({super.key, this.debugTransport});

  /// 测试注入的传输实现；为 null 时用真实的 `aiChatStream`。
  final AiChatTransport? debugTransport;

  @override
  State<AiChatPage> createState() => _AiChatPageState();
}

class _AiChatPageState extends State<AiChatPage> {
  final List<_ChatMessage> _messages = <_ChatMessage>[];
  final TextEditingController _input = TextEditingController();
  final ScrollController _scroll = ScrollController();
  final AiChatEngine _engine = AiChatEngine(tools: buildAiQueryTools());
  bool _streaming = false;

  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(
          _scroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  /// 从已完成的历史消息构建给模型的上下文（不含正在流式的这条）。
  List<Map<String, String>> _priorMessages() {
    return <Map<String, String>>[
      for (final m in _messages)
        if (m.status == _MsgStatus.done && m.text.trim().isNotEmpty)
          <String, String>{
            'role': m.role == _Role.user ? 'user' : 'assistant',
            'content': m.text.trim(),
          },
    ];
  }

  Future<void> _send() async {
    final text = _input.text.trim();
    if (text.isEmpty || _streaming) {
      return;
    }
    final scope = VeriFinScope.of(context);
    final l10n = AppLocalizations.of(context);
    final prior = _priorMessages();
    final context0 = AiToolContext(
      entries: scope.entries,
      accounts: scope.accounts,
      categories: scope.categories,
      tags: scope.tags,
      balanceOf: scope.accountBalance,
      now: DateTime.now(),
    );
    final settings = scope.aiSettings;
    final transport =
        widget.debugTransport ??
        (List<Map<String, String>> messages) =>
            aiChatStream(settings: settings, messages: messages);

    final assistant = _ChatMessage(
      role: _Role.assistant,
      status: _MsgStatus.streaming,
    )..statusLabel = l10n.aiChatThinking;
    setState(() {
      _input.clear();
      _messages.add(_ChatMessage(role: _Role.user, text: text));
      _messages.add(assistant);
      _streaming = true;
    });
    _scrollToBottom();

    try {
      await for (final event in _engine.run(
        transport: transport,
        context: context0,
        priorMessages: prior,
        userInput: text,
      )) {
        if (!mounted) {
          return;
        }
        setState(() {
          switch (event) {
            case AiChatToolInvoked():
              assistant.statusLabel = l10n.aiChatQuerying;
            case final AiChatToolDisplay e:
              assistant.displays.add(e.display);
            case final AiChatAnswerDelta e:
              assistant.statusLabel = null;
              assistant.text += e.delta;
            case final AiChatCompleted e:
              assistant.statusLabel = null;
              if (assistant.text.trim().isEmpty) {
                assistant.text = e.answer;
              }
              assistant.status = _MsgStatus.done;
            case final AiChatFailed e:
              assistant.statusLabel = null;
              assistant.status = _MsgStatus.error;
              assistant.text = e.error is AiException
                  ? aiErrorMessage(l10n, e.error as AiException)
                  : '$e';
          }
        });
        _scrollToBottom();
      }
    } finally {
      if (mounted) {
        setState(() {
          _streaming = false;
          if (assistant.status == _MsgStatus.streaming) {
            assistant.status = _MsgStatus.done;
          }
        });
      }
    }
  }

  Future<void> _clearHistory() async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await showConfirmDialog(
      context,
      title: l10n.aiChatClearHistory,
      message: l10n.aiChatClearMessage,
      confirmLabel: l10n.aiChatClearConfirm,
      destructive: true,
    );
    if (confirmed && mounted) {
      setState(_messages.clear);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final configured = VeriFinScope.of(context).aiSettings.isConfigured;
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.aiChatTitle),
        actions: <Widget>[
          if (_messages.isNotEmpty)
            IconButton(
              tooltip: l10n.aiChatClearHistory,
              onPressed: _streaming ? null : _clearHistory,
              icon: const Icon(Icons.delete_sweep_outlined),
            ),
        ],
      ),
      body: SafeArea(
        child: configured ? _buildChat(context) : _buildUnconfigured(context),
      ),
    );
  }

  Widget _buildUnconfigured(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(
              Icons.smart_toy_outlined,
              size: 56,
              color: Theme.of(
                context,
              ).colorScheme.onSurface.withValues(alpha: 0.4),
            ),
            const SizedBox(height: 16),
            Text(l10n.aiChatUnconfiguredHint, textAlign: TextAlign.center),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => const AiSettingsPage()),
              ),
              icon: const Icon(Icons.settings_outlined),
              label: Text(l10n.aiChatGoConfigure),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChat(BuildContext context) {
    return Column(
      children: <Widget>[
        Expanded(
          child: _messages.isEmpty
              ? _buildEmptyState(context)
              : ListView.builder(
                  controller: _scroll,
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                  itemCount: _messages.length,
                  itemBuilder: (context, index) =>
                      _MessageView(message: _messages[index]),
                ),
        ),
        _buildInputBar(context),
      ],
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final hints = <String>[
      l10n.aiChatHintTopCategory,
      l10n.aiChatHintLargeExpense,
      l10n.aiChatHintMonthSummary,
    ];
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Center(
              child: Text(
                l10n.aiChatEmptyTitle,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            const SizedBox(height: 16),
            for (final hint in hints)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: ActionChip(
                  avatar: const Icon(Icons.chat_bubble_outline, size: 16),
                  label: Text(hint),
                  onPressed: () {
                    _input.text = hint;
                    _send();
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildInputBar(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(
          top: BorderSide(
            color: Theme.of(
              context,
            ).colorScheme.onSurface.withValues(alpha: 0.08),
          ),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: <Widget>[
          Expanded(
            child: TextField(
              controller: _input,
              minLines: 1,
              maxLines: 4,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => _send(),
              decoration: InputDecoration(
                hintText: AppLocalizations.of(context).aiChatInputHint,
                filled: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(veriRadiusLg),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          IconButton.filled(
            onPressed: _streaming ? null : _send,
            icon: _streaming
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.arrow_upward),
          ),
        ],
      ),
    );
  }
}

class _MessageView extends StatelessWidget {
  const _MessageView({required this.message});

  final _ChatMessage message;

  @override
  Widget build(BuildContext context) {
    if (message.role == _Role.user) {
      return Align(
        alignment: Alignment.centerRight,
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 6),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.82,
          ),
          decoration: BoxDecoration(
            color: veriRoyal,
            borderRadius: BorderRadius.circular(veriRadiusLg),
          ),
          child: Text(
            message.text,
            style: const TextStyle(color: Colors.white),
          ),
        ),
      );
    }
    final isError = message.status == _MsgStatus.error;
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          if (message.statusLabel != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    message.statusLabel!,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          for (final display in message.displays) ...<Widget>[
            AiResultView(display: display),
            const SizedBox(height: 8),
          ],
          if (message.text.trim().isNotEmpty)
            isError
                ? Text(
                    message.text,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  )
                : GptMarkdown(message.text),
        ],
      ),
    );
  }
}
