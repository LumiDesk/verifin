import 'package:flutter/material.dart';

import '../app/app_theme.dart';
import '../app/common_widgets.dart';
import '../l10n/app_localizations.dart';
import '../app/models.dart';
import '../app/veri_fin_scope.dart';
import 'sheets.dart';

class TagManagementPage extends StatefulWidget {
  const TagManagementPage({super.key});

  @override
  State<TagManagementPage> createState() => _TagManagementPageState();
}

class _TagManagementPageState extends State<TagManagementPage> {
  @override
  Widget build(BuildContext context) {
    final controller = VeriFinScope.of(context);
    final tags = controller.tags;

    return Scaffold(
      body: SafeArea(
        child: VeriPage(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(14, 8, 14, 28),
            children: <Widget>[
              VeriHeader(
                title: AppLocalizations.of(context).tagMgmt,
                subtitle: AppLocalizations.of(context).tagMgmtSubtitle,
                showBack: true,
                actions: <Widget>[
                  HeaderAction(
                    icon: Icons.add,
                    tooltip: AppLocalizations.of(context).tagAdd,
                    onPressed: _createTag,
                  ),
                ],
              ),
              const SizedBox(height: 10),
              if (tags.isEmpty)
                VeriCard(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 20),
                    child: Center(
                      child: Text(
                        AppLocalizations.of(context).tagsEmpty,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(
                            context,
                          ).colorScheme.onSurface.withValues(alpha: 0.5),
                        ),
                      ),
                    ),
                  ),
                )
              else
                VeriCard(
                  padding: EdgeInsets.zero,
                  child: ReorderableListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    buildDefaultDragHandles: false,
                    itemCount: tags.length,
                    onReorderItem: (oldIndex, newIndex) {
                      controller.reorderTags(oldIndex, newIndex);
                    },
                    itemBuilder: (context, index) {
                      final tag = tags[index];
                      return _TagManageRow(
                        key: ValueKey<String>(tag.id),
                        index: index,
                        tag: tag,
                        usageCount: controller.tagUsageCount(tag.id),
                        onTap: () => _showTagActions(tag),
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

  Future<void> _createTag() async {
    final label = await showTextInputDialog(
      context: context,
      title: AppLocalizations.of(context).tagAdd,
      label: AppLocalizations.of(context).tagNameLabel,
    );
    if (!mounted || label == null) {
      return;
    }
    VeriFinScope.of(context).addTag(label);
  }

  Future<void> _showTagActions(Tag tag) async {
    final selected = await showOptionSheet<String>(
      context: context,
      title: tag.label,
      values: const <String>['rename', 'delete'],
      selected: 'rename',
      showSelectedMarker: false,
      labelOf: (value) => switch (value) {
        'rename' => AppLocalizations.of(context).commonRename,
        'delete' => AppLocalizations.of(context).deleteTag,
        _ => value,
      },
    );
    if (!mounted || selected == null) {
      return;
    }
    switch (selected) {
      case 'rename':
        await _renameTag(tag);
      case 'delete':
        await _deleteTag(tag);
    }
  }

  Future<void> _renameTag(Tag tag) async {
    final label = await showTextInputDialog(
      context: context,
      title: AppLocalizations.of(context).tagRenameTitle,
      label: AppLocalizations.of(context).tagNameLabel,
      initialValue: tag.label,
    );
    if (!mounted || label == null) {
      return;
    }
    VeriFinScope.of(context).renameTag(tag.id, label);
  }

  Future<void> _deleteTag(Tag tag) async {
    final controller = VeriFinScope.of(context);
    final usage = controller.tagUsageCount(tag.id);
    final confirmed = await showConfirmDialog(
      context,
      title: AppLocalizations.of(context).tagDeleteTitle,
      message: usage > 0
          ? AppLocalizations.of(context).tagDeleteInUse(tag.label, usage)
          : AppLocalizations.of(context).tagDeleteMessage(tag.label),
      confirmLabel: AppLocalizations.of(context).commonDelete,
      destructive: true,
    );
    if (!mounted || !confirmed) {
      return;
    }
    controller.deleteTag(tag.id);
  }
}

class _TagManageRow extends StatelessWidget {
  const _TagManageRow({
    super.key,
    required this.index,
    required this.tag,
    required this.usageCount,
    required this.onTap,
  });

  final int index;
  final Tag tag;
  final int usageCount;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(veriRadiusSm),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
          child: Row(
            children: <Widget>[
              Icon(
                Icons.label,
                size: 22,
                color: veriRoyal.withValues(alpha: 0.75),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      tag.label,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      AppLocalizations.of(context).entriesCountFull(usageCount),
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: Theme.of(
                          context,
                        ).colorScheme.onSurface.withValues(alpha: 0.48),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              ReorderableDragStartListener(
                index: index,
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Icon(
                    Icons.drag_handle,
                    size: 18,
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurface.withValues(alpha: 0.38),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
