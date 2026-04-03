import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:wallone/models/investment_model.dart';

import 'package:wallone/state/balance_provider.dart';
import 'package:wallone/state/budget_provider.dart';
import 'package:wallone/state/investment_provider.dart';
import 'package:wallone/utils/animations.dart';
import 'package:wallone/utils/constants.dart';
import 'package:wallone/common_widgets/custom_text_field.dart';

class FixedInvestmentsCard extends StatefulWidget {
  const FixedInvestmentsCard({super.key});

  @override
  State<FixedInvestmentsCard> createState() => _FixedInvestmentsCardState();
}

class _FixedInvestmentsCardState extends State<FixedInvestmentsCard> {
  final bool _isSimulating = false;

  @override
  Widget build(BuildContext context) {
    final budgetProvider = Provider.of<BudgetProvider>(context);
    final investments = budgetProvider.allInvestments;
    final screenWidth = MediaQuery.of(context).size.width;

    if (investments.isEmpty) {
      return _buildEmptyInvestmentsMessage(context);
    }

    // Calculate total investments amount from actual investments
    final totalInvestments = budgetProvider.totalInvestments;

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
      'Savings': {'icon': Icons.savings_outlined, 'color': Colors.green},
      // Default for other categories
      'default': {'icon': Icons.account_balance, 'color': Colors.teal},
    };

    final code = context.read<BalanceProvider>().currencyCode;
    final symbol = NumberFormat.simpleCurrency(name: code).currencySymbol;
    final provider = Provider.of<InvestmentProvider>(context);
    final percentageChangeValue = provider.percentageChange;

