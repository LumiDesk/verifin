import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app/app_theme.dart';
import '../app/common_widgets.dart';
import '../app/feedback.dart';
import '../app/models.dart';
import '../app/veri_fin_scope.dart';
import '../l10n/app_localizations.dart';

/// 首页/看板底部的面板管理入口:展示开启数量,点击进入管理页。
class PanelSettingsEntry extends StatelessWidget {
  const PanelSettingsEntry({super.key, required this.kind});

  final PanelPageKind kind;

  @override
  Widget build(BuildContext context) {
    final controller = VeriFinScope.of(context);
    final count = controller.enabledPanelIds(kind).length;
    final mutedColor = Theme.of(
      context,
    ).colorScheme.onSurface.withValues(alpha: 0.44);

    return Center(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          key: Key('panel_settings_entry_${kind.name}'),
          borderRadius: BorderRadius.circular(999),
          onTap: () {
            Navigator.of(context).push<void>(
              MaterialPageRoute<void>(
                builder: (context) => PanelSettingsPage(kind: kind),
              ),
            );
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  AppLocalizations.of(context).panelCountLabel(
                    count,
                    kind.label(AppLocalizations.of(context)),
                  ),
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: mutedColor,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(width: 2),
                Icon(Icons.chevron_right, size: 14, color: mutedColor),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 面板管理页:开关各面板,进入排序模式后拖动调整顺序。
class PanelSettingsPage extends StatefulWidget {
  const PanelSettingsPage({super.key, required this.kind});

  final PanelPageKind kind;

  @override
  State<PanelSettingsPage> createState() => _PanelSettingsPageState();
}

class _PanelSettingsPageState extends State<PanelSettingsPage> {
  final EditorExitController _exitController = EditorExitController();
  bool _sorting = false;
  late List<PagePanelSetting> _initialPanels;
  late List<PagePanelSetting> _draftPanels;
  bool _initialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) {
      return;
    }
    final panels = VeriFinScope.of(context).panelSettings(widget.kind);
    _initialPanels = List<PagePanelSetting>.of(panels);
    _draftPanels = List<PagePanelSetting>.of(panels);
    _initialized = true;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final kind = widget.kind;
    final panels = _draftPanels;
    final specById = <String, PagePanelSpec>{
      for (final spec in kind.specs) spec.id: spec,
    };

    return UnsavedChangesGuard(
      isDirty: _isDirty,
      onSave: _save,
      exitController: _exitController,
      child: Scaffold(
        body: SafeArea(
          child: VeriPage(
            child: Column(
              children: <Widget>[
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 8, 14, 0),
                  child: VeriHeader(
                    title: l10n.panelPageTitle(kind.label(l10n)),
                    subtitle: _sorting
                        ? l10n.panelSortHint
                        : l10n.panelToggleHint,
                    showBack: true,
                    actions: <Widget>[
                      if (!_sorting)
                        HeaderAction(
                          key: const Key('panel_reset'),
                          icon: Icons.restart_alt,
                          tooltip: l10n.panelResetConfirm,
                          onPressed: _confirmReset,
                        ),
                      HeaderAction(
                        key: const Key('panel_sort_toggle'),
                        icon: _sorting ? Icons.check : Icons.swap_vert,
                        tooltip: _sorting
                            ? l10n.panelSortDone
                            : l10n.panelSortStart,
                        onPressed: () => setState(() => _sorting = !_sorting),
                      ),
                      SaveHeaderAction(
                        onPressed: _isDirty ? _saveAndExit : null,
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: ReorderableListView.builder(
                    padding: const EdgeInsets.fromLTRB(14, 10, 14, 28),
                    buildDefaultDragHandles: false,
                    proxyDecorator: (child, _, _) => Material(
                      color: Colors.transparent,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(veriRadiusMd),
                          boxShadow: <BoxShadow>[
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.14),
                              blurRadius: 18,
                              offset: const Offset(0, 10),
                            ),
                          ],
                        ),
                        child: child,
                      ),
                    ),
                    onReorderStart: (_) => _triggerSelectionHaptic(),
                    onReorderEnd: (_) => _triggerSelectionHaptic(),
                    onReorderItem: (oldIndex, newIndex) {
                      _triggerSelectionHaptic();
                      setState(() {
                        final moved = _draftPanels.removeAt(oldIndex);
                        _draftPanels.insert(
                          newIndex.clamp(0, _draftPanels.length),
                          moved,
                        );
                      });
                    },
                    itemCount: panels.length,
                    itemBuilder: (context, index) {
                      final panel = panels[index];
                      final spec = specById[panel.id];
                      return Padding(
                        key: ValueKey<String>('panel_${kind.name}_${panel.id}'),
                        padding: const EdgeInsets.only(bottom: 8),
                        child: _PanelRow(
                          spec: spec ?? PagePanelSpec(id: panel.id),
                          enabled: panel.enabled,
                          sorting: _sorting,
                          index: index,
                          onChanged: (value) => _togglePanel(panel.id, value),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _confirmReset() async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await showConfirmDialog(
      context,
      title: l10n.panelResetTitle(widget.kind.label(l10n)),
      message: l10n.panelResetMessage,
      confirmLabel: l10n.panelResetConfirm,
    );
    if (confirmed && mounted) {
      setState(() {
        _draftPanels = widget.kind.specs
            .map((spec) => PagePanelSetting(id: spec.id, enabled: true))
            .toList();
      });
    }
  }

  void _togglePanel(String panelId, bool enabled) {
    final index = _draftPanels.indexWhere((panel) => panel.id == panelId);
    if (index == -1) {
      return;
    }
    if (!enabled && _draftPanels.where((panel) => panel.enabled).length <= 1) {
      final l10n = AppLocalizations.of(context);
      unawaited(
        VeriFeedbackHost.of(context).showMessage(
          message: l10n.panelKeepOneMessage(widget.kind.label(l10n)),
          tone: VeriFeedbackTone.warning,
        ),
      );
      return;
    }
    setState(() {
      _draftPanels[index] = _draftPanels[index].copyWith(enabled: enabled);
    });
  }

  void _triggerSelectionHaptic() {
    if (VeriFinScope.of(context).hapticsEnabled) {
      HapticFeedback.selectionClick();
    }
  }

  bool get _isDirty {
    if (_draftPanels.length != _initialPanels.length) {
      return true;
    }
    for (var i = 0; i < _draftPanels.length; i++) {
      final current = _draftPanels[i];
      final initial = _initialPanels[i];
      if (current.id != initial.id || current.enabled != initial.enabled) {
        return true;
      }
    }
    return false;
  }

  Future<void> _saveAndExit() async {
    if (await _save() && mounted) {
      setState(() {
        _initialPanels = List<PagePanelSetting>.of(_draftPanels);
      });
      _exitController.exit();
    }
  }

  Future<bool> _save() => VeriFinScope.of(
    context,
  ).savePanelSettingsDraft(widget.kind, _draftPanels);
}

class _PanelRow extends StatelessWidget {
  const _PanelRow({
    required this.spec,
    required this.enabled,
    required this.sorting,
    required this.index,
    required this.onChanged,
  });

  final PagePanelSpec spec;
  final bool enabled;
  final bool sorting;
  final int index;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final mutedColor = Theme.of(
      context,
    ).colorScheme.onSurface.withValues(alpha: 0.48);
    final description = spec.description(l10n);

    return VeriCard(
      child: Row(
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  spec.label(l10n),
                  style: Theme.of(
                    context,
                  ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
                ),
                if (description.isNotEmpty) ...<Widget>[
                  const SizedBox(height: 3),
                  Text(
                    description,
                    style: Theme.of(
                      context,
                    ).textTheme.labelSmall?.copyWith(color: mutedColor),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          if (sorting)
            ReorderableDragStartListener(
              index: index,
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Icon(
                  Icons.drag_indicator,
                  size: 18,
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurface.withValues(alpha: 0.34),
                ),
              ),
            )
          else
            Transform.scale(
              scale: 0.82,
              alignment: Alignment.centerRight,
              child: Switch(
                key: Key('panel_switch_${spec.id}'),
                value: enabled,
                onChanged: onChanged,
              ),
            ),
        ],
      ),
    );
  }
}
