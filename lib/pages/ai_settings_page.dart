import 'package:flutter/material.dart';

import '../app/ai/ai_client.dart';
import '../app/ai/ai_settings.dart';
import '../app/app_theme.dart';
import '../app/common_widgets.dart';
import '../app/veri_fin_scope.dart';
import '../l10n/app_localizations.dart';

/// AI 记账设置页：配置 OpenAI 兼容服务的请求地址、API Key、模型，并测试连通性。
/// 配置为设备本地偏好（存 KV），不进 JSON 备份、初始化保留。
class AiSettingsPage extends StatefulWidget {
  const AiSettingsPage({super.key});

  @override
  State<AiSettingsPage> createState() => _AiSettingsPageState();
}

class _AiSettingsPageState extends State<AiSettingsPage> {
  final TextEditingController _baseUrlController = TextEditingController();
  final TextEditingController _apiKeyController = TextEditingController();
  final TextEditingController _modelController = TextEditingController();
  bool _seeded = false;
  bool _obscureKey = true;
  bool _testing = false;
  String? _statusText;
  bool _statusIsError = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_seeded) {
      final settings = VeriFinScope.of(context).aiSettings;
      _baseUrlController.text = settings.baseUrl;
      _apiKeyController.text = settings.apiKey;
      _modelController.text = settings.model;
      _seeded = true;
    }
  }

  @override
  void dispose() {
    _baseUrlController.dispose();
    _apiKeyController.dispose();
    _modelController.dispose();
    super.dispose();
  }

  AiSettings _current() => AiSettings(
    baseUrl: _baseUrlController.text.trim(),
    apiKey: _apiKeyController.text.trim(),
    model: _modelController.text.trim(),
  );

  void _save() {
    final l10n = AppLocalizations.of(context);
    final settings = _current();
    if (!settings.isConfigured) {
      setState(() {
        _statusIsError = true;
        _statusText = l10n.aiFillAllFields;
      });
      return;
    }
    VeriFinScope.of(context).setAiSettings(settings);
    FocusScope.of(context).unfocus();
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(l10n.aiSettingsSaved)));
    setState(() {
      _statusIsError = false;
      _statusText = null;
    });
  }

  Future<void> _testConnection() async {
    final l10n = AppLocalizations.of(context);
    final settings = _current();
    if (!settings.isConfigured) {
      setState(() {
        _statusIsError = true;
        _statusText = l10n.aiFillAllFields;
      });
      return;
    }
    setState(() {
      _testing = true;
      _statusIsError = false;
      _statusText = l10n.testingConnection;
    });
    try {
      await aiChatComplete(
        settings: settings,
        systemPrompt: 'You are a health check. Reply with the single word OK.',
        userPrompt: 'ping',
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _statusIsError = false;
        _statusText = l10n.connectionOk;
      });
    } on AiException catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _statusIsError = true;
        _statusText = l10n.connectionFailed(error.message);
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _statusIsError = true;
        _statusText = l10n.connectionFailed('$error');
      });
    } finally {
      if (mounted) {
        setState(() => _testing = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurface.withValues(alpha: 0.55);

    return Scaffold(
      body: SafeArea(
        child: VeriPage(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(14, 8, 14, 28),
            children: <Widget>[
              VeriHeader(title: l10n.aiSettingsTitle, showBack: true),
              const SizedBox(height: 10),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Text(
                  l10n.aiSettingsIntro,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: muted,
                    height: 1.5,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              VeriCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    TextField(
                      controller: _baseUrlController,
                      keyboardType: TextInputType.url,
                      autocorrect: false,
                      decoration: InputDecoration(
                        labelText: l10n.aiBaseUrlLabel,
                        hintText: l10n.aiBaseUrlHint,
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _apiKeyController,
                      obscureText: _obscureKey,
                      autocorrect: false,
                      enableSuggestions: false,
                      decoration: InputDecoration(
                        labelText: l10n.aiApiKeyLabel,
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscureKey
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                          ),
                          onPressed: () =>
                              setState(() => _obscureKey = !_obscureKey),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _modelController,
                      autocorrect: false,
                      decoration: InputDecoration(
                        labelText: l10n.aiModelLabel,
                        hintText: l10n.aiModelHint,
                      ),
                    ),
                    if (_statusText != null) ...<Widget>[
                      const SizedBox(height: 12),
                      Text(
                        _statusText!,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: _statusIsError
                              ? theme.colorScheme.error
                              : theme.colorScheme.primary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                    const SizedBox(height: 14),
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _testing ? null : _testConnection,
                            style: OutlinedButton.styleFrom(
                              minimumSize: const Size(44, 44),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 10,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(
                                  veriRadiusMd,
                                ),
                              ),
                            ),
                            icon: _testing
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(Icons.wifi_tethering, size: 18),
                            label: Text(l10n.testConnection),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: FilledButton(
                            onPressed: _save,
                            child: Text(l10n.commonSave),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest.withValues(
                    alpha: 0.4,
                  ),
                  borderRadius: BorderRadius.circular(veriRadiusMd),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Icon(Icons.privacy_tip_outlined, size: 16, color: muted),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        l10n.aiPrivacyNotice,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: muted,
                          height: 1.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
