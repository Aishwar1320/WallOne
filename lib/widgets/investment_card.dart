import 'dart:ui';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:wallone/state/balance_provider.dart';
import 'package:wallone/state/budget_provider.dart';
import 'package:wallone/utils/constants.dart';
import 'package:wallone/widgets/dropdown_menu.dart';
import 'package:wallone/widgets/custom_text_field.dart';

class FixedInvestmentsCard extends StatelessWidget {
  const FixedInvestmentsCard({super.key});

  @override
  Widget build(BuildContext context) {
    final budgetProvider = Provider.of<BudgetProvider>(context);
    final investments = budgetProvider.allInvestments;

    if (investments.isEmpty) {
      return Card(
        elevation: 16,
        shadowColor: shadowColor(context).withOpacity(0.4),
        color: boxColor(context),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(32),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(32),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 3, sigmaY: 3),
            child: Container(
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    boxColor(context),
                    boxColor(context).withOpacity(0.95),
                  ],
                ),
                borderRadius: BorderRadius.circular(32),
                border: Border.all(
                  color: primaryColor(context).withOpacity(0.05),
                  width: 1,
                ),
              ),
              child: _buildEmptyInvestmentsMessage(context),
            ),
          ),
        ),
      );
    }

    // Calculate total investments amount from actual investments
    final totalInvestments = budgetProvider.totalInvestments;

    // Calculate percentage change (comparing with last month)
    final lastMonthTotal =
        investments.where((inv) => inv.isActive).fold(0.0, (sum, inv) {
      final monthsSinceStart =
          DateTime.now().difference(inv.startDate).inDays / 30;
      return monthsSinceStart >= 1 ? sum + (inv.amount * 0.92) : sum;
    });

