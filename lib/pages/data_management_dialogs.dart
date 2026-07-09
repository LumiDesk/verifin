part of 'data_management_page.dart';

class _BackupProgressDialog extends StatelessWidget {
  const _BackupProgressDialog({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      content: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          const SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(strokeWidth: 2.4),
          ),
          const SizedBox(width: 16),
          Flexible(child: Text(label)),
        ],
      ),
    );
  }
}

/// 输入解密口令的对话框。用 StatefulWidget 在 [State.dispose]（退出动画结束后）
/// 释放控制器，避免退出动画期间 TextField 用到已释放控制器。
class _PassphrasePromptDialog extends StatefulWidget {
  const _PassphrasePromptDialog({
    required this.title,
    required this.message,
    required this.errorText,
  });

  final String title;
  final String message;
  final String errorText;

  @override
  State<_PassphrasePromptDialog> createState() =>
      _PassphrasePromptDialogState();
}

class _PassphrasePromptDialogState extends State<_PassphrasePromptDialog> {
  final TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(widget.title),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(widget.message),
          const SizedBox(height: 12),
          TextField(
            controller: _controller,
            autofocus: true,
            obscureText: true,
            decoration: InputDecoration(
              labelText: l10n.backupKeyLabel,
              errorText: widget.errorText.isEmpty ? null : widget.errorText,
            ),
          ),
        ],
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.commonCancel),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(_controller.text),
          child: Text(l10n.okLabel),
        ),
      ],
    );
  }
}

/// 设置 / 修改加密口令的对话框（两次输入 + 校验）。控制器由 State 管理并释放。
class _SetPassphraseDialog extends StatefulWidget {
  const _SetPassphraseDialog({required this.isChange});

  final bool isChange;

  @override
  State<_SetPassphraseDialog> createState() => _SetPassphraseDialogState();
}

class _SetPassphraseDialogState extends State<_SetPassphraseDialog> {
  final TextEditingController _keyController = TextEditingController();
  final TextEditingController _confirmController = TextEditingController();
  String? _errorText;

  @override
  void dispose() {
    _keyController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(widget.isChange ? l10n.changeKeyTitle : l10n.setKeyTitle),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(l10n.setKeyMessage),
          const SizedBox(height: 12),
          TextField(
            controller: _keyController,
            autofocus: true,
            obscureText: true,
            decoration: InputDecoration(labelText: l10n.keyMinLabel),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _confirmController,
            obscureText: true,
            decoration: InputDecoration(
              labelText: l10n.keyRepeatLabel,
              errorText: _errorText,
            ),
          ),
        ],
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.commonCancel),
        ),
        FilledButton(
          onPressed: () {
            final key = _keyController.text;
            if (key.length < 4) {
              setState(() => _errorText = l10n.keyTooShort);
              return;
            }
            if (key != _confirmController.text) {
              setState(() => _errorText = l10n.keyMismatch);
              return;
            }
            Navigator.of(context).pop(key);
          },
          child: Text(l10n.commonSave),
        ),
      ],
    );
  }
}

/// 编辑 WebDAV 配置的对话框（含连通性测试）。控制器由 State 管理并释放。
class _WebdavEditDialog extends StatefulWidget {
  const _WebdavEditDialog({required this.existing});

  final WebdavConfig existing;

  @override
  State<_WebdavEditDialog> createState() => _WebdavEditDialogState();
}

class _WebdavEditDialogState extends State<_WebdavEditDialog> {
  late final TextEditingController _urlController = TextEditingController(
    text: widget.existing.url,
  );
  late final TextEditingController _userController = TextEditingController(
    text: widget.existing.username,
  );
  late final TextEditingController _passController = TextEditingController(
    text: widget.existing.password,
  );
  String? _statusText;
  bool _testing = false;

  WebdavConfig _current() => WebdavConfig(
    url: _urlController.text.trim(),
    username: _userController.text.trim(),
    password: _passController.text,
    autoUpload: widget.existing.autoUpload,
  );

  @override
  void dispose() {
    _urlController.dispose();
    _userController.dispose();
    _passController.dispose();
    super.dispose();
  }

  Future<void> _test() async {
    final l10n = AppLocalizations.of(context);
    setState(() {
      _testing = true;
      _statusText = l10n.testingConnection;
    });
    try {
      await webdavTestConnection(_current());
      if (mounted) setState(() => _statusText = l10n.connectionOk);
    } catch (error) {
      if (mounted) {
        setState(() => _statusText = l10n.connectionFailed('$error'));
      }
    } finally {
      if (mounted) setState(() => _testing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(l10n.webdavServer),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            TextField(
              controller: _urlController,
              autofocus: true,
              keyboardType: TextInputType.url,
              decoration: InputDecoration(
                labelText: l10n.webdavUrlLabel,
                hintText: 'https://dav.example.com/verifin/',
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _userController,
              decoration: InputDecoration(labelText: l10n.webdavUserLabel),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _passController,
              obscureText: true,
              decoration: InputDecoration(labelText: l10n.webdavPassLabel),
            ),
            if (_statusText != null) ...<Widget>[
              const SizedBox(height: 10),
              Text(_statusText!, style: Theme.of(context).textTheme.bodySmall),
            ],
          ],
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.commonCancel),
        ),
        TextButton(
          onPressed: _testing || _urlController.text.trim().isEmpty
              ? null
              : _test,
          child: Text(l10n.testConnection),
        ),
        FilledButton(
          onPressed: () {
            if (_urlController.text.trim().isEmpty) {
              setState(() => _statusText = l10n.fillServerUrl);
              return;
            }
            Navigator.of(context).pop(_current());
          },
          child: Text(l10n.commonSave),
        ),
      ],
    );
  }
}
