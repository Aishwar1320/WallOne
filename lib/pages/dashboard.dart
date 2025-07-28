import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:wallone/state/list_provider.dart';
import 'package:wallone/utils/constants.dart';
import 'package:wallone/widgets/dynamic_buttons.dart';
import 'package:wallone/widgets/filter_control.dart';
import 'package:wallone/widgets/item_list.dart';
import 'package:wallone/widgets/total_expense.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  bool isExpensesSelected = true;
  String selectedPeriod = 'All Dates';

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: 10),
      physics: const BouncingScrollPhysics(),
      child: Column(
        spacing: 10,
        children: [
          // Expenses And Income Button With Month Drop Down List
          Container(
            decoration: BoxDecoration(
              color: inversePrimaryColor(context),
              borderRadius: BorderRadius.circular(25),
              boxShadow: [
                BoxShadow(
                  blurRadius: 5,
                  offset: const Offset(1, 1),
                  blurStyle: BlurStyle.solid,
                  color: shadowColor(context),
                )
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 10.0,
                vertical: 10,
              ),
              child: Column(
                spacing: 20,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      //

                      // Dynamic Switch Buttons
                      Expanded(
                        flex: 3,
                        child: DynamicButtonsWidget(
                          onSelectionChanged: (isExpensesSelected) {
                            setState(() {
                              this.isExpensesSelected = isExpensesSelected;
                            });

                            Provider.of<ListProvider>(context, listen: false)
                                .setFilter(
                              isExpensesSelected: isExpensesSelected,
                              period: selectedPeriod,
                              isActive: selectedPeriod != 'All Dates',
                            );
                          },
                        ),
                      ),

                      const SizedBox(width: 10),

                      // Drop Down Menu
                      Expanded(
                        flex: 2,
                        child: TransactionFilterControls(
                          isExpensesSelected: isExpensesSelected,
                          selectedPeriod: selectedPeriod,
                          onTypeChanged: (value) =>
                              setState(() => isExpensesSelected = value),
                          onPeriodChanged: (period) {
                            final newPeriod = period ?? 'All Dates';
                            setState(() {
                              selectedPeriod = newPeriod;
                            });

                            Provider.of<ListProvider>(context, listen: false)
                                .setFilter(
                              isExpensesSelected: isExpensesSelected,
                              period: newPeriod,
                              isActive: newPeriod != 'All Dates',
                            );
                          },
                        ),
                      )
                    ],
                  ),

                  // Day - Week - Month Total
                  Row(
                    spacing: 10,
                    children: [
                      Expanded(
                        child: TotalExpenseBoxWidget(
                          label: "D A Y",
                          balanceType: 'daily',
                          isExpensesSelected: isExpensesSelected,
                        ),
                      ),
                      Expanded(
                        child: TotalExpenseBoxWidget(
                          label: "W E E K",
                          balanceType: 'weekly',
                          isExpensesSelected: isExpensesSelected,
                        ),
                      ),
                      Expanded(
                        child: TotalExpenseBoxWidget(
                          label: "M O N T H",
                          balanceType: 'monthly',
                          isExpensesSelected: isExpensesSelected,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 10.0),
            child: Text(
              "T R A N S A C T I O N S",
              style: GoogleFonts.outfit(
                fontSize: 20,
                color: primaryColor(context),
                fontWeight: FontWeight.bold,
              ),
            ),
          ),

          // Transaction List
          Consumer<ListProvider>(
            key: ValueKey('${isExpensesSelected}_$selectedPeriod'),
            builder: (context, listProvider, child) {
              final transactions = listProvider.getFilteredTransactions(
                isExpensesSelected,
                selectedPeriod,
              );

              // Group transactions by date
              final Map<String, List<AllListProvider>> groupedTransactions = {};
              for (final transaction in transactions) {
                DateTime parsedDate;
                try {
                  parsedDate = DateTime.parse(transaction.date);
                } catch (e) {
                  parsedDate = DateFormat('dd-MM-yyyy').parse(transaction.date);
                }
                final dateKey = DateFormat('yyyy-MM-dd').format(parsedDate);

                (groupedTransactions[dateKey] ??= []).add(transaction);
              }

              // Sort dates descending
              final sortedDates = groupedTransactions.keys.toList()
                ..sort((a, b) => b.compareTo(a));

              return ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: sortedDates.length,
                itemBuilder: (context, index) {
                  final date = sortedDates[index];
                  return ItemListWidget(
                    transactions: groupedTransactions[date]!,
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }
}
