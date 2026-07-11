import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:wallone/features/investments/models/investment_model.dart';
import 'package:wallone/features/budget/providers/budget_provider.dart';
import 'package:wallone/features/investments/providers/investment_provider.dart';
import 'package:wallone/core/utils/animations.dart';
import 'package:wallone/core/utils/constants.dart';
import 'package:wallone/shared/widgets/custom_text_field.dart';

// ─── Shared helpers ───────────────────────────────────────────────────────────

/// Standard dialog card decoration.
BoxDecoration _dialogDecoration(BuildContext context) => BoxDecoration(
      color: boxColor(context),
      borderRadius: BorderRadius.circular(28),
      boxShadow: [_cardShadow(context)],
    );

/// Subtle card shadow used throughout the dialogs.
BoxShadow _cardShadow(BuildContext context) => BoxShadow(
      color: shadowColor(context).withValues(alpha: 0.1),
      blurRadius: 10,
      offset: const Offset(0, 4),
    );

/// Outfit text helper – avoids repeating `GoogleFonts.outfit(...)` everywhere.
TextStyle _outfit({
  double? fontSize,
  FontWeight fontWeight = FontWeight.normal,
  Color? color,
}) =>
    GoogleFonts.outfit(
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
    );

/// Standard fade + scale transition used for all `showGeneralDialog` calls.
Widget _dialogTransition(
  BuildContext ctx,
  Animation<double> anim,
  Animation<double> secondary,
  Widget child,
) =>
    FadeTransition(
      opacity: CurvedAnimation(parent: anim, curve: Curves.easeOut),
      child: ScaleTransition(
        scale: CurvedAnimation(parent: anim, curve: Curves.easeOutBack),
        child: child,
      ),
    );

/// Wraps content in the standard dialog `Dialog` + `Container` shell.
Widget _dialogShell(BuildContext context, {required Widget child}) => Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      child: Container(
        padding: const EdgeInsets.all(28),
        decoration: _dialogDecoration(context),
        child: child,
      ),
    );

/// Icon + title header row shared by all dialogs.
Widget _dialogHeader({
  required BuildContext context,
  required Widget icon,
  required String title,
  double? fontSize,
}) =>
    Row(
      children: [
        icon,
        const SizedBox(width: 12),
        Text(
          title,
          style: _outfit(
            fontSize: fontSize ?? 24,
            fontWeight: FontWeight.bold,
            color: fontSize != null ? primaryColor(context) : null,
          ),
        ),
      ],
    );

/// Rounded icon badge used in dialog headers.
Widget _iconBadge({required List<Color> gradientColors, required IconData icon}) =>
    Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: gradientColors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(icon, color: Colors.white, size: 20),
    );

/// Circular icon badge (used for simple info/delete alerts).
Widget _circleBadge({required Color bgColor, required Color iconColor, required IconData icon}) =>
    Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: bgColor, shape: BoxShape.circle),
      child: Icon(icon, color: iconColor, size: 32),
    );

/// Full-width `ElevatedButton` with the standard dialog styling.
Widget _primaryButton({
  required BuildContext context,
  required String label,
  required VoidCallback onPressed,
  Color? bgColor,
  Color? fgColor,
  double fontSize = 16,
}) =>
    SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 16),
          backgroundColor: bgColor ?? primaryColor(context),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          elevation: 4,
          shadowColor: (bgColor ?? primaryColor(context)).withValues(alpha: 0.4),
        ),
        child: Text(
          label,
          style: _outfit(
            fontSize: fontSize,
            fontWeight: FontWeight.w600,
            color: fgColor ?? Colors.white,
          ),
        ),
      ),
    );

/// Full-width `TextButton` cancel button.
Widget _cancelButton({
  required BuildContext context,
  required VoidCallback onPressed,
  double fontSize = 16,
}) =>
    TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      child: Text(
        'Cancel',
        style: _outfit(fontSize: fontSize, fontWeight: FontWeight.w600),
      ),
    );

