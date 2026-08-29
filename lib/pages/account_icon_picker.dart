import 'package:flutter/material.dart';

import '../app/account_icon_assets.dart';
import '../app/app_theme.dart';
import '../app/common_widgets.dart';
import '../app/icon_catalog.dart';
import '../l10n/app_localizations.dart';

/// 账户图标选择器的具体实现；对外仍经 `sheets.dart` 的
/// `showAccountIconSheet` 稳定入口打开。
Future<String?> showAccountIconPickerSheet({
  required BuildContext context,
  required String selected,
}) {
  final l10n = AppLocalizations.of(context);
  final choices = <_AccountIconChoice>[
    for (final code in accountIconCodes)
      _AccountIconChoice(
        code: code,
        label: iconLabelForCode(l10n, code),
        groupKey: 'generic',
        groupLabel: l10n.iconGroupGeneric,
        searchTerms: <String>[code],
      ),
    for (final option in accountAssetIconOptions)
      _AccountIconChoice(
        code: option.code,
        label: option.label,
        groupKey: option.groupKey,
        groupLabel: option.groupLabel(l10n),
        searchTerms: option.searchTerms,
      ),
  ];

  return showModalBottomSheet<String>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    backgroundColor: Theme.of(context).colorScheme.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(veriRadiusLg)),
    ),
    builder: (context) =>
        _AccountIconPickerBody(selected: selected, choices: choices),
  );
}

class _AccountIconPickerBody extends StatefulWidget {
  const _AccountIconPickerBody({required this.selected, required this.choices});

  final String selected;
  final List<_AccountIconChoice> choices;

  @override
  State<_AccountIconPickerBody> createState() => _AccountIconPickerBodyState();
}

class _AccountIconPickerBodyState extends State<_AccountIconPickerBody> {
  static const _groupOrder = <String>['generic', 'credit', 'payment', 'bank'];

  final TextEditingController _searchController = TextEditingController();
  String _query = '';
  String _groupKey = 'all';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<_AccountIconChoice> get _searchResults => widget.choices
      .where((choice) => choice.matches(_query))
      .toList(growable: false);

  String _groupLabel(AppLocalizations l10n, String key) {
    if (key == 'all') {
      return l10n.allLabel;
    }
    return widget.choices
        .firstWhere((choice) => choice.groupKey == key)
        .groupLabel;
  }

