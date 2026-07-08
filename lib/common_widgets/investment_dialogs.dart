import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:wallone/models/investment_model.dart';
import 'package:wallone/state/budget_provider.dart';
import 'package:wallone/state/investment_provider.dart';
import 'package:wallone/utils/animations.dart';
import 'package:wallone/utils/constants.dart';
import 'package:wallone/common_widgets/custom_text_field.dart';

class InvestmentDialogs {
  static void showAddInvestmentDialog(BuildContext context, void Function(void Function()) setState) {
    final budgetProvider = Provider.of<BudgetProvider>(context, listen: false);
    final totalBalance = budgetProvider.totalBalance;
    final screenWidth = MediaQuery.of(context).size.width;

    bool dateConfirmed = false;

    if (totalBalance <= 0) {
      showGeneralDialog(
        context: context,
        barrierDismissible: true,
        barrierLabel: "Insufficient Balance",
        barrierColor: Colors.black54,
        transitionDuration: const Duration(milliseconds: 300),
        transitionBuilder: (ctx, anim, secondaryAnim, child) {
          return FadeTransition(
            opacity: CurvedAnimation(parent: anim, curve: Curves.easeOut),
            child: ScaleTransition(
              scale: CurvedAnimation(parent: anim, curve: Curves.easeOutBack),
              child: child,
            ),
          );
        },
        pageBuilder: (ctx, anim1, anim2) => Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(28),
          ),
          child: Container(
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
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.trending_up,
                    color: Colors.orange.shade400,
                    size: 32,
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  'Insufficient Balance',
                  style: GoogleFonts.outfit(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'You need to have some balance in your account before making investments.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.outfit(
                    fontSize: 16,
                    color: cardTextColor(context),
                  ),
                ),
                const SizedBox(height: 28),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context),
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
                      'Got It',
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
          ),
        ),
      );
      return;
    }

    final TextEditingController nameController = TextEditingController();
    final TextEditingController amountController = TextEditingController();
    String selectedCategory = 'Stocks'; // Default category
    String selectedType = 'Fixed Investment'; // Default type
    DateTime? selectedDate;
    TimeOfDay? selectedTime;

    selectedDate ??= DateTime.now();
    selectedTime ??= TimeOfDay.fromDateTime(selectedDate);

    final formKey = GlobalKey<FormState>();

    showGeneralDialog(
      context: context,
      barrierDismissible: false,
      barrierLabel: "Add Investment",
      barrierColor: Colors.black54,
      transitionDuration: const Duration(milliseconds: 300),
      transitionBuilder: (ctx, anim, secondaryAnim, child) {
        return FadeTransition(
          opacity: CurvedAnimation(parent: anim, curve: Curves.easeOut),
          child: ScaleTransition(
            scale: CurvedAnimation(parent: anim, curve: Curves.easeOutBack),
            child: child,
          ),
        );
      },
      pageBuilder: (ctx, anim1, anim2) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(28),
        ),
        child: Container(
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
          child: Consumer<BudgetProvider>(
            builder: (context, provider, _) {
              if (provider.showDateTimePicker) {
                final pickerKey =
                    ValueKey(selectedDate?.millisecondsSinceEpoch ?? 0);
                return ScaleTransition(
                  scale: CurvedAnimation(
                    parent: anim1,
                    curve: Curves.elasticOut,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          IconButton(
                            style: IconButton.styleFrom(
                              backgroundColor: purpleColors(context),
                              foregroundColor: Colors.white,
                            ),
                            icon: const Icon(Icons.arrow_back),
                            onPressed: () {
                              provider.toggleDateTimePicker();
                            },
                          ),
                          const SizedBox(width: 12),
                          Text(
                            'Select Date & Time',
                            style: GoogleFonts.outfit(
                              fontSize: screenWidth / 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 28),
                      CupertinoTheme(
                        data: CupertinoThemeData(
                          textTheme: CupertinoTextThemeData(
                            dateTimePickerTextStyle: GoogleFonts.outfit(
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
                                boxShadow: [
                                  BoxShadow(
                                    color:
                                        shadowColor(context).withValues(alpha: 0.1),
                                    blurRadius: 10,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: CupertinoDatePicker(
                                key: pickerKey,
                                mode: CupertinoDatePickerMode.dateAndTime,
                                initialDateTime:
                                    provider.selectedInvestmentDate,
                                onDateTimeChanged: (DateTime newDateTime) {
                                  provider
                                      .updateInvestmentDateTime(newDateTime);

                                  setState(() {
                                    dateConfirmed = false;
                                  });
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
                                  boxShadow: [
                                    BoxShadow(
                                      color:
                                          shadowColor(context).withValues(alpha: 0.1),
                                      blurRadius: 10,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      '${'${provider.selectedInvestmentDate.toLocal()}'.split(' ')[0].replaceAll('-', '/')}  ${provider.selectedInvestmentTime.format(context)}',
                                      style: GoogleFonts.outfit(
                                        fontSize: screenWidth / 30,
                                        color: cardTextColor(context),
                                      ),
                                    ),
                                    const Spacer(),
                                    IconButton(
                                      iconSize: screenWidth / 15,
                                      icon: const Icon(Icons.refresh),
                                      color: Colors.redAccent,
                                      tooltip: 'Reset date & time',
                                      onPressed: () {
                                        setState(() {
                                          selectedDate = null;
                                          selectedTime = null;
                                          dateConfirmed = false;
                                        });
                                        provider.updateInvestmentDateTime(
                                          DateTime.now(),
                                        );
                                      },
                                    ),
                                    IconButton(
                                      iconSize: screenWidth / 15,
                                      key: ValueKey(dateConfirmed),
                                      icon: Icon(
                                        dateConfirmed
                                            ? Icons.check_circle
                                            : Icons.check_circle_outline,
                                      ),
                                      color: purpleColors(context),
                                      onPressed: () {
                                        setState(() {
                                          dateConfirmed = true;
                                        });
                                        selectedDate = DateTime(
                                          provider.selectedInvestmentDate.year,
                                          provider.selectedInvestmentDate.month,
                                          provider.selectedInvestmentDate.day,
                                          provider.selectedInvestmentTime.hour,
                                          provider
                                              .selectedInvestmentTime.minute,
                                        );
                                        selectedTime =
                                            provider.selectedInvestmentTime;
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
              } else {
                return Form(
                  key: formKey,
                  child: SingleChildScrollView(
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
                              child: const Icon(
                                Icons.savings_outlined,
                                color: Colors.white,
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Text(
                              'Add New Investment',
                              style: GoogleFonts.outfit(
                                fontSize: screenWidth / 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 28),

                        // Type Selection
                        StatefulBuilder(builder: (context, setStateType) {
                          return Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: primaryColor(context).withValues(alpha: 0.05),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: primaryColor(context).withValues(alpha: 0.1),
                                width: 1,
                              ),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: GestureDetector(
                                    onTap: () {
                                      setStateType(() {
                                        selectedType = 'Fixed Investment';
                                        selectedCategory =
                                            'Stocks'; // Reset to default for investments
                                      });
                                    },
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 12,
                                      ),
                                      decoration: BoxDecoration(
                                        color:
                                            selectedType == 'Fixed Investment'
                                                ? Theme.of(context).primaryColor
                                                : Colors.transparent,
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Icon(
                                            Icons.trending_up,
                                            size: 18,
                                            color: selectedType ==
                                                    'Fixed Investment'
                                                ? Colors.white
                                                : cardTextColor(context),
                                          ),
                                          const SizedBox(width: 8),
                                          Text(
                                            'Fixed',
                                            textAlign: TextAlign.center,
                                            style: GoogleFonts.outfit(
                                              fontSize: screenWidth / 30,
                                              fontWeight: FontWeight.w600,
                                              color: selectedType ==
                                                      'Fixed Investment'
                                                  ? Colors.white
                                                  : cardTextColor(context),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                                Expanded(
                                  child: GestureDetector(
                                    onTap: () {
                                      setStateType(() {
                                        selectedType = 'One-time Savings';
                                        selectedCategory =
                                            'Savings'; // Set category for one-time savings
                                      });
                                    },
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 12,
                                      ),
                                      decoration: BoxDecoration(
                                        color:
                                            selectedType == 'One-time Savings'
                                                ? Colors.green.shade600
                                                : Colors.transparent,
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Icon(
                                            Icons.savings_outlined,
                                            size: 18,
                                            color: selectedType ==
                                                    'One-time Savings'
                                                ? Colors.white
                                                : cardTextColor(context),
                                          ),
                                          const SizedBox(width: 8),
                                          Text(
                                            'One-time',
                                            textAlign: TextAlign.center,
                                            style: GoogleFonts.outfit(
                                              fontSize: screenWidth / 30,
                                              fontWeight: FontWeight.w600,
                                              color: selectedType ==
                                                      'One-time Savings'
                                                  ? Colors.white
                                                  : cardTextColor(context),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }),
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
                                boxShadow: [
                                  BoxShadow(
                                    color:
                                        shadowColor(context).withValues(alpha: 0.1),
                                    blurRadius: 10,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: IconButton.filled(
                                style: IconButton.styleFrom(
                                  backgroundColor:
                                      budgetBackgroundLight(context),
                                  foregroundColor: primaryColor(context),
                                ),
                                icon: const Icon(Icons.calendar_today),
                                onPressed: () {
                                  provider.toggleDateTimePicker();
                                },
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
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Please enter an amount';
                            }
                            final amount = double.tryParse(value);
                            if (amount == null || amount <= 0) {
                              return 'Enter a valid amount greater than 0';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 48),
                        Row(
                          children: [
                            Expanded(
                              child: TextButton(
                                onPressed: () => Navigator.pop(context),
                                style: TextButton.styleFrom(
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 16),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                ),
                                child: Text(
                                  'Cancel',
                                  style: GoogleFonts.outfit(
                                    fontSize: screenWidth / 30,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: ElevatedButton(
                                onPressed: () {
                                  if (formKey.currentState!.validate()) {
                                    final amount =
                                        double.parse(amountController.text);
                                    final isOneTime =
                                        selectedType == 'One-time Savings';
                                    context.read<InvestmentProvider>().addInvestment(
                                      nameController.text,
                                      amount,
                                      category: selectedCategory,
                                      startDate: DateTime(
                                        provider.selectedInvestmentDate.year,
                                        provider.selectedInvestmentDate.month,
                                        provider.selectedInvestmentDate.day,
                                        provider.selectedInvestmentTime.hour,
                                        provider.selectedInvestmentTime.minute,
                                      ),
                                      isOneTime: isOneTime,
                                    );
                                    Navigator.pop(context);
                                  }
                                },
                                style: ElevatedButton.styleFrom(
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 16),
                                  backgroundColor:
                                      selectedType == 'One-time Savings'
                                          ? Colors.green.shade600
                                          : Theme.of(context).primaryColor,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  elevation: 4,
                                  shadowColor:
                                      (selectedType == 'One-time Savings'
                                              ? Colors.green.shade600
                                              : Theme.of(context).primaryColor)
                                          .withValues(alpha: 0.4),
                                ),
                                child: Text(
                                  selectedType == 'One-time Savings'
                                      ? 'Add Savings'
                                      : 'Add Investment',
                                  style: GoogleFonts.outfit(
                                    fontSize: screenWidth / 30,
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
                  ),
                );
              }
            },
          ),
        ),
      ),
    );
  }

  static void showEditInvestmentDialog(
      BuildContext context, InvestmentModel investment, int index) {
    final TextEditingController amountController =
        TextEditingController(text: investment.amount.toString());
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(28),
        ),
        child: Container(
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
          child: Form(
            key: formKey,
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
                            Colors.blue.shade700,
                            Colors.blue.shade900,
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.edit_outlined,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      investment.isOneTime ?? false
                          ? 'Edit Savings'
                          : 'Edit Investment',
                      style: GoogleFonts.outfit(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 28),
                Text(
                  'Name: ${investment.name}',
                  style: GoogleFonts.outfit(
                    fontSize: 16,
                    color: primaryColor(context).withValues(alpha: 0.7),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 32),
                CustomTextField(
                  controller: amountController,
                  labelText: 'Amount',
                  prefixIcon: Icons.attach_money,
                  keyboardType: TextInputType.number,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter an amount';
                    }
                    final amount = double.tryParse(value);
                    if (amount == null || amount <= 0) {
                      return 'Enter a valid amount greater than 0';
                    }
                    return null;
                  },
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
                        onPressed: () {
                          if (formKey.currentState!.validate()) {
                            final amount = double.parse(amountController.text);
                            context
                                .read<InvestmentProvider>()
                                .updateInvestmentAmount(index, amount);
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
                          'Save Changes',
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
          ),
        ),
      ),
    );
  }

  static void showDeleteConfirmation(
      BuildContext context, InvestmentModel investment, int index) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(28),
        ),
        child: Container(
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
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.delete_outline,
                  color: Colors.red.shade400,
                  size: 32,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                investment.isOneTime ?? false
                    ? 'Delete Savings'
                    : 'Delete Investment',
                style: GoogleFonts.outfit(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Are you sure you want to delete this ${investment.isOneTime ?? false ? "savings" : "investment"}? This action cannot be undone.',
                textAlign: TextAlign.center,
                style: GoogleFonts.outfit(
                  fontSize: 16,
                  color: cardTextColor(context),
                ),
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
                      onPressed: () {
                        Provider.of<InvestmentProvider>(context, listen: false)
                            .removeInvestment(index);
                        Navigator.pop(context);
                      },
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        backgroundColor: Colors.red.shade400,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        elevation: 4,
                        shadowColor: Colors.red.withValues(alpha: 0.4),
                      ),
                      child: Text(
                        'Delete',
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
        ),
      ),
    );
  }
}

