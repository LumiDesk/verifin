import 'dart:async';

import 'package:anchored_menu/anchored_menu.dart';
import 'package:flutter/material.dart';

import '../app/app_theme.dart';
import '../app/auto_save.dart';
import '../app/common_widgets.dart';
import '../app/feedback.dart';
import '../l10n/app_localizations.dart';
import '../app/models.dart';
import '../app/veri_fin_controller.dart';
import '../app/veri_fin_scope.dart';
import 'sheets.dart';

class TagManagementPage extends StatefulWidget {
  const TagManagementPage({super.key});

  @override
  State<TagManagementPage> createState() => _TagManagementPageState();
}

class _TagManagementPageState extends State<TagManagementPage> {
  late final AutoSave _autoSave = AutoSave(save: _saveOrder);
  bool _sorting = false;
  List<Tag> _draftTags = <Tag>[];

  @override
  void dispose() {
    _autoSave.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = VeriFinScope.of(context);
    final tags = _sorting ? _draftTags : controller.tags;

    return AutoSavePopScope(
      autoSave: _autoSave,
      child: Scaffold(
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
                    if (!_sorting)
                      HeaderAction(
                        icon: Icons.add,
                        tooltip: AppLocalizations.of(context).tagAdd,
                        onPressed: _createTag,
                      ),
                    if (_sorting)
                      HeaderAction(
                        icon: Icons.check,
                        tooltip: AppLocalizations.of(context).panelSortDone,
                        onPressed: _finishSorting,
                      )
                    else
                      HeaderAction(
                        icon: Icons.swap_vert,
                        tooltip: AppLocalizations.of(context).sortLabel,
                        onPressed: tags.length >= 2
                            ? () => _startSorting(controller)
                            : null,
                      ),
                  ],
                ),
                const SizedBox(height: 10),
                AutoSaveFailureBanner(autoSave: _autoSave),
                if (tags.isEmpty)
                  VeriCard(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 20),
                      child: Center(
                        child: Text(
                          AppLocalizations.of(context).tagsEmpty,
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(
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
                        if (_sorting) {
                          _reorderDraft(oldIndex, newIndex);
                        }
                      },
                      itemBuilder: (context, index) {
                        final tag = tags[index];
                        if (_sorting) {
                          return _TagManageRow(
                            key: ValueKey<String>(tag.id),
                            index: index,
                            tag: tag,
                            usageCount: controller.tagUsageCount(tag.id),
                            sorting: true,
                          );
                        }
                        return AnchoredMenuAnchor(
                          key: ValueKey<String>(tag.id),
                          entries: _tagMenuEntries(tag),
                          semanticLabel: tag.label,
                          builder: (context, openMenu, menuOpen) =>
                              _TagManageRow(
                                index: index,
                                tag: tag,
                                usageCount: controller.tagUsageCount(tag.id),
                                sorting: false,
                                onTap: openMenu,
                                onActions: openMenu,
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

  void _startSorting(VeriFinController controller) {
    setState(() {
      _sorting = true;
      _draftTags = List<Tag>.of(controller.tags);
    });
  }

  void _finishSorting() {
    setState(() {
      _sorting = false;
      _draftTags = <Tag>[];
    });
  }

  void _reorderDraft(int oldIndex, int newIndex) {
    if (oldIndex < 0 ||
        oldIndex >= _draftTags.length ||
        newIndex < 0 ||
        newIndex > _draftTags.length) {
      return;
    }
    setState(() {
      final moved = _draftTags.removeAt(oldIndex);
      _draftTags.insert(newIndex.clamp(0, _draftTags.length), moved);
    });
    _autoSave.schedule(immediate: true);
  }

  Future<bool> _saveOrder() => VeriFinScope.of(
    context,
  ).saveTagOrderDraft(_draftTags.map((tag) => tag.id).toList());

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

  List<AnchoredMenuEntry> _tagMenuEntries(Tag tag) {
    final l10n = AppLocalizations.of(context);
    return <AnchoredMenuEntry>[
      AnchoredMenuItem(
        id: 'tag_rename',
        icon: Icons.drive_file_rename_outline,
        title: l10n.commonRename,
        onPressed: () async => _renameTag(tag),
      ),
      const AnchoredMenuDivider(),
      AnchoredMenuItem(
        id: 'tag_delete',
        icon: Icons.delete_outline,
        title: l10n.deleteTag,
        foregroundColor: Theme.of(context).colorScheme.error,
        onPressed: () async => _deleteTag(tag),
      ),
    ];
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
    final controller = VeriFinScope.of(context);
    final l10n = AppLocalizations.of(context);
    final result = await controller.renameTag(tag.id, label);
    if (!mounted || result != RenameResult.duplicate) {
      return;
    }
    unawaited(
      VeriFeedbackHost.of(context).showMessage(
        message: l10n.tagNameDuplicate,
        tone: VeriFeedbackTone.warning,
      ),
    );
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
    await controller.deleteTag(tag.id);
  }
}

class _TagManageRow extends StatelessWidget {
  const _TagManageRow({
    super.key,
    required this.index,
    required this.tag,
    required this.usageCount,
    required this.sorting,
    this.onTap,
    this.onActions,
  });

  final int index;
  final Tag tag;
  final int usageCount;
  final bool sorting;
  final VoidCallback? onTap;
  final VoidCallback? onActions;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(veriRadiusSm),
        onTap: sorting ? null : onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
          child: Row(
            children: <Widget>[
              Icon(
                Icons.label,
                size: 22,
                color: Theme.of(
                  context,
                ).colorScheme.primary.withValues(alpha: 0.75),
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
              if (sorting)
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
                )
              else
                IconButton(
                  tooltip: tag.label,
                  onPressed: onActions,
                  icon: const Icon(Icons.more_vert),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