  Widget _groupFilters(AppLocalizations l10n) {
    final keys = <String>['all', ..._groupOrder];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: <Widget>[
          for (final item in keys.indexed) ...<Widget>[
            ChoiceChip(
              key: Key('account_icon_group_${item.$2}'),
              label: Text(_groupLabel(l10n, item.$2)),
              selected: _groupKey == item.$2,
              showCheckmark: false,
              materialTapTargetSize: MaterialTapTargetSize.padded,
              selectedColor: veriRoyal.withValues(alpha: 0.14),
              onSelected: (_) => setState(() => _groupKey = item.$2),
            ),
            if (item.$1 < keys.length - 1) const SizedBox(width: 8),
          ],
        ],
      ),
    );
  }

  Widget _iconGrid(List<_AccountIconChoice> choices) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: EdgeInsets.zero,
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 90,
        mainAxisExtent: 90,
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
      ),
      itemCount: choices.length,
      itemBuilder: (context, index) {
        final choice = choices[index];
        final selected = choice.code == widget.selected;
        return Semantics(
          button: true,
          selected: selected,
          label: choice.label,
          child: Material(
            color: selected
                ? veriRoyal.withValues(alpha: 0.10)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(veriRadiusMd),
            child: InkWell(
              key: Key('account_icon_option_${choice.code}'),
              borderRadius: BorderRadius.circular(veriRadiusMd),
              onTap: () => Navigator.of(context).pop(choice.code),
              child: Container(
                padding: const EdgeInsets.fromLTRB(4, 8, 4, 5),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(veriRadiusMd),
                  border: Border.all(
                    color: selected
                        ? veriRoyal
                        : Theme.of(
                            context,
                          ).colorScheme.onSurface.withValues(alpha: 0.10),
                    width: selected ? 2 : 1,
                  ),
                ),
                child: Stack(
                  children: <Widget>[
                    Align(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          AccountIconBox(iconCode: choice.code, size: 36),
                          const SizedBox(height: 5),
                          Flexible(
                            child: Text(
                              choice.label,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.center,
                              style: Theme.of(context).textTheme.labelSmall
                                  ?.copyWith(
                                    fontWeight: selected
                                        ? FontWeight.w800
                                        : FontWeight.w600,
                                  ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (selected)
                      const Positioned(
                        top: 0,
                        right: 0,
                        child: Icon(
                          Icons.check_circle,
                          size: 15,
                          color: veriRoyal,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _browseIcons(AppLocalizations l10n) {
    final keys = _groupKey == 'all' ? _groupOrder : <String>[_groupKey];
    return ListView(
      padding: const EdgeInsets.only(bottom: 4),
      children: <Widget>[
        for (final key in keys) ...<Widget>[
          Padding(
            padding: const EdgeInsets.only(top: 12, bottom: 8),
            child: Text(
              _groupLabel(l10n, key),
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: Theme.of(
                  context,
                ).colorScheme.onSurface.withValues(alpha: 0.58),
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          _iconGrid(
            widget.choices
                .where((choice) => choice.groupKey == key)
                .toList(growable: false),
          ),
        ],
      ],
    );
  }

  Widget _searchIcons(AppLocalizations l10n) {
    final results = _searchResults;
    if (results.isEmpty) {
      return EmptyState(
        icon: Icons.search_off,
        title: l10n.accountIconSearchEmpty,
        description: l10n.accountIconSearchEmptyDesc,
      );
    }
    return ListView.separated(
      itemCount: results.length,
      separatorBuilder: (_, _) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final choice = results[index];
        final selected = choice.code == widget.selected;
        return ListTile(
          key: Key('account_icon_search_result_${choice.code}'),
          minTileHeight: 52,
          contentPadding: const EdgeInsets.symmetric(horizontal: 8),
          leading: AccountIconBox(iconCode: choice.code, size: 36),
          title: Text(
            choice.label,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
            ),
          ),
          subtitle: Text(choice.groupLabel),
          trailing: selected
              ? const Icon(Icons.check_circle, color: veriRoyal, size: 18)
              : null,
          onTap: () => Navigator.of(context).pop(choice.code),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final searchActive = normalizeAccountIconSearch(_query).isNotEmpty;
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          14,
          0,
          14,
          16 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: SizedBox(
          height: MediaQuery.sizeOf(context).height * 0.80,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                l10n.accountIconPickerTitle,
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 10),
              TextField(
                key: const Key('account_icon_search_field'),
                controller: _searchController,
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.search),
                  hintText: l10n.accountIconSearchHint,
                  suffixIcon: _query.isEmpty
                      ? null
                      : IconButton(
                          tooltip: l10n.commonClear,
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _query = '');
                          },
                          icon: const Icon(Icons.close),
                        ),
                ),
                onChanged: (value) => setState(() {
                  _query = value;
                  if (value.trim().isNotEmpty) {
                    _groupKey = 'all';
                  }
                }),
              ),
              const SizedBox(height: 10),
              _groupFilters(l10n),
              const SizedBox(height: 2),
              Expanded(
                child: searchActive ? _searchIcons(l10n) : _browseIcons(l10n),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AccountIconChoice {
  const _AccountIconChoice({
    required this.code,
    required this.label,
    required this.groupKey,
    required this.groupLabel,
    required this.searchTerms,
  });

  final String code;
  final String label;
  final String groupKey;
  final String groupLabel;
  final List<String> searchTerms;

  bool matches(String query) {
    final normalized = normalizeAccountIconSearch(query);
    if (normalized.isEmpty) {
      return true;
    }
    return <String>[
      label,
      groupLabel,
      code,
      ...searchTerms,
    ].any((term) => normalizeAccountIconSearch(term).contains(normalized));
  }
}
