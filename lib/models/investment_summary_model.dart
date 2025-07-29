import 'package:wallone/models/investment_model.dart';
import 'package:wallone/models/investment_transaction_model.dart';

class InvestmentSummaryModel {
  final double totalInvestments;
  final List<InvestmentTransactionModel> transactions;
  final List<InvestmentModel> activeInvestments;
  final List<InvestmentModel> inactiveInvestments;

  const InvestmentSummaryModel({
    this.totalInvestments = 0.0,
    this.transactions = const [],
    this.activeInvestments = const [],
    this.inactiveInvestments = const [],
  });

  // Get all investments (active + inactive)
  List<InvestmentModel> get allInvestments =>
      [...activeInvestments, ...inactiveInvestments];

  // Get total number of investments
  int get totalInvestmentCount => allInvestments.length;

  // Get total active investment amount (sum of all active investment amounts)
  double get totalActiveInvestmentAmount =>
      activeInvestments.fold(0.0, (sum, inv) => sum + inv.amount);

  // Get total deducted amount from all investments
  double get totalDeductedAmount =>
      allInvestments.fold(0.0, (sum, inv) => sum + inv.totalDeducted);

  InvestmentSummaryModel copyWith({
    double? totalInvestments,
    List<InvestmentTransactionModel>? transactions,
    List<InvestmentModel>? activeInvestments,
    List<InvestmentModel>? inactiveInvestments,
  }) {
    return InvestmentSummaryModel(
      totalInvestments: totalInvestments ?? this.totalInvestments,
      transactions: transactions ?? this.transactions,
      activeInvestments: activeInvestments ?? this.activeInvestments,
      inactiveInvestments: inactiveInvestments ?? this.inactiveInvestments,
    );
  }

  @override
  String toString() {
    return 'InvestmentSummaryModel(totalInvestments: $totalInvestments, transactions: ${transactions.length}, activeInvestments: ${activeInvestments.length}, inactiveInvestments: ${inactiveInvestments.length})';
  }
}