/// Two-button row: Cancel on the left, primary action on the right.
Widget _dialogActions({
  required BuildContext context,
  required Widget primaryAction,
  double fontSize = 16,
}) =>
    Row(
      children: [
        Expanded(child: _cancelButton(context: context, onPressed: () => Navigator.pop(context), fontSize: fontSize)),
        const SizedBox(width: 16),
        Expanded(child: primaryAction),
      ],
    );

// ─── Type-toggle tab ──────────────────────────────────────────────────────────

class _TypeTab extends StatelessWidget {
  const _TypeTab({
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.onTap,
    required this.context,
  });

  final String label;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;
  final BuildContext context;

  @override
  Widget build(BuildContext ctx) {
    final color = isSelected ? inversePrimaryColor(context) : primaryColor(context);
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? primaryColor(context) : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 18, color: color),
              const SizedBox(width: 8),
              Text(label, style: _outfit(fontWeight: FontWeight.w600, color: color)),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Amount validator (shared) ────────────────────────────────────────────────

String? _validateAmount(String? value) {
  if (value == null || value.trim().isEmpty) return 'Please enter an amount';
  final amount = double.tryParse(value);
  if (amount == null || amount <= 0) return 'Enter a valid amount greater than 0';
  return null;
}

// ─── InvestmentDialogs ────────────────────────────────────────────────────────

class InvestmentDialogs {
  static void showAddInvestmentDialog(
      BuildContext context, void Function(void Function()) setState) {
    final budgetProvider = Provider.of<BudgetProvider>(context, listen: false);
    final totalBalance = budgetProvider.totalBalance;
    final screenWidth = MediaQuery.of(context).size.width;

    // ── Insufficient balance guard ──
    if (totalBalance <= 0) {
      showGeneralDialog(
        context: context,
        barrierDismissible: true,
        barrierLabel: "Insufficient Balance",
        barrierColor: Colors.black54,
        transitionDuration: const Duration(milliseconds: 300),
        transitionBuilder: _dialogTransition,
        pageBuilder: (ctx, _, __) => _dialogShell(
          context,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _circleBadge(
                bgColor: Colors.orange.shade50,
                iconColor: Colors.orange.shade400,
                icon: Icons.trending_up,
              ),
              const SizedBox(height: 24),
              Text('Insufficient Balance',
                  style: _outfit(fontSize: 24, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              Text(
                'You need to have some balance in your account before making investments.',
                textAlign: TextAlign.center,
                style: _outfit(fontSize: 16, color: cardTextColor(context)),
              ),
              const SizedBox(height: 28),
              _primaryButton(
                context: context,
                label: 'Got It',
                onPressed: () => Navigator.pop(context),
                bgColor: Theme.of(context).primaryColor,
              ),
            ],
          ),
        ),
      );
      return;
    }

    // ── Add Investment form ──
    final nameController = TextEditingController();
    final amountController = TextEditingController();
    String selectedCategory = 'Stocks';
    String selectedType = 'Fixed Investment';
    DateTime selectedDate = DateTime.now();

    final formKey = GlobalKey<FormState>();

    showGeneralDialog(
      context: context,
      barrierDismissible: false,
      barrierLabel: "Add Investment",
      barrierColor: Colors.black54,
      transitionDuration: const Duration(milliseconds: 300),
      transitionBuilder: _dialogTransition,
      pageBuilder: (ctx, anim1, __) => _dialogShell(
        context,
        child: Consumer<BudgetProvider>(
          builder: (context, provider, _) {
            if (provider.showDateTimePicker) {
              // ── Date & time picker view ──
              final pickerKey = ValueKey(selectedDate.millisecondsSinceEpoch);
              return ScaleTransition(
                scale: CurvedAnimation(parent: anim1, curve: Curves.elasticOut),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _dialogHeader(
                      context: context,
                      fontSize: screenWidth / 20,
                      title: 'Select Date & Time',
                      icon: IconButton(
                        style: IconButton.styleFrom(
                          backgroundColor: primaryColor(context),
                          foregroundColor: inversePrimaryColor(context),
                        ),
                        icon: const Icon(Icons.arrow_back),
                        onPressed: provider.toggleDateTimePicker,
                      ),
                    ),
                    const SizedBox(height: 28),
                    CupertinoTheme(
                      data: CupertinoThemeData(
                        textTheme: CupertinoTextThemeData(
                          dateTimePickerTextStyle: _outfit(
                            fontSize: screenWidth / 25,
                            color: cardTextColor(context),
                          ),
                        ),
                      ),
                      child: Column(
                        children: [
                          Container(
                            height: 200,
                            decoration: BoxDecoration(
                              color: boxColor(context),
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [_cardShadow(context)],
                            ),
                            child: CupertinoDatePicker(
                              key: pickerKey,
                              mode: CupertinoDatePickerMode.dateAndTime,
                              initialDateTime: provider.selectedInvestmentDate,
                              onDateTimeChanged: (dt) {
                                provider.updateInvestmentDateTime(dt);
                                setState(() {});
                              },
                            ),
                          ),
                          const SizedBox(height: 16),
                          DialogBoxFadeTransition(
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: boxColor(context),
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: [_cardShadow(context)],
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    '${provider.selectedInvestmentDate.toLocal().toString().split(' ')[0].replaceAll('-', '/')}  ${provider.selectedInvestmentTime.format(context)}',
                                    style: _outfit(
                                      fontSize: screenWidth / 30,
                                      color: primaryColor(context),
                                    ),
                                  ),
                                  const Spacer(),
                                  IconButton(
                                    iconSize: screenWidth / 15,
                                    icon: const Icon(Icons.refresh),
                                    color: Colors.redAccent,
                                    tooltip: 'Reset date & time',
                                    onPressed: () {
                                      setState(() => selectedDate = DateTime.now());
                                      provider.updateInvestmentDateTime(DateTime.now());
                                    },
                                  ),
                                  IconButton(
                                    iconSize: screenWidth / 15,
                                    icon: const Icon(Icons.check_circle_outline),
                                    color: primaryColor(context),
                                    onPressed: () {
                                      selectedDate = DateTime(
                                        provider.selectedInvestmentDate.year,
                                        provider.selectedInvestmentDate.month,
                                        provider.selectedInvestmentDate.day,
                                        provider.selectedInvestmentTime.hour,
                                        provider.selectedInvestmentTime.minute,
                                      );
                                      provider.toggleDateTimePicker();
                                    },
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }

            // ── Main form view ──
            return Form(
              key: formKey,
              child: SingleChildScrollView(
                child: StatefulBuilder(
                  builder: (context, setStateType) => Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _dialogHeader(
                        context: context,
                        fontSize: screenWidth / 20,
                        title: 'Add New Investment',
                        icon: _iconBadge(
                          gradientColors: [
                            Colors.deepPurple.shade700,
                            Colors.deepPurple.shade900,
                          ],
                          icon: Icons.savings_outlined,
                        ),
                      ),
                      const SizedBox(height: 28),

                      // Type toggle
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: budgetBackgroundLight(context),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Row(
                          children: [
                            _TypeTab(
                              context: context,
                              label: 'Fixed',
                              icon: Icons.trending_up,
                              isSelected: selectedType == 'Fixed Investment',
                              onTap: () => setStateType(() {
                                selectedType = 'Fixed Investment';
                                selectedCategory = 'Stocks';
                              }),
                            ),
                            _TypeTab(
                              context: context,
                              label: 'One-time',
                              icon: Icons.savings_outlined,
                              isSelected: selectedType == 'One-time Savings',
                              onTap: () => setStateType(() {
                                selectedType = 'One-time Savings';
                                selectedCategory = 'Savings';
                              }),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),

                      Row(
                        children: [
                          Expanded(
                            child: CustomTextField(
                              controller: nameController,
                              labelText: selectedType == 'One-time Savings'
                                  ? 'Savings Name'
                                  : 'Investment Name',
                              prefixIcon: Icons.label_outline,
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) {
                                  return selectedType == 'One-time Savings'
                                      ? 'Please enter a savings name'
                                      : 'Please enter an investment name';
                                }
                                return null;
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                          Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [_cardShadow(context)],
                            ),
                            child: IconButton.filled(
                              style: IconButton.styleFrom(
                                backgroundColor: budgetBackgroundLight(context),
                                foregroundColor: primaryColor(context),
                              ),
                              icon: const Icon(Icons.calendar_today),
                              onPressed: provider.toggleDateTimePicker,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),

                      CustomTextField(
                        controller: amountController,
                        labelText: 'Amount',
                        prefixIcon: Icons.attach_money,
                        keyboardType: TextInputType.number,
                        validator: _validateAmount,
                      ),
                      const SizedBox(height: 48),

                      _dialogActions(
                        context: context,
                        fontSize: screenWidth / 30,
                        primaryAction: _primaryButton(
                          context: context,
                          label: selectedType == 'One-time Savings'
                              ? 'Add Savings'
                              : 'Add Investment',
                          fontSize: screenWidth / 30,
                          fgColor: inversePrimaryColor(context),
                          onPressed: () {
                            if (formKey.currentState!.validate()) {
                              context.read<InvestmentProvider>().addInvestment(
                                    nameController.text,
                                    double.parse(amountController.text),
                                    category: selectedCategory,
                                    startDate: DateTime(
                                      provider.selectedInvestmentDate.year,
                                      provider.selectedInvestmentDate.month,
                                      provider.selectedInvestmentDate.day,
                                      provider.selectedInvestmentTime.hour,
                                      provider.selectedInvestmentTime.minute,
                                    ),
                                    isOneTime:
                                        selectedType == 'One-time Savings',
                                  );
                              Navigator.pop(context);
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  static void showEditInvestmentDialog(
      BuildContext context, InvestmentModel investment, int index) {
    final amountController =
        TextEditingController(text: investment.amount.toString());
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (context) => _dialogShell(
        context,
        child: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _dialogHeader(
                context: context,
                title: investment.isOneTime ?? false
                    ? 'Edit Savings'
                    : 'Edit Investment',
                icon: _iconBadge(
                  gradientColors: [
                    Colors.blue.shade700,
                    Colors.blue.shade900,
                  ],
                  icon: Icons.edit_outlined,
                ),
              ),
              const SizedBox(height: 28),
              Text(
                'Name: ${investment.name}',
                style: _outfit(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: primaryColor(context).withValues(alpha: 0.7),
                ),
              ),
              const SizedBox(height: 32),
              CustomTextField(
                controller: amountController,
                labelText: 'Amount',
                prefixIcon: Icons.attach_money,
                keyboardType: TextInputType.number,
                validator: _validateAmount,
              ),
              const SizedBox(height: 28),
              _dialogActions(
                context: context,
                primaryAction: _primaryButton(
                  context: context,
                  label: 'Save Changes',
                  bgColor: Theme.of(context).primaryColor,
                  onPressed: () {
                    if (formKey.currentState!.validate()) {
                      context
                          .read<InvestmentProvider>()
                          .updateInvestmentAmount(
                              index, double.parse(amountController.text));
                      Navigator.pop(context);
                    }
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static void showDeleteConfirmation(
      BuildContext context, InvestmentModel investment, int index) {
    final isOneTime = investment.isOneTime ?? false;
    showDialog(
      context: context,
      builder: (context) => _dialogShell(
        context,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _circleBadge(
              bgColor: Colors.red.shade50,
              iconColor: Colors.red.shade400,
              icon: Icons.delete_outline,
            ),
            const SizedBox(height: 24),
            Text(
              isOneTime ? 'Delete Savings' : 'Delete Investment',
              style: _outfit(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Text(
              'Are you sure you want to delete this ${isOneTime ? "savings" : "investment"}? This action cannot be undone.',
              textAlign: TextAlign.center,
              style: _outfit(fontSize: 16, color: cardTextColor(context)),
            ),
            const SizedBox(height: 28),
            _dialogActions(
              context: context,
              primaryAction: _primaryButton(
                context: context,
                label: 'Delete',
                bgColor: Colors.red.shade400,
                onPressed: () {
                  Provider.of<InvestmentProvider>(context, listen: false)
                      .removeInvestment(index);
                  Navigator.pop(context);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
