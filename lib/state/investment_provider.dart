import 'package:flutter/material.dart';
import 'package:wallone/models/investment_model.dart';
import 'package:wallone/models/investment_transaction_model.dart';
import 'package:wallone/models/investment_summary_model.dart';
import 'package:wallone/state/list_provider.dart';
import 'package:wallone/utils/services/shared_pref.dart';

/// Provider to manage user investments and their transaction history.
class InvestmentProvider with ChangeNotifier {
  final BalanceStorage storage;
  ListProvider? listProvider;

  List<InvestmentModel> _investments = [];
  List<InvestmentTransactionModel> _transactions = [];
  double _totalInvestments = 0;

  List<InvestmentModel> get investments => _investments;
  List<InvestmentTransactionModel> get investmentTransactions => _transactions;
  double get totalInvestments => _totalInvestments;

  InvestmentProvider(this.storage);

  /// Load investments and reconstruct state
  Future<void> loadInvestments() async {
    final raw = await storage.loadInvestments();
    _investments = raw
        .map((e) => InvestmentModel.fromMap(
              Map<String, dynamic>.from(e as Map),
            ))
        .toList();

    // Rebuild transactions list
    _transactions = _investments
        .expand((inv) => inv.monthlyDeductions.map(
              (amount) => InvestmentTransactionModel(
                amount: amount,
                date: inv.lastDeductionDate,
                id: '${inv.name}_${amount.toString()}_${inv.lastDeductionDate.toIso8601String()}',
              ),
            ))
        .toList();

    _recalcTotal();
    notifyListeners();
  }

  void _logError(String message, Object error, StackTrace stackTrace) {
    debugPrint('[InvestmentProvider ERROR] $message');
    debugPrint('Error details: $error');
    debugPrint('Stack trace: $stackTrace');
  }

  void _log(String message) {
    debugPrint('[InvestmentProvider] $message');
  }

  /// Save investments back to storage
  Future<void> saveInvestments() async {
    try {
      final serializable = _investments.map((inv) => inv.toMap()).toList();
      await storage.saveInvestments(_investments);

      _log('Investments saved: $serializable');
    } catch (e, st) {
      _logError('Failed to save investments', e, st);
    }
  }

  /// Add a new investment
  void addInvestment(String name, double amount, {String category = 'Other'}) {
    final inv = InvestmentModel.create(
      name: name,
      amount: amount,
      category: category,
    );
    _investments.add(inv);
    recordTransaction(inv.name, amount);
    saveInvestments();
    notifyListeners();
  }

  /// Remove investment by index
  void removeInvestment(int index) {
    if (index < 0 || index >= _investments.length) return;
    _investments.removeAt(index);
    saveInvestments();
    notifyListeners();
  }

  /// Toggle active state of an investment
  void toggleInvestmentActive(int index) {
    if (index < 0 || index >= _investments.length) return;
    final inv = _investments[index];
    _investments[index] = inv.copyWith(isActive: !inv.isActive);
    saveInvestments();
    notifyListeners();
  }

  /// Record a deduction transaction for given investment name
  void recordTransaction(String invName, double amount, {DateTime? date}) {
    final invIndex = _investments.indexWhere((inv) => inv.name == invName);
    if (invIndex == -1) return;
    final inv = _investments[invIndex];
    final dedDate = date ?? DateTime.now();
    final updatedInv = inv.addMonthlyDeduction(amount, dedDate);
    _investments[invIndex] = updatedInv;

    final tx = InvestmentTransactionModel(
      amount: amount,
      date: dedDate,
      id: '${inv.name}_${dedDate.toIso8601String()}',
    );
    _transactions.add(tx);
    _recalcTotal();
    saveInvestments();
    notifyListeners();
  }

  /// Remove a transaction and its corresponding deduction
  void removeTransaction(int txIndex) {
    if (txIndex < 0 || txIndex >= _transactions.length) return;
    final tx = _transactions.removeAt(txIndex);

    // find investment by matching id prefix
    final invName = tx.id?.split('_').first;
    final invIndex = _investments.indexWhere((i) => i.name == invName);
    if (invIndex != -1) {
      final inv = _investments[invIndex];
      final dedIndex = inv.monthlyDeductions.indexOf(tx.amount);
      if (dedIndex != -1) {
        _investments[invIndex] = inv.removeMonthlyDeduction(dedIndex);
      }
    }

    _recalcTotal();
    saveInvestments();
    notifyListeners();
  }

  /// Generate a summary model
  InvestmentSummaryModel get summary => InvestmentSummaryModel(
        totalInvestments: _totalInvestments,
        transactions: _transactions,
        activeInvestments: _investments.where((i) => i.isActive).toList(),
        inactiveInvestments: _investments.where((i) => !i.isActive).toList(),
      );

  void _recalcTotal() {
    _totalInvestments = _transactions.fold(0.0, (sum, tx) => sum + tx.amount);
  }
}
