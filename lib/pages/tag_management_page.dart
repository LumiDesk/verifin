import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter/material.dart';

import '../app/app_theme.dart';
import '../app/common_widgets.dart';
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
  bool _sorting = false;
  bool _savingOrder = false;
  List<Tag> _draftTags = <Tag>[];
  List<String> _initialOrder = <String>[];

  @override
  Widget build(BuildContext context) {
    final controller = VeriFinScope.of(context);
    final tags = _sorting ? _draftTags : controller.tags;

    return UnsavedChangesGuard(
      isDirty: _isOrderDirty,
      onSave: _saveOrder,
      onDiscard: _discardOrder,
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
                    SortModeHeaderActions(
                      sorting: _sorting,
                      canSort: tags.length >= 2,
                      dirty: _isOrderDirty,
                      onStart: () => _startSorting(controller),
                      onCancel: _cancelSorting,
                      onSave: _saveOrderAndFinish,
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
                        return _TagManageRow(
                          key: ValueKey<String>(tag.id),
                          index: index,
                          tag: tag,
                          usageCount: controller.tagUsageCount(tag.id),
                          sorting: _sorting,
                          onTap: () => _showTagActions(tag),
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

  bool get _isOrderDirty =>
      _sorting &&
      !listEquals(_draftTags.map((tag) => tag.id).toList(), _initialOrder);

  void _startSorting(VeriFinController controller) {
    setState(() {
      _sorting = true;
      _draftTags = List<Tag>.of(controller.tags);
      _initialOrder = _draftTags.map((tag) => tag.id).toList();
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
  }

  Future<bool> _saveOrder() async {
    if (_savingOrder || !_isOrderDirty) {
      return !_isOrderDirty;
    }
    _savingOrder = true;
    final saved = await VeriFinScope.of(
      context,
    ).saveTagOrderDraft(_draftTags.map((tag) => tag.id).toList());
    _savingOrder = false;
    return saved;
  }

  Future<void> _saveOrderAndFinish() async {
    if (await _saveOrder() && mounted) {
      setState(_discardOrder);
    }
  }

  void _discardOrder() {
    _sorting = false;
    _draftTags = <Tag>[];
    _initialOrder = <String>[];
  }

  Future<void> _cancelSorting() async {
    if (!_isOrderDirty) {
      setState(_discardOrder);
      return;
    }
    final decision = await showUnsavedChangesDialog(context: context);
    if (!mounted) {
      return;
    }
    switch (decision) {
      case EditorExitDecision.save:
        await _saveOrderAndFinish();
      case EditorExitDecision.discard:
        setState(_discardOrder);
      case EditorExitDecision.cancel:
        break;
    }
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
    required this.sorting,
    required this.onTap,
  });

  final int index;
  final Tag tag;
  final int usageCount;
  final bool sorting;
  final VoidCallback onTap;

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
                ),
            ],
          ),
        ),
      ),
    );
  }
}