// Compute percentage change as a double
    final double percentageChangeValue = lastMonthTotal > 0
        ? ((totalInvestments - lastMonthTotal) / lastMonthTotal * 100)
        : 0.0;

    // Get actual investment categories or use defaults if none exist
    Map<String, double> investmentCategories = {};

    if (investments.isNotEmpty) {
      // Group investments by category and sum amounts
      for (var investment in investments) {
        if (investment.isActive) {
          if (investmentCategories.containsKey(investment.name)) {
            investmentCategories[investment.name] =
                investmentCategories[investment.name]! + investment.amount;
          } else {
            investmentCategories[investment.name] = investment.amount;
          }
        }
      }
    } else {
      // Default categories if no investments exist
      investmentCategories = {
        'Stocks': totalInvestments * 0.33,
        'Mutual Funds': totalInvestments * 0.51,
        'Gold': totalInvestments * 0.16,
      };
    }

    // Get top 3 investment categories (or less if fewer exist)
    final topCategories = investmentCategories.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    topCategories.take(3).toList();

    // Map of category names to their respective icons and colors
    final categoryIcons = {
      'Stocks': {'icon': Icons.show_chart, 'color': Colors.blue},
      'SIP': {'icon': Icons.pie_chart, 'color': Colors.purple},
      'Gold': {'icon': Icons.monetization_on, 'color': Colors.orange},
      // Default for other categories
      'default': {'icon': Icons.account_balance, 'color': Colors.teal},
    };

    final code = context.read<BalanceProvider>().currencyCode;
    final symbol = NumberFormat.simpleCurrency(name: code).currencySymbol;

    return Card(
      elevation: 16,
      shadowColor: shadowColor(context).withOpacity(0.4),
      color: boxColor(context),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(32),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(32),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 3, sigmaY: 3),
          child: Container(
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  boxColor(context),
                  boxColor(context).withOpacity(0.95),
                ],
              ),
              borderRadius: BorderRadius.circular(32),
              border: Border.all(
                color: primaryColor(context).withOpacity(0.05),
                width: 1,
              ),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    _buildGradientIconContainer(
                      context,
                      Icons.trending_up_rounded,
                      [Colors.deepPurple.shade700, Colors.deepPurple.shade900],
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'All Investments',
                                style: GoogleFonts.outfit(
                                  fontSize: 20,
                                  color: cardTextColor(context),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              IconButton(
                                onPressed: () =>
                                    _showAddInvestmentDialog(context),
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                                icon: Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [
                                        Theme.of(context)
                                            .primaryColor
                                            .withOpacity(0.8),
                                        Theme.of(context).primaryColor,
                                      ],
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                    ),
                                    borderRadius: BorderRadius.circular(14),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Theme.of(context)
                                            .primaryColor
                                            .withOpacity(0.3),
                                        blurRadius: 6,
                                        offset: const Offset(0, 3),
                                      ),
                                    ],
                                  ),
                                  child: Icon(
                                    Icons.add,
                                    color: inversePrimaryColor(context),
                                    size: 20,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 28),
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: primaryColor(context).withOpacity(0.05),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: primaryColor(context).withOpacity(0.1),
                      width: 1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: shadowColor(context).withOpacity(0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: investments.isEmpty
                      ? _buildEmptyInvestmentsMessage(context)
                      : ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: investments.length,
                          separatorBuilder: (context, index) => Divider(
                            color: primaryColor(context).withOpacity(0.1),
                            height: 24,
                          ),
                          itemBuilder: (context, index) {
                            final investment = investments[index];
                            return Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                      colors: [
                                        Theme.of(context)
                                            .primaryColor
                                            .withOpacity(0.7),
                                        Theme.of(context).primaryColor,
                                      ],
                                    ),
                                    borderRadius: BorderRadius.circular(14),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Theme.of(context)
                                            .primaryColor
                                            .withOpacity(0.2),
                                        blurRadius: 6,
                                        offset: const Offset(0, 3),
                                      ),
                                    ],
                                  ),
                                  child: Icon(
                                    categoryIcons[investment.category]?['icon']
                                            as IconData? ??
                                        categoryIcons['default']!['icon']
                                            as IconData,
                                    color: Colors.white,
                                    size: 20,
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        investment.name,
                                        style: GoogleFonts.outfit(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600,
                                          color: cardTextColor(context),
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        '$symbol${investment.amount.toStringAsFixed(2)}',
                                        style: GoogleFonts.outfit(
                                          fontSize: 14,
                                          color: primaryColor(context),
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Transform.scale(
                                  scale: 0.8,
                                  child: Switch.adaptive(
                                    value: investment.isActive,
                                    onChanged: (value) {
                                      budgetProvider.toggleInvestment(index);
                                    },
                                    activeColor: Theme.of(context).primaryColor,
                                  ),
                                ),
                                PopupMenuButton<String>(
                                  onSelected: (value) {
                                    if (value == 'Edit') {
                                      _showEditInvestmentDialog(
                                          context, investment, index);
                                    } else if (value == 'Delete') {
                                      _showDeleteConfirmation(
                                          context, investment, index);
                                    }
                                  },
                                  itemBuilder: (BuildContext context) => [
                                    const PopupMenuItem(
                                      value: 'Edit',
                                      child: Text('Edit'),
                                    ),
                                    const PopupMenuItem(
                                      value: 'Delete',
                                      child: Text('Delete'),
                                    ),
                                  ],
                                  icon: Icon(
                                    Icons.more_vert,
                                    color: cardTextColor(context),
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                ),
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: primaryColor(context).withOpacity(0.05),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: primaryColor(context).withOpacity(0.1),
                      width: 1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: shadowColor(context).withOpacity(0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Total Investments',
                            style: GoogleFonts.outfit(
                              fontSize: 16,
                              color: cardTextColor(context),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '$symbol${totalInvestments.toStringAsFixed(2)}',
                            style: GoogleFonts.outfit(
                              fontSize: 26,
                              fontWeight: FontWeight.bold,
                              color: primaryColor(context),
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: percentageChangeValue >= 0
                              ? Colors.green.withOpacity(0.1)
                              : Colors.red.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: percentageChangeValue >= 0
                                  ? Colors.green.withOpacity(0.1)
                                  : Colors.red.withOpacity(0.1),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            Icon(
                              percentageChangeValue >= 0
                                  ? Icons.arrow_upward
                                  : Icons.arrow_downward,
                              color: percentageChangeValue >= 0
                                  ? Colors.green.shade600
                                  : Colors.red.shade600,
                              size: 16,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '${percentageChangeValue.toStringAsFixed(1)}%',
                              style: GoogleFonts.outfit(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: percentageChangeValue >= 0
                                    ? Colors.green.shade600
                                    : Colors.red.shade600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // Demo Button
                // ElevatedButton(
                //   onPressed: () {
                //     Provider.of<BalanceProvider>(context, listen: false)
                //         .simulateInvestmentDeduction();
                //   },
                //   child: const Text("Simulate Investment Deduction"),
                // ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGradientIconContainer(
      BuildContext context, IconData icon, List<Color> gradientColors) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: gradientColors,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: gradientColors[0].withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Icon(
        icon,
        color: Colors.white,
        size: 15,
      ),
    );
  }

  Widget _buildEmptyInvestmentsMessage(BuildContext context) {
    return SizedBox(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).primaryColor.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.trending_up,
              size: 32,
              color: Theme.of(context).primaryColor,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'No Investments Yet',
            style: GoogleFonts.outfit(
              fontSize: 22,
              fontWeight: FontWeight.w600,
              color: cardTextColor(context),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Start growing your wealth by adding your first investment',
            textAlign: TextAlign.center,
            style: GoogleFonts.outfit(
              fontSize: 16,
              color: cardTextColor(context),
              height: 1.5,
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () => _showAddInvestmentDialog(context),
            icon: const Icon(
              color: Colors.white,
              Icons.add_rounded,
            ),
            label: Text(
              'Add Investment',
              style: GoogleFonts.outfit(
                fontWeight: FontWeight.w600,
              ),
            ),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(
                horizontal: 28,
                vertical: 14,
              ),
              backgroundColor: Theme.of(context).primaryColor,
              foregroundColor: Colors.white,
              elevation: 4,
              shadowColor: Theme.of(context).primaryColor.withOpacity(0.4),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showAddInvestmentDialog(BuildContext context) {
    final budgetProvider = Provider.of<BudgetProvider>(context, listen: false);
    final totalBalance = budgetProvider.totalBalance;

    if (totalBalance <= 0) {
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
                  color: shadowColor(context).withOpacity(0.1),
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
                          Theme.of(context).primaryColor.withOpacity(0.4),
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
    DateTime? selectedDate; // Variable to store the selected date
    TimeOfDay? selectedTime; // Variable to store the selected time

    selectedDate ??= DateTime.now();
    selectedTime ??= TimeOfDay.fromDateTime(selectedDate);

    // Create a key to validate the form.
    final _formKey = GlobalKey<FormState>();

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
                color: shadowColor(context).withOpacity(0.1),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Consumer<BudgetProvider>(
            builder: (context, provider, _) {
              if (provider.showDateTimePicker) {
                return Column(
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
                            fontSize: 24,
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
                            fontSize: 18,
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
                                  color: shadowColor(context),
                                  blurRadius: 5,
                                ),
                              ],
                            ),
                            child: CupertinoDatePicker(
                              mode: CupertinoDatePickerMode.dateAndTime,
                              initialDateTime: provider.selectedInvestmentDate,
                              onDateTimeChanged: (DateTime newDateTime) {
                                provider.updateInvestmentDateTime(newDateTime);
                              },
                            ),
                          ),
                          const SizedBox(height: 16),
                          if (selectedDate != null && selectedTime != null)
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: shadowColor(context),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    '${'${provider.selectedInvestmentDate.toLocal()}'.split(' ')[0].replaceAll('-', '/')}  ${provider.selectedInvestmentTime.format(context)}',
                                    style: GoogleFonts.outfit(
                                      fontSize: 16,
                                      color: cardTextColor(context),
                                    ),
                                  ),
                                  IconButton(
                                    icon: Icon(
                                      Icons.check_circle,
                                      color: purpleColors(context),
                                      size: 20,
                                    ),
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
                        ],
                      ),
                    ),
                  ],
                );
              } else {
                return Form(
                  key: _formKey,
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
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 28),
                      Row(
                        children: [
                          Expanded(
                            child: CustomTextField(
                              controller: nameController,
                              labelText: 'Investment Name',
                              prefixIcon: Icons.label_outline,
                              // Add validator for name
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) {
                                  return 'Please enter an investment name';
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
                                  blurRadius: 5,
                                  color: shadowColor(context),
                                ),
                              ],
                            ),
                            child: IconButton.filled(
                              style: IconButton.styleFrom(
                                backgroundColor: budgetBackgroundLight(context),
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
                        labelText: 'Investment Amount',
                        prefixIcon: Icons.attach_money,
                        keyboardType: TextInputType.number,
                        // Add validator for amount
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
                      const SizedBox(height: 20),
                      DropdownMenuDynamicWidget(
                        boxColor: boxColor(context),
                        hintText: 'Select Category',
                        items: const [
                          'Stocks',
                          'Mutual Funds',
                          'Gold',
                          'Other'
                        ],
                        onItemSelected: (String? newValue) {
                          if (newValue != null) {
                            selectedCategory = newValue;
                          }
                        },
                        value: selectedCategory,
                      ),
                      const SizedBox(height: 28),
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
                                if (_formKey.currentState!.validate()) {
                                  final amount =
                                      double.parse(amountController.text);
                                  provider.addInvestment(
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
                                  );
                                  Navigator.pop(context);
                                }
                              },
                              style: ElevatedButton.styleFrom(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 16),
                                backgroundColor: Theme.of(context).primaryColor,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                elevation: 4,
                                shadowColor: Theme.of(context)
                                    .primaryColor
                                    .withOpacity(0.4),
                              ),
                              child: Text(
                                'Add Investment',
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
            },
          ),
        ),
      ),
    );
  }

  void _showEditInvestmentDialog(
      BuildContext context, Investment investment, int index) {
    final TextEditingController amountController =
        TextEditingController(text: investment.amount.toString());
    final _formKey = GlobalKey<FormState>();

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
                color: shadowColor(context).withOpacity(0.1),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Form(
            key: _formKey,
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
                      'Edit Investment',
                      style: GoogleFonts.outfit(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 28),
                Text(
                  'Investment Name: ${investment.name}',
                  style: GoogleFonts.outfit(
                    fontSize: 16,
                    color: primaryColor(context).withOpacity(0.7),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Category: ${investment.category}',
                  style: GoogleFonts.outfit(
                    fontSize: 16,
                    color: primaryColor(context).withOpacity(0.7),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 20),
                CustomTextField(
                  controller: amountController,
                  labelText: 'Investment Amount',
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
                          if (_formKey.currentState!.validate()) {
                            final amount = double.parse(amountController.text);
                            Provider.of<BudgetProvider>(context, listen: false)
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
                              Theme.of(context).primaryColor.withOpacity(0.4),
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

  void _showDeleteConfirmation(
      BuildContext context, Investment investment, int index) {
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
                color: shadowColor(context).withOpacity(0.1),
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
                'Delete Investment',
                style: GoogleFonts.outfit(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Are you sure you want to delete this investment? This action cannot be undone.',
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
                        Provider.of<BudgetProvider>(context, listen: false)
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
                        shadowColor: Colors.red.withOpacity(0.4),
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
