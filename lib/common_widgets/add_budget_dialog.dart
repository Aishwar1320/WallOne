import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:wallone/state/budget_provider.dart';
import 'package:wallone/state/category_provider.dart';
import 'package:wallone/common_widgets/dropdown_menu.dart';
import 'package:wallone/common_widgets/custom_text_field.dart';
import 'package:wallone/utils/constants.dart';

void showAddBudgetDialog(BuildContext context, {Budget? budget}) {
  showDialog(
    context: context,
    builder: (context) => Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(28),
      ),
      child: BudgetDialogWidget(budget: budget),
    ),
  );
}

class BudgetDialogWidget extends StatefulWidget {
  final Budget? budget;

  const BudgetDialogWidget({super.key, this.budget});

  @override
  State<BudgetDialogWidget> createState() => _BudgetDialogWidgetState();
}

class _BudgetDialogWidgetState extends State<BudgetDialogWidget> {
  late final TextEditingController _amountController;
  String? _selectedCategory;

  @override
  void initState() {
    super.initState();
    _amountController = TextEditingController();
    if (widget.budget != null) {
      _amountController.text = widget.budget!.amount.toString();
      _selectedCategory = widget.budget!.category;
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.budget != null;

    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: boxColor(context),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: shadowColor(context).withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.deepPurple.shade700,
                      Colors.deepPurple.shade900,
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  isEditing ? Icons.edit : Icons.add_chart,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                isEditing ? 'Edit Budget' : 'Add New Budget',
                style: GoogleFonts.outfit(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 28),
          Consumer<CategoryProvider>(
            builder: (context, categoryProvider, child) {
              final categories = categoryProvider.categories;
              return DropdownMenuDynamicWidget(
                boxColor: boxColor(context),
                hintText: "Select Category",
                onItemSelected: (value) {
                  setState(() {
                    _selectedCategory = value;
                  });
                },
                items: categories.map((c) => c.name).toList(),
                value: _selectedCategory,
              );
            },
          ),
          const SizedBox(height: 20),
          CustomTextField(
            controller: _amountController,
            labelText: 'Budget Amount',
            prefixIcon: Icons.attach_money,
            keyboardType: TextInputType.number,
          ),
          const SizedBox(height: 28),
          Row(
            children: [
              Expanded(
                child: TextButton(
                  onPressed: () => Navigator.pop(context),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: Text(
                    'Cancel',
                    style: GoogleFonts.outfit(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: ElevatedButton(
                  onPressed: () async {
                    if ((_selectedCategory == null) ||
                        _amountController.text.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                          content: Text(
                              'Please select a category and enter an amount')));
                      return;
                    }

                    final amount = double.tryParse(_amountController.text);
                    if (amount == null) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                          content: Text('Enter a valid numeric amount')));
                      return;
                    }

                    if (amount <= 0) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                          content: Text('Amount must be greater than zero')));
                      return;
                    }

                    final categoryProvider = context.read<CategoryProvider>();
                    final iconKey =
                        categoryProvider.getIconForCategory(_selectedCategory!);
                    final budgetProvider = context.read<BudgetProvider>();

                    bool success;
                    if (isEditing && widget.budget!.id.isNotEmpty) {
                      success = await budgetProvider.updateBudget(
                        widget.budget!.id,
                        _selectedCategory!,
                        amount,
                        iconKey,
                      );
                    } else {
                      success = await budgetProvider.addBudget(
                        _selectedCategory!,
                        amount,
                        iconKey,
                      );
                    }

                    if (success && context.mounted) {
                      Navigator.pop(context);
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    backgroundColor: Theme.of(context).primaryColor,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 4,
                    shadowColor:
                        Theme.of(context).primaryColor.withValues(alpha: 0.4),
                  ),
                  child: Text(
                    isEditing ? 'Update Budget' : 'Add Budget',
                    style: GoogleFonts.outfit(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

