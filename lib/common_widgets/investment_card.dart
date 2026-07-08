import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:wallone/state/balance_provider.dart';
import 'package:wallone/state/budget_provider.dart';
import 'package:wallone/state/investment_provider.dart';
import 'package:wallone/utils/constants.dart';
import 'package:wallone/common_widgets/investment_chart.dart';
import 'package:wallone/common_widgets/investment_dialogs.dart';

import 'package:wallone/common_widgets/investment_empty_state.dart';

class FixedInvestmentsCard extends StatefulWidget {
  const FixedInvestmentsCard({super.key});

  @override
  State<FixedInvestmentsCard> createState() => _FixedInvestmentsCardState();
}

class _FixedInvestmentsCardState extends State<FixedInvestmentsCard> {
  // Map of category names to their icons and colors
  static const Map<String, Map<String, dynamic>> _categoryIcons = {
    'Stocks': {'icon': Icons.show_chart, 'color': Colors.blue},
    'SIP': {'icon': Icons.pie_chart, 'color': Colors.purple},
    'Gold': {'icon': Icons.monetization_on, 'color': Colors.orange},
    'Savings': {'icon': Icons.savings_outlined, 'color': Colors.green},
    'default': {'icon': Icons.account_balance, 'color': Colors.teal},
  };

  @override
  Widget build(BuildContext context) {
    final budgetProvider = Provider.of<BudgetProvider>(context);
    final investments = budgetProvider.allInvestments;
    final screenWidth = MediaQuery.of(context).size.width;

    if (investments.isEmpty) {
      return InvestmentEmptyState(
        onAddInvestment: () =>
            InvestmentDialogs.showAddInvestmentDialog(context, setState),
      );
    }

    // Calculate total investments amount from actual investments
    final totalInvestments = budgetProvider.totalInvestments;

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
                    ? Colors.green.withValues(alpha: 0.1)
                    : Colors.red.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: percentageChangeValue >= 0
                        ? Colors.green.withValues(alpha: 0.1)
                        : Colors.red.withValues(alpha: 0.1),
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
        InvestmentChart(
          screenWidth: screenWidth,
        ),

        const SizedBox(height: 20),

        // List
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: boxColor(context),
            borderRadius: BorderRadius.circular(20),
          ),
          child: investments.isEmpty
              ? InvestmentEmptyState(
                  onAddInvestment: () =>
                      InvestmentDialogs.showAddInvestmentDialog(
                          context, setState),
                )
              : ListView.separated(
                  padding: EdgeInsets.zero,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: investments.length,
                  separatorBuilder: (context, index) => Divider(
                    color: primaryColor(context).withValues(alpha: 0.1),
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
                                          .withValues(alpha: 0.7),
                                      Theme.of(context).primaryColor,
                                    ],
                            ),
                            borderRadius: BorderRadius.circular(14),
                            boxShadow: [
                              BoxShadow(
                                color: isOneTime
                                    ? Colors.green.withValues(alpha: 0.2)
                                    : Theme.of(context)
                                        .primaryColor
                                        .withValues(alpha: 0.2),
                                blurRadius: 6,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: Icon(
                            isOneTime
                                ? Icons.savings_outlined
                                : _categoryIcons[investment.category]?['icon']
                                        as IconData? ??
                                    _categoryIcons['default']!['icon']
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
                                context
                                    .read<InvestmentProvider>()
                                    .toggleInvestmentActive(index);
                              },
                              activeThumbColor: Theme.of(context).primaryColor,
                            ),
                          ),
                        PopupMenuButton<String>(
                          padding: const EdgeInsetsGeometry.only(left: 0),
                          onSelected: (value) {
                            if (value == 'Edit') {
                              InvestmentDialogs.showEditInvestmentDialog(
                                  context, investment, index);
                            } else if (value == 'Delete') {
                              InvestmentDialogs.showDeleteConfirmation(
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
          onTap: () =>
              InvestmentDialogs.showAddInvestmentDialog(context, setState),
          child: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: purpleColors(context),
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: Theme.of(context).primaryColor.withValues(alpha: 0.3),
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
}
