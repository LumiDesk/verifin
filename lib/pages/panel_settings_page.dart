import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app/app_theme.dart';
import '../app/common_widgets.dart';
import '../app/models.dart';
import '../app/veri_fin_scope.dart';

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
                  '$count个${kind.label}面板',
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
  bool _sorting = false;

  @override
  Widget build(BuildContext context) {
    final controller = VeriFinScope.of(context);
    final kind = widget.kind;
    final panels = controller.panelSettings(kind);
    final specById = <String, PagePanelSpec>{
      for (final spec in kind.specs) spec.id: spec,
    };

    return Scaffold(
      body: SafeArea(
        child: VeriPage(
          child: Column(
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 8, 14, 0),
                child: VeriHeader(
                  title: '${kind.label}面板',
                  subtitle: _sorting ? '拖动手柄调整顺序' : '开关与排序',
                  showBack: true,
                  actions: <Widget>[
                    HeaderAction(
                      key: const Key('panel_sort_toggle'),
                      icon: _sorting ? Icons.check : Icons.swap_vert,
                      tooltip: _sorting ? '完成排序' : '排序面板',
                      onPressed: () => setState(() => _sorting = !_sorting),
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
                    controller.reorderPanels(kind, oldIndex, newIndex);
                  },
                  itemCount: panels.length,
                  itemBuilder: (context, index) {
                    final panel = panels[index];
                    final spec = specById[panel.id];
                    return Padding(
                      key: ValueKey<String>('panel_${kind.name}_${panel.id}'),
                      padding: const EdgeInsets.only(bottom: 8),
                      child: _PanelRow(
                        spec:
                            spec ??
                            PagePanelSpec(
                              id: panel.id,
                              label: panel.id,
                              description: '',
                            ),
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
    );
  }

  void _togglePanel(String panelId, bool enabled) {
    final controller = VeriFinScope.of(context);
    if (!controller.setPanelEnabled(widget.kind, panelId, enabled)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('至少保留一个开启的${widget.kind.label}面板')),
      );
    }
  }

  void _triggerSelectionHaptic() {
    if (VeriFinScope.of(context).hapticsEnabled) {
      HapticFeedback.selectionClick();
    }
  }
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
    final mutedColor = Theme.of(
      context,
    ).colorScheme.onSurface.withValues(alpha: 0.48);

    return VeriCard(
      child: Row(
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  spec.label,
                  style: Theme.of(
                    context,
                  ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
                ),
                if (spec.description.isNotEmpty) ...<Widget>[
                  const SizedBox(height: 3),
                  Text(
                    spec.description,
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
