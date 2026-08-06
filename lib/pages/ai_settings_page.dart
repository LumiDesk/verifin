import 'package:flutter/material.dart';

import '../app/ai/ai_capabilities.dart';
import '../app/ai/ai_client.dart';
import '../app/ai/ai_settings.dart';
import '../app/app_theme.dart';
import '../app/common_widgets.dart';
import '../app/veri_fin_scope.dart';
import '../l10n/app_localizations.dart';
import 'sheets.dart';

/// AI 记账设置页：配置 OpenAI 兼容服务的请求地址、API Key、模型，并测试连通性。
/// 配置为设备本地偏好（存 KV），不进 JSON 备份、初始化保留。
class AiSettingsPage extends StatefulWidget {
  const AiSettingsPage({super.key});

  @override
  State<AiSettingsPage> createState() => _AiSettingsPageState();
}

class _AiSettingsPageState extends State<AiSettingsPage> {
  final EditorExitController _exitController = EditorExitController();
  final TextEditingController _baseUrlController = TextEditingController();
  final TextEditingController _apiKeyController = TextEditingController();
  final TextEditingController _modelController = TextEditingController();
  bool _seeded = false;
  late AiSettings _initialSettings;
  bool _obscureKey = true;
  bool _testing = false;
  AiToolCallMode _toolCallMode = AiToolCallMode.auto;
  AiCapabilityProfile? _detectedProfile;
  String? _statusText;
  bool _statusIsError = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_seeded) {
      final settings = VeriFinScope.of(context).aiSettings;
      _initialSettings = settings;
      _baseUrlController.text = settings.baseUrl;
      _apiKeyController.text = settings.apiKey;
      _modelController.text = settings.model;
      _toolCallMode = settings.toolCallMode;
      final cached = VeriFinScope.of(context).aiCapabilityProfile;
      if (cached?.matches(settings) == true) {
        _detectedProfile = cached;
        _statusText = _capabilityStatus(cached!, settings);
      }
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
    toolCallMode: _toolCallMode,
  );

  bool get _isDirty => _seeded && _current() != _initialSettings;

  Future<void> _saveAndExit() async {
    if (await _save() && mounted) {
      setState(() => _initialSettings = _current());
      _exitController.exit();
    }
  }

  Future<bool> _save() async {
    final l10n = AppLocalizations.of(context);
    final settings = _current();
    if (!settings.isConfigured) {
      setState(() {
        _statusIsError = true;
        _statusText = l10n.aiFillAllFields;
      });
      return false;
    }
    // http 发往公网主机会明文暴露 API Key，保存前提醒确认。
    if (!await confirmCleartextIfRisky(context, settings.baseUrl)) return false;
    if (!mounted) return false;
    final detected = _detectedProfile;
    final saved = await VeriFinScope.of(
      context,
    ).saveAiSettingsDraft(settings, detectedProfile: detected);
    if (!mounted || !saved) {
      return false;
    }
    FocusScope.of(context).unfocus();
    setState(() {
      _statusIsError = false;
      _statusText = null;
    });
    return true;
  }

  Future<void> _clearConfig() async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await showConfirmDialog(
      context,
      title: l10n.aiClearConfig,
      message: l10n.aiClearConfigMessage,
      confirmLabel: l10n.aiClearConfig,
      destructive: true,
    );
    if (!confirmed || !mounted) {
      return;
    }
    final saved = await VeriFinScope.of(
      context,
    ).saveAiSettingsDraft(const AiSettings());
    if (!mounted || !saved) {
      return;
    }
    _baseUrlController.clear();
    _apiKeyController.clear();
    _modelController.clear();
    _toolCallMode = AiToolCallMode.auto;
    _detectedProfile = null;
    _initialSettings = const AiSettings();
    FocusScope.of(context).unfocus();
    setState(() {
      _statusIsError = false;
      _statusText = null;
    });
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(l10n.aiConfigCleared)));
  }

  Future<void> _detectCapabilities() async {
    final l10n = AppLocalizations.of(context);
    final settings = _current();
    if (!settings.isConfigured) {
      setState(() {
        _statusIsError = true;
        _statusText = l10n.aiFillAllFields;
      });
      return;
    }
    if (!await confirmCleartextIfRisky(context, settings.baseUrl)) return;
    if (!mounted) return;
    setState(() {
      _testing = true;
      _statusIsError = false;
      _statusText = l10n.aiDetectingCapabilities;
    });
    try {
      final profile = await detectAiCapabilities(settings: settings);
      if (!mounted) {
        return;
      }
      final scope = VeriFinScope.of(context);
      if (profile.matches(scope.aiSettings)) {
        scope.setAiCapabilityProfile(profile);
      }
      setState(() {
        _detectedProfile = profile;
        _statusIsError = false;
        _statusText = _capabilityStatus(profile, settings);
      });
    } on AiException catch (error) {
      if (!mounted) {
        return;
      }
      VeriFinScope.of(
        context,
      ).logger?.error('AI 能力检测失败', source: 'ai', error: error);
      setState(() {
        _statusIsError = true;
        _statusText = l10n.connectionFailed(aiErrorMessage(l10n, error));
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      VeriFinScope.of(
        context,
      ).logger?.error('AI 能力检测失败', source: 'ai', error: error);
      setState(() {
        _statusIsError = true;
        _statusText = l10n.connectionFailed(l10n.aiErrUnknown);
      });
    } finally {
      if (mounted) {
        setState(() => _testing = false);
      }
    }
  }

  Future<void> _selectToolCallMode() async {
    final selected = await showOptionSheet<AiToolCallMode>(
      context: context,
      title: AppLocalizations.of(context).aiToolModeTitle,
      values: AiToolCallMode.values,
      selected: _toolCallMode,
      labelOf: _toolModeLabel,
    );
    if (selected == null || !mounted) return;
    setState(() {
      _toolCallMode = selected;
      final profile = _detectedProfile;
      if (profile != null) {
        _statusText = _capabilityStatus(profile, _current());
      }
    });
  }

  String _toolModeLabel(AiToolCallMode mode) {
    final l10n = AppLocalizations.of(context);
    return switch (mode) {
      AiToolCallMode.auto => l10n.aiToolModeAuto,
      AiToolCallMode.native => l10n.aiToolModeNative,
      AiToolCallMode.prompt => l10n.aiToolModePrompt,
    };
  }

  String _toolModeHint(AiToolCallMode mode) {
    final l10n = AppLocalizations.of(context);
    return switch (mode) {
      AiToolCallMode.auto => l10n.aiToolModeAutoHint,
      AiToolCallMode.native => l10n.aiToolModeNativeHint,
      AiToolCallMode.prompt => l10n.aiToolModePromptHint,
    };
  }

  String _capabilityStatus(AiCapabilityProfile profile, AiSettings settings) {
    final l10n = AppLocalizations.of(context);
    final capability =
        profile.nativeToolCalls == AiNativeToolCapability.supported
        ? l10n.aiNativeToolsSupported
        : l10n.aiNativeToolsUnsupported;
    final effectiveMode = profile.effectiveMode(settings);
    final protocol = switch (effectiveMode) {
      AiToolCallMode.native => l10n.aiActualProtocolNative,
      AiToolCallMode.prompt => l10n.aiActualProtocolPrompt,
      AiToolCallMode.auto => l10n.aiActualProtocolAuto,
    };
    return '${l10n.aiConnectionReady}\n'
        '${l10n.aiStreamingReady}\n'
        '$capability\n'
        '$protocol';
  }

  void _onConfigChanged() {
    setState(() {
      _detectedProfile = null;
      _statusText = null;
      _statusIsError = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurface.withValues(alpha: 0.55);

    return UnsavedChangesGuard(
      isDirty: _isDirty,
      onSave: _save,
      exitController: _exitController,
      child: Scaffold(
        body: SafeArea(
          child: VeriPage(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(14, 8, 14, 28),
              children: <Widget>[
                VeriHeader(
                  title: l10n.aiSettingsTitle,
                  showBack: true,
                  actions: <Widget>[
                    HeaderAction(
                      icon: Icons.delete_outline,
                      tooltip: l10n.aiClearConfig,
                      destructive: true,
                      onPressed:
                          (_baseUrlController.text.isEmpty &&
                              _apiKeyController.text.isEmpty &&
                              _modelController.text.isEmpty)
                          ? null
                          : _clearConfig,
                    ),
                    SaveHeaderAction(
                      onPressed: _isDirty && _current().isConfigured
                          ? _saveAndExit
                          : null,
                    ),
                  ],
                ),
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
                        onChanged: (_) => _onConfigChanged(),
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
                        onChanged: (_) => _onConfigChanged(),
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
                        onChanged: (_) => _onConfigChanged(),
                        autocorrect: false,
                        decoration: InputDecoration(
                          labelText: l10n.aiModelLabel,
                          hintText: l10n.aiModelHint,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Material(
                        color: Colors.transparent,
                        child: ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(l10n.aiToolModeTitle),
                          subtitle: Text(
                            '${_toolModeLabel(_toolCallMode)} · '
                            '${_toolModeHint(_toolCallMode)}',
                          ),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: _testing ? null : _selectToolCallMode,
                        ),
                      ),
                      Text(
                        l10n.aiCapabilityProbeNotice,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: muted,
                          height: 1.4,
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
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: _testing ? null : _detectCapabilities,
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size(44, 44),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 10,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(veriRadiusMd),
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
                          label: Text(l10n.aiDetectCapabilities),
                        ),
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
      ),
    );
  }
}
