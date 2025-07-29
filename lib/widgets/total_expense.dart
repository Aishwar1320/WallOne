import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:wallone/state/balance_provider.dart';
import 'package:wallone/utils/constants.dart';

class TotalExpenseBoxWidget extends StatelessWidget {
  final String label;
  final String balanceType; // 'daily', 'weekly', 'monthly', or 'total'
  final bool isExpensesSelected; // Whether expenses or incomes are selected

  const TotalExpenseBoxWidget({
    Key? key,
    required this.label,
    required this.balanceType,
    required this.isExpensesSelected,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final balanceProvider = Provider.of<BalanceProvider>(context);
    String formattedBalance;

    // Instead of using the raw double value, we now use formatted getters.
    switch (balanceType) {
      case 'daily':
        formattedBalance = isExpensesSelected
            ? balanceProvider.formattedDailyExpenses
            : balanceProvider.formattedDailyIncomes;
        break;
      case 'weekly':
        formattedBalance = isExpensesSelected
            ? balanceProvider.formattedWeeklyExpenses
            : balanceProvider.formattedWeeklyIncomes;
        break;
      case 'monthly':
        formattedBalance = isExpensesSelected
            ? balanceProvider.formattedMonthlyExpenses
            : balanceProvider.formattedMonthlyIncomes;
        break;
      case 'total':
      default:
        formattedBalance = balanceProvider.formattedTotalBalance;
        break;
    }

    return Container(
      height: 80,
      decoration: BoxDecoration(
        color: boxColor(context),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: shadowColor(context).withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            label,
            style: GoogleFonts.outfit(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: purpleColors(context),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            formattedBalance,
            style: GoogleFonts.outfit(
              fontSize: 22,
              color: primaryColor(context),
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
