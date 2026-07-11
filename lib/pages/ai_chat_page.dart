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
    List<AiResultDisplay>? displays,
  }) : displays = displays ?? <AiResultDisplay>[];

  final _Role role;
  String text;
  final List<AiResultDisplay> displays;
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
  bool _restored = false;

  /// 落库的历史消息上限，防止 KV 无限增长。
  static const int _historyLimit = 40;

  @override
  void initState() {
    super.initState();
    // 输入内容变化时刷新发送按钮的可用态（空内容不可发送）。
    _input.addListener(_onInputChanged);
  }

  void _onInputChanged() => setState(() {});

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_restored) {
      return;
    }
    _restored = true;
    // 重开时恢复历史文字与结果卡片（displays 已序列化落库）。
    for (final message in VeriFinScope.of(context).aiChatHistory) {
      final rawDisplays = message['displays'];
      final displays = <AiResultDisplay>[
        if (rawDisplays is List)
          for (final d in rawDisplays.whereType<Map>())
            if (aiResultDisplayFromJson(Map<String, Object?>.from(d))
                case final AiResultDisplay display)
              display,
      ];
      _messages.add(
        _ChatMessage(
          role: message['role'] == 'user' ? _Role.user : _Role.assistant,
          text: message['content']?.toString() ?? '',
          displays: displays,
        ),
      );
    }
  }

  @override
  void dispose() {
    _input.removeListener(_onInputChanged);
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  bool get _canSend => !_streaming && _input.text.trim().isNotEmpty;

  /// 把当前对话落库（文本 + 序列化的结果卡片，截断到最近 [_historyLimit] 条）。
  void _saveHistory() {
    final all = <Map<String, Object?>>[
      for (final m in _messages)
        if (m.status == _MsgStatus.done &&
            (m.text.trim().isNotEmpty || m.displays.isNotEmpty))
          <String, Object?>{
            'role': m.role == _Role.user ? 'user' : 'assistant',
            'content': m.text.trim(),
            if (m.displays.isNotEmpty)
              'displays': m.displays.map((d) => d.toJson()).toList(),
          },
    ];
    final trimmed = all.length > _historyLimit
        ? all.sublist(all.length - _historyLimit)
        : all;
    VeriFinScope.of(context).setAiChatHistory(trimmed);
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
        _saveHistory();
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
      VeriFinScope.of(context).clearAiChatHistory();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final configured = VeriFinScope.of(context).aiSettings.isConfigured;
    return Scaffold(
      body: SafeArea(
        child: VeriPage(
          child: Column(
            children: <Widget>[
              // 与统计分析/收支统计等页保持一致：头部套 fromLTRB(14, 8, 14, 0) 内边距，
              // 使返回箭头/标题的位置和其它页对齐（VeriHeader 自身无横向内边距）。
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 8, 14, 0),
                child: VeriHeader(
                  title: l10n.aiChatTitle,
                  showBack: true,
                  actions: <Widget>[
                    if (_messages.isNotEmpty)
                      HeaderAction(
                        icon: Icons.delete_sweep_outlined,
                        tooltip: l10n.aiChatClearHistory,
                        destructive: true,
                        onPressed: _streaming ? null : _clearHistory,
                      ),
                  ],
                ),
              ),
              Expanded(
                child: configured
                    ? (_messages.isEmpty
                          ? _buildEmptyState(context)
                          : _buildMessageList(context))
                    : _buildUnconfigured(context),
              ),
              if (configured) _buildInputBar(context),
            ],
          ),
        ),
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

  Widget _buildMessageList(BuildContext context) {
    return ListView.builder(
      controller: _scroll,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 18),
      itemCount: _messages.length,
      itemBuilder: (context, index) => _MessageView(message: _messages[index]),
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
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final canSend = _canSend;
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 16),
      decoration: BoxDecoration(
        color: isDark ? veriSurfaceDark : veriSurfaceLight,
        border: Border(
          top: BorderSide(color: isDark ? Colors.white10 : veriLine),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: <Widget>[
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: isDark ? Colors.white10 : veriSurfaceAltLight,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: isDark ? Colors.white12 : veriLine),
              ),
              child: TextField(
                controller: _input,
                minLines: 1,
                maxLines: 5,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _send(),
                style: const TextStyle(fontSize: 15.5, height: 1.45),
                decoration: InputDecoration(
                  hintText: AppLocalizations.of(context).aiChatInputHint,
                  isDense: true,
                  filled: false,
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 13,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          _SendButton(enabled: canSend, streaming: _streaming, onTap: _send),
        ],
      ),
    );
  }
}

/// 底部发送按钮：可用=主色圆钮 + 白色箭头；流式=主色 + 转圈；不可用=灰底灰标、不可点。
class _SendButton extends StatelessWidget {
  const _SendButton({
    required this.enabled,
    required this.streaming,
    required this.onTap,
  });

  final bool enabled;
  final bool streaming;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final disabledBg = isDark ? Colors.white12 : const Color(0xFFDCE3EE);
    final disabledFg = Theme.of(
      context,
    ).colorScheme.onSurface.withValues(alpha: 0.35);
    final active = enabled || streaming;
    return Material(
      color: active ? veriRoyal : disabledBg,
      shape: const CircleBorder(),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: enabled ? onTap : null,
        child: SizedBox(
          width: 46,
          height: 46,
          child: streaming
              ? const Padding(
                  padding: EdgeInsets.all(13),
                  child: CircularProgressIndicator(
                    strokeWidth: 2.2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
              : Icon(
                  Icons.arrow_upward_rounded,
                  color: enabled ? Colors.white : disabledFg,
                  size: 22,
                ),
        ),
      ),
    );
  }
}

class _MessageView extends StatelessWidget {
  const _MessageView({required this.message});

  final _ChatMessage message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (message.role == _Role.user) {
      return Align(
        alignment: Alignment.centerRight,
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 7),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.8,
          ),
          decoration: BoxDecoration(
            color: veriRoyal,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(18),
              topRight: Radius.circular(18),
              bottomLeft: Radius.circular(18),
              bottomRight: Radius.circular(4),
            ),
          ),
          child: Text(
            message.text,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 15.5,
              height: 1.45,
            ),
          ),
        ),
      );
    }
    final isError = message.status == _MsgStatus.error;
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 7),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          if (message.statusLabel != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8, left: 2),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  const SizedBox(
                    width: 15,
                    height: 15,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  const SizedBox(width: 9),
                  Text(
                    message.statusLabel!,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                ],
              ),
            ),
          for (final display in message.displays) ...<Widget>[
            AiResultView(display: display),
            const SizedBox(height: 10),
          ],
          if (message.text.trim().isNotEmpty)
            isError
                ? _ErrorBubble(text: message.text)
                : GptMarkdown(
                    message.text,
                    style: TextStyle(
                      fontSize: 15.5,
                      height: 1.6,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
        ],
      ),
    );
  }
}

/// 助手出错时的提示气泡（红边淡底，比裸红字更精致）。
class _ErrorBubble extends StatelessWidget {
  const _ErrorBubble({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final error = Theme.of(context).colorScheme.error;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      decoration: BoxDecoration(
        color: error.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(veriRadiusMd),
        border: Border.all(color: error.withValues(alpha: 0.35)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(Icons.error_outline, size: 18, color: error),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(color: error, fontSize: 14, height: 1.45),
            ),
          ),
        ],
      ),
    );
  }
}
