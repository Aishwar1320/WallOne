import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:wallone/utils/constants.dart';
import 'package:wallone/common_widgets/dropdown_menu.dart';

class TransactionFilterControls extends StatelessWidget {
  final bool isExpensesSelected;
  final String selectedPeriod;
  final Function(bool) onTypeChanged;
  final Function(String?) onPeriodChanged;

  const TransactionFilterControls({
    super.key,
    required this.isExpensesSelected,
    required this.selectedPeriod,
    required this.onTypeChanged,
    required this.onPeriodChanged,
  });

  Map<String, String> _generateDateOptions({int days = 7}) {
    final now = DateTime.now();
    final keyFormat = DateFormat('yyyy-MM-dd');
    final displayFormat = DateFormat('MM-dd');

    final Map<String, String> options = {
      'All Transactions': 'All Transactions'
    };

    for (int i = 0; i < days; i++) {
      final date = now.subtract(Duration(days: i));
      final key = keyFormat.format(date);
      final label = i == 0 ? 'Today' : displayFormat.format(date);
      options[key] = label;
    }

    return options;
  }

  @override
  Widget build(BuildContext context) {
    final dateOptions = _generateDateOptions();
    final actualValue =
        selectedPeriod.isEmpty ? 'All Transactions' : selectedPeriod;

    return DropdownMenuDynamicWidget(
      boxColor: boxColor(context),
      hintText: '',
      value: actualValue,
      items: dateOptions.keys.toList(),
      itemDisplayMap: dateOptions, // Pass the display map
      customDisplayText: dateOptions[actualValue] ?? actualValue,
      onItemSelected: onPeriodChanged,
    );
  }
}
