import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:wallone/utils/constants.dart';
import 'package:wallone/widgets/dropdown_menu.dart';

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
    final dateFormat = DateFormat('dd-MM');

    // Include 'All Dates' first
    Map<String, String> options = {'All Dates': 'All Dates'};

    for (int i = 0; i < days; i++) {
      final date = now.subtract(Duration(days: i));
      final formatted = dateFormat.format(date);
      final label = i == 0 ? 'Today' : formatted;
      options[formatted] = label;
    }

    return options;
  }

  @override
  Widget build(BuildContext context) {
    final dateOptions = _generateDateOptions();

    return DropdownMenuDynamicWidget(
      boxColor: boxColor(context),
      hintText: '', // Remove the "Select Date" label completely
      value: selectedPeriod.isEmpty ? 'All Dates' : selectedPeriod,
      items: dateOptions.keys.toList(),
      customDisplayText: dateOptions[selectedPeriod] ?? selectedPeriod,
      onItemSelected: onPeriodChanged,
    );
  }
}