    return Column(
      children: [
        Column(
          children: [
            Text(
              'Total Portfolio Value',
              style: GoogleFonts.outfit(
                fontSize: screenWidth / 25,
                color: cardTextColor(context),
                fontWeight: FontWeight.w500,
              ),
            ),
            Text(
              '$symbol${totalInvestments.toStringAsFixed(2)}',
              style: GoogleFonts.outfit(
                fontSize: screenWidth / 15,
                fontWeight: FontWeight.bold,
                color: primaryColor(context),
                letterSpacing: 0.5,
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 8,
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
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    percentageChangeValue >= 0
                        ? Icons.arrow_upward
                        : Icons.arrow_downward,
                    color: percentageChangeValue >= 0
                        ? Colors.green.shade600
                        : Colors.red.shade600,
                    size: screenWidth / 28,
                  ),
                  const SizedBox(width: 2),
                  Text(
                    '${percentageChangeValue.toStringAsFixed(1)} %',
                    style: GoogleFonts.outfit(
                      fontSize: screenWidth / 34,
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
        const SizedBox(height: 20),

        // ── Chart ───────────────────────────────────────────────────────
        _InvestmentChart(
          screenWidth: screenWidth,
        ),

        const SizedBox(height: 14),

        // // ── Simulate button ────────────────────────────────────────────
        // GestureDetector(
        //   onTap: _isSimulating
        //       ? null
        //       : () async {
        //           setState(() => _isSimulating = true);
        //           try {
        //             await context
        //                 .read<InvestmentProvider>()
        //                 .simulateInvestmentDeduction();
        //             if (context.mounted) {
        //               ScaffoldMessenger.of(context).showSnackBar(
        //                 SnackBar(
        //                   content: Row(
        //                     children: [
        //                       const Icon(Icons.check_circle_rounded,
        //                           color: Colors.white, size: 18),
        //                       const SizedBox(width: 8),
        //                       Text(
        //                         'Investment cycle simulated!',
        //                         style: GoogleFonts.outfit(
        //                             color: Colors.white,
        //                             fontWeight: FontWeight.w600),
        //                       ),
        //                     ],
        //                   ),
        //                   backgroundColor: const Color(0xFF4C1D95),
        //                   behavior: SnackBarBehavior.floating,
        //                   shape: RoundedRectangleBorder(
        //                       borderRadius: BorderRadius.circular(12)),
        //                   duration: const Duration(seconds: 2),
        //                 ),
        //               );
        //             }
        //           } finally {
        //             if (mounted) setState(() => _isSimulating = false);
        //           }
        //         },
        //   child: AnimatedContainer(
        //     duration: const Duration(milliseconds: 200),
        //     padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
        //     decoration: BoxDecoration(
        //       gradient: _isSimulating
        //           ? null
        //           : const LinearGradient(
        //               colors: [Color(0xFF4C1D95), Color(0xFF7C3AED)],
        //               begin: Alignment.centerLeft,
        //               end: Alignment.centerRight,
        //             ),
        //       color: _isSimulating
        //           ? const Color(0xFF4C1D95).withOpacity(0.4)
        //           : null,
        //       borderRadius: BorderRadius.circular(14),
        //       boxShadow: _isSimulating
        //           ? []
        //           : [
        //               BoxShadow(
        //                 color: const Color(0xFF7C3AED).withOpacity(0.35),
        //                 blurRadius: 12,
        //                 offset: const Offset(0, 4),
        //               ),
        //             ],
        //     ),
        //     child: Row(
        //       mainAxisSize: MainAxisSize.min,
        //       mainAxisAlignment: MainAxisAlignment.center,
        //       children: [
        //         if (_isSimulating) ...[
        //           const SizedBox(
        //             width: 15,
        //             height: 15,
        //             child: CircularProgressIndicator(
        //               strokeWidth: 2,
        //               color: Colors.white,
        //             ),
        //           ),
        //           const SizedBox(width: 8),
        //         ] else ...[
        //           const Icon(Icons.play_circle_outline_rounded,
        //               color: Colors.white, size: 18),
        //           const SizedBox(width: 6),
        //         ],
        //         Text(
        //           _isSimulating ? 'Simulating…' : 'Simulate Investment Cycle',
        //           style: GoogleFonts.outfit(
        //             fontSize: screenWidth / 34,
        //             fontWeight: FontWeight.w700,
        //             color: Colors.white,
        //             letterSpacing: 0.2,
        //           ),
        //         ),
        //       ],
        //     ),
        //   ),
        // ),

        const SizedBox(height: 20),

        // List
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: boxColor(context),
            borderRadius: BorderRadius.circular(20),
          ),
          child: investments.isEmpty
              ? _buildEmptyInvestmentsMessage(context)
              : ListView.separated(
                  padding: EdgeInsets.zero,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: investments.length,
                  separatorBuilder: (context, index) => Divider(
                    color: primaryColor(context).withOpacity(0.1),
                    height: 24,
                  ),
                  itemBuilder: (context, index) {
                    final investment = investments[index];
                    final isOneTime = investment.isOneTime ?? false;

                    return Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: isOneTime
                                  ? [
                                      Colors.green.shade700,
                                      Colors.green.shade900,
                                    ]
                                  : [
                                      Theme.of(context)
                                          .primaryColor
                                          .withOpacity(0.7),
                                      Theme.of(context).primaryColor,
                                    ],
                            ),
                            borderRadius: BorderRadius.circular(14),
                            boxShadow: [
                              BoxShadow(
                                color: isOneTime
                                    ? Colors.green.withOpacity(0.2)
                                    : Theme.of(context)
                                        .primaryColor
                                        .withOpacity(0.2),
                                blurRadius: 6,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: Icon(
                            isOneTime
                                ? Icons.savings_outlined
                                : categoryIcons[investment.category]?['icon']
                                        as IconData? ??
                                    categoryIcons['default']!['icon']
                                        as IconData,
                            color: Colors.white,
                            size: screenWidth / 25,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    investment.name,
                                    overflow: TextOverflow.ellipsis,
                                    maxLines: 1,
                                    style: GoogleFonts.outfit(
                                      fontSize: screenWidth / 30,
                                      fontWeight: FontWeight.w600,
                                      color: primaryColor(context),
                                    ),
                                  ),
                                ],
                              ),
                              Text(
                                '$symbol${investment.amount.toStringAsFixed(2)}',
                                style: GoogleFonts.outfit(
                                  fontSize: screenWidth / 30,
                                  color: budgetTextLight(context),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (!isOneTime)
                          Transform.scale(
                            scale: screenWidth / 700,
                            child: Switch.adaptive(
                              padding: const EdgeInsetsGeometry.only(right: 0),
                              value: investment.isActive,
                              onChanged: (value) {
                                budgetProvider.toggleInvestment(index);
                              },
                              activeColor: Theme.of(context).primaryColor,
                            ),
                          ),
                        PopupMenuButton<String>(
                          padding: const EdgeInsetsGeometry.only(left: 0),
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
                            size: screenWidth / 22,
                          ),
                        ),
                      ],
                    );
                  },
                ),
        ),

        const SizedBox(
          height: 20,
        ),

        GestureDetector(
          onTap: () => _showAddInvestmentDialog(context),
          child: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: purpleColors(context),
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: Theme.of(context).primaryColor.withOpacity(0.3),
                  blurRadius: 6,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              spacing: 5,
              children: [
                Text(
                  'Investment More',
                  style: GoogleFonts.outfit(
                    fontSize: screenWidth / 30,
                    fontWeight: FontWeight.w600,
                    color: primaryColor(context),
                  ),
                ),
                Icon(
                  Icons.add,
                  color: primaryColor(context),
                  size: 20,
                ),
              ],
            ),
          ),
        ),
      ],
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
              color: boxColor(context),
              shape: BoxShape.circle,
              border: Border.all(
                color: shadowColor(context),
              ),
            ),
            child: Icon(
              Icons.trending_up,
              size: 32,
              color: primaryColor(context),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'No Investments Yet',
            style: GoogleFonts.outfit(
              fontSize: 22,
              fontWeight: FontWeight.w600,
              color: primaryColor(context),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Start growing your wealth by adding investments or savings',
            textAlign: TextAlign.center,
            style: GoogleFonts.outfit(
              fontSize: 16,
              color: budgetTextLight(context),
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
              backgroundColor: purpleColors(context),
              foregroundColor: Colors.white,
              elevation: 4,
              shadowColor: shadowColor(context),
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
                color: shadowColor(context).withOpacity(0.1),
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
                                        shadowColor(context).withOpacity(0.1),
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
                                          shadowColor(context).withOpacity(0.1),
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
                              color: primaryColor(context).withOpacity(0.05),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: primaryColor(context).withOpacity(0.1),
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
                                        shadowColor(context).withOpacity(0.1),
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
                                          .withOpacity(0.4),
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

  void _showEditInvestmentDialog(
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
                color: shadowColor(context).withOpacity(0.1),
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
                    color: primaryColor(context).withOpacity(0.7),
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

// ─────────────────────────────────────────────────────────────────────────────
// Investment Chart Widget
// ─────────────────────────────────────────────────────────────────────────────

class _InvestmentChart extends StatelessWidget {
  final double screenWidth;

  const _InvestmentChart({
    required this.screenWidth,
  });

  /// Builds FlSpots from the percentage history list with smooth interpolation.
  /// Adds intermediate points between each entry for elegant curves.
  List<FlSpot> _buildHistorySpots(List<double> history) {
    if (history.isEmpty) return [];
    if (history.length == 1) {
      return [FlSpot(0, history.first), FlSpot(1, history.first)];
    }

    final spots = <FlSpot>[];
    const int stepsPerSegment = 6; // intermediate points between entries

    for (int i = 0; i < history.length - 1; i++) {
      final y1 = history[i];
      final y2 = history[i + 1];

      for (int s = 0; s < stepsPerSegment; s++) {
        final t = s / stepsPerSegment; // 0.0 … <1.0
        // Smooth ease-in-out interpolation
        final eased = t * t * (3.0 - 2.0 * t);
        final y = y1 + (y2 - y1) * eased;
        final x = i.toDouble() + t;
        spots.add(FlSpot(x, y));
      }
    }
    // Add the final point
    spots.add(FlSpot((history.length - 1).toDouble(), history.last));
    return spots;
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<InvestmentProvider>(context);
    final sw = screenWidth;

    final percentageChange = provider.percentageChange;
    final history = provider.percentageHistory;

    // If there are no investments at all, show empty state
    if (provider.investments.isEmpty) {
      return Container(
        height: 160,
        decoration: BoxDecoration(
          color: boxColor(context),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: const Color(0xFF4C1D95).withOpacity(0.12),
            width: 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF4C1D95).withOpacity(0.06),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.show_chart_rounded,
                  size: 38, color: const Color(0xFF7C3AED).withOpacity(0.35)),
              const SizedBox(height: 8),
              Text(
                'No investment data',
                style: GoogleFonts.outfit(
                  fontSize: sw / 34,
                  color: const Color(0xFF4C1D95).withOpacity(0.4),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Prepend 0.0 so the graph always starts from the bottom left
    final displayHistory = [0.0, ...history];

    // Build spots from history
    List<FlSpot> spots;
    if (displayHistory.length >= 2) {
      // Enough data points for a real graph
      spots = _buildHistorySpots(displayHistory);
    } else {
      // Very unlikely edge case since we prepended 0.0, but just in case
      spots = [const FlSpot(0, 0), const FlSpot(1, 0)];
    }

    // Determine colours based on latest percentage
    final bool isHealthy = percentageChange >= 50;
    final Color stroke =
        isHealthy ? const Color(0xFF4C1D95) : const Color(0xFFDC2626);
    final Color glowMid =
        isHealthy ? const Color(0xFF7C3AED) : const Color(0xFFEF4444);
    final Color bgLight =
        isHealthy ? const Color(0xFFEDE9FE) : const Color(0xFFFEE2E2);

    return _buildChartCard(
      context: context,
      spots: spots,
      stroke: stroke,
      glowMid: glowMid,
      bgLight: bgLight,
      screenWidth: sw,
      percentageChange: percentageChange,
    );
  }

  Widget _buildChartCard({
    required BuildContext context,
    required List<FlSpot> spots,
    required Color stroke,
    required Color glowMid,
    required Color bgLight,
    required double screenWidth,
    required double percentageChange,
  }) {
    // Fixed Y range for percentage (0–100%)
    const double minY = 0.0;
    const double maxY = 105.0; // slight buffer above 100

    // ── X range ──────────────────────────────────────────────────────────────
    const double minXWidth = 6.0; // Show at least "6 intervals" of space
    final minX = spots.first.x - 0.1;

    // If we have less than minXWidth intervals, force maxX to maintain the scale
    final actualXRange = spots.last.x - spots.first.x;
    final maxX = actualXRange < minXWidth
        ? spots.first.x + minXWidth
        : spots.last.x + (actualXRange * 0.02);

    const titlesData = FlTitlesData(
      show: true,
      leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
      rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
      topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
      bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
    );

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: bgLight.withOpacity(0.38),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: stroke.withOpacity(0.08),
          width: 1.0,
        ),
      ),
      padding: const EdgeInsets.only(top: 24, bottom: 2, left: 0, right: 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: 188,
            child: LineChart(
              LineChartData(
                lineTouchData: LineTouchData(
                  handleBuiltInTouches: true,
                  touchSpotThreshold: 44,
                  getTouchedSpotIndicator: (barData, idxs) => idxs.map((idx) {
                    return TouchedSpotIndicatorData(
                      FlLine(
                        color: stroke.withOpacity(0.35),
                        strokeWidth: 1.5,
                        dashArray: [5, 5],
                      ),
                      FlDotData(
                        getDotPainter: (_, __, ___, ____) => FlDotCirclePainter(
                          radius: 5,
                          color: stroke,
                          strokeWidth: 2.5,
                          strokeColor: Colors.white,
                        ),
                      ),
                    );
                  }).toList(),
                  touchTooltipData: LineTouchTooltipData(
                    getTooltipColor: (_) =>
                        const Color(0xFF3B0764).withOpacity(0.92),
                    tooltipRoundedRadius: 12,
                    tooltipPadding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    getTooltipItems: (touched) => touched.map((ts) {
                      final val = ts.y;
                      final text =
                          '${val >= 0 ? '+' : ''}${val.toStringAsFixed(1)}%';
                      return LineTooltipItem(
                        text,
                        GoogleFonts.outfit(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: screenWidth / 31,
                        ),
                      );
                    }).toList(),
                  ),
                ),
                minX: minX,
                maxX: maxX,
                minY: minY,
                maxY: maxY,
                gridData: const FlGridData(show: false),
                borderData: FlBorderData(show: false),
                titlesData: titlesData,
                clipData: const FlClipData.all(),
                lineBarsData: [
                  LineChartBarData(
                    spots: spots,
                    isCurved: true,
                    curveSmoothness: 0.45,
                    preventCurveOverShooting: true,
                    preventCurveOvershootingThreshold: 1.5,
                    color: stroke,
                    barWidth: 2.8,
                    isStrokeCapRound: true,
                    isStrokeJoinRound: true,
                    shadow: Shadow(
                      color: stroke.withOpacity(0.5),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                    dotData: const FlDotData(show: false),
                    belowBarData: BarAreaData(
                      show: true,
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        stops: const [0.0, 0.55, 1.0],
                        colors: [
                          glowMid.withOpacity(0.28),
                          glowMid.withOpacity(0.07),
                          bgLight.withOpacity(0.0),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              duration: const Duration(milliseconds: 450),
              curve: Curves.easeOutCubic,
            ),
          ),
        ],
      ),
    );
  }
}
