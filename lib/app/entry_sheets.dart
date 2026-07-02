import 'package:flutter/material.dart';

import 'app_theme.dart';
import 'ledger_math.dart';
import 'models.dart';

class NumberPadSheet extends StatefulWidget {
  const NumberPadSheet({super.key, required this.title, this.initialAmount});

  final String title;
  final double? initialAmount;

  @override
  State<NumberPadSheet> createState() => _NumberPadSheetState();
}

class _NumberPadSheetState extends State<NumberPadSheet> {
  late String _input = widget.initialAmount == null
      ? ''
      : formatAmount(widget.initialAmount!);

  double get _amount => double.tryParse(_input) ?? 0;

  @override
  Widget build(BuildContext context) {
    final keys = <String>[
      '1',
      '2',
      '3',
      '⌫',
      '4',
      '5',
      '6',
      'C',
      '7',
      '8',
      '9',
      '.',
      '0',
      '00',
      '',
      'OK',
    ];

    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        0,
        20,
        20 + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(widget.title, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Text(
              _input.isEmpty ? '0' : _input,
              textAlign: TextAlign.end,
              style: Theme.of(
                context,
              ).textTheme.displaySmall?.copyWith(fontWeight: FontWeight.w800),
            ),
          ),
          const SizedBox(height: 14),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 4,
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: 2.2,
            ),
            itemCount: keys.length,
            itemBuilder: (context, index) {
              final value = keys[index];
              if (value.isEmpty) {
                return const SizedBox.shrink();
              }

              final isOk = value == 'OK';
              return FilledButton.tonal(
                key: isOk
                    ? const Key('number_pad_ok')
                    : Key('number_key_$value'),
                style: FilledButton.styleFrom(
                  backgroundColor: isOk ? veriBlue : null,
                  foregroundColor: isOk ? Colors.white : null,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                onPressed: isOk && _amount <= 0
                    ? null
                    : () => _handleKey(value),
                child: value == '⌫'
                    ? const Icon(Icons.backspace_outlined)
                    : Text(
                        value,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
              );
            },
          ),
        ],
      ),
    );
  }

  void _handleKey(String value) {
    if (value == 'OK') {
      Navigator.of(context).pop(_amount);
      return;
    }

    setState(() {
      if (value == 'C') {
        _input = '';
        return;
      }
      if (value == '⌫') {
        if (_input.isNotEmpty) {
          _input = _input.substring(0, _input.length - 1);
        }
        return;
      }
      if (value == '.') {
        if (_input.contains('.')) {
          return;
        }
        _input = _input.isEmpty ? '0.' : '$_input.';
        return;
      }
      if (_input.contains('.')) {
        final decimalLength = _input.split('.').last.length;
        if (decimalLength >= 2) {
          return;
        }
      }
      if (_input == '0' && value != '00') {
        _input = value;
      } else {
        _input = '$_input$value';
      }
    });
  }
}

class CategoryPickerSheet extends StatelessWidget {
  const CategoryPickerSheet({
    super.key,
    required this.categories,
    required this.selectedId,
  });

  final List<Category> categories;
  final String selectedId;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text('全部分类', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 14),
          GridView.count(
            crossAxisCount: 3,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 2.6,
            children: categories
                .map(
                  (category) => ChoiceChip(
                    avatar: Icon(category.icon, size: 18),
                    label: Text(category.label),
                    selected: category.id == selectedId,
                    onSelected: (_) => Navigator.of(context).pop(category.id),
                  ),
                )
                .toList(),
          ),
        ],
      ),
    );
  }
}
