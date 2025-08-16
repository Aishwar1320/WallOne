import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wallone/models/investment_model.dart';
import 'package:wallone/state/balance_provider.dart';
import 'package:wallone/state/investment_provider.dart';
import 'package:wallone/utils/constants.dart';
import 'dart:convert';

/// Icon mapping for string keys to IconData
final Map<String, IconData> iconMap = {
  'food': Icons.fastfood,
  'travel': Icons.flight,
  'shopping': Icons.shopping_cart,
  'salary': Icons.attach_money,
  'home': Icons.home,
  'entertainment': Icons.movie,
  'others': Icons.category,
};

class Budget {
  final String category;
  final double amount;
  double spent;
  final String iconKey;
  final String id;

  Budget({
    required this.category,
    required this.amount,
    required this.spent,
    required this.iconKey,
    String? id,
  }) : id = id ?? DateTime.now().millisecondsSinceEpoch.toString();

  IconData get icon => iconMap[iconKey] ?? Icons.help_outline;

  double get progress => spent / amount;

  Color color(BuildContext context) {
    final percentage = progress * 100;
    if (percentage < 50) return budgetProgressGreen(context);
    if (percentage < 75) return budgetProgressOrange(context);
    if (percentage < 90) return budgetProgressDeepOrange(context);
    return budgetProgressRed(context);
  }

  String get statusText {
    final percentage = progress * 100;
    if (percentage < 50) return "On Track";
    if (percentage < 75) return "Watch Spending";
    if (percentage < 90) return "Near Limit";
    return "Over Budget";
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'category': category,
      'amount': amount,
      'spent': spent,
      'iconKey': iconKey,
    };
  }

  factory Budget.fromJson(Map<String, dynamic> json) {
    return Budget(
      id: json['id'],
      category: json['category'],
      amount: json['amount'],
      spent: json['spent'],
      iconKey: json['iconKey'],
    );
  }
}

class BudgetProvider with ChangeNotifier {
  final BalanceProvider _balanceProvider;
  final InvestmentProvider _investmentProvider;
  List<Budget> _budgets = [];
  final SharedPreferences _prefs;
  static const String _budgetsKey = 'budgets';

  Map<String, dynamic> toJson() {
    return {
      'budget': _budgets,
    };
  }

  bool _showAllBudgets = false;
  int _currentBudgetIndex = 0;
  bool _showDateTimePicker = false;

  BudgetProvider(this._balanceProvider, this._investmentProvider, this._prefs) {
    _loadBudgets();
    _investmentProvider.addListener(() {
      _syncWithBalanceProvider();
    });
  }

  bool get showAllBudgets => _showAllBudgets;
  int get currentBudgetIndex => _currentBudgetIndex;
  bool get showDateTimePicker => _showDateTimePicker;

  void toggleShowAllBudgets() {
    _showAllBudgets = !_showAllBudgets;
    notifyListeners();
  }

  void setCurrentBudgetIndex(int index) {
    _currentBudgetIndex = index;
    notifyListeners();
  }

  void toggleDateTimePicker() {
    _showDateTimePicker = !_showDateTimePicker;
    notifyListeners();
  }

  List<Budget> get budgets => _budgets;

  Budget? getBudgetByCategory(String category) {
    try {
      return _budgets.firstWhere(
        (budget) => budget.category.toLowerCase() == category.toLowerCase(),
      );
    } catch (_) {
      return null;
    }
  }

  void _syncWithBalanceProvider() {
    if (_investmentProvider.listProvider == null) return;

    final transactions = _investmentProvider.listProvider!.transactions;
    final today = DateTime.now();
    final firstDayOfMonth = DateTime(today.year, today.month, 1);

    for (var budget in _budgets) {
      budget.spent = 0;
    }

    for (var transaction in transactions) {
      if (transaction.isIncome) continue;

      final transactionDate = DateTime.parse(transaction.date);
      if (transactionDate.isBefore(firstDayOfMonth)) continue;

      final budget = getBudgetByCategory(transaction.category);
      if (budget != null) {
        budget.spent += transaction.amount;
      }
    }

    _saveBudgets();
    notifyListeners();
  }

  Future<void> _loadBudgets() async {
    final String? budgetsJson = _prefs.getString(_budgetsKey);
    if (budgetsJson != null) {
      final List<dynamic> decoded = jsonDecode(budgetsJson);
      _budgets = decoded.map((item) => Budget.fromJson(item)).toList();
      _syncWithBalanceProvider();
    }
  }

  Future<void> _saveBudgets() async {
    final String encoded = jsonEncode(_budgets.map((b) => b.toJson()).toList());
    await _prefs.setString(_budgetsKey, encoded);
  }

  Future<void> addBudget(String category, double amount, String iconKey) async {
    final budget = Budget(
      category: category,
      amount: amount,
      spent: 0,
      iconKey: iconKey,
    );
    _budgets.add(budget);
    await _saveBudgets();
    _syncWithBalanceProvider();
  }

  Future<void> updateBudgetSpent(String id, double spent) async {
    final index = _budgets.indexWhere((b) => b.id == id);
    if (index != -1) {
      _budgets[index].spent = spent;
      await _saveBudgets();
      notifyListeners();
    }
  }

  Future<void> removeBudget(String id) async {
    _budgets.removeWhere((b) => b.id == id);
    await _saveBudgets();
    notifyListeners();
  }

  double get monthlyIncome => _balanceProvider.monthlyIncomes;

  double get monthlySavings => totalBalance + totalInvestments;

  double get dailyUsage {
    final now = DateTime.now();
    final daysInMonth = DateTime(now.year, now.month + 1, 0).day;
    final remainingBalance = monthlyIncome - monthlyExpenses;
    return remainingBalance / daysInMonth;
  }

  double get totalInvestments => _investmentProvider.totalInvestments;

  Map<String, double> get investments {
    return {
      for (var inv in _investmentProvider.investments) inv.name: inv.amount
    };
  }

  double get monthlyExpensesProgress {
    if (monthlyIncome <= 0) return 0.0;
    return (_balanceProvider.monthlyExpenses / monthlyIncome).clamp(0.0, 1.0);
  }

  double get monthlyExpenses => _balanceProvider.monthlyExpenses;

  double get totalBalance => _balanceProvider.totalBalance;

  void addInvestment(String label, double amount,
      {String category = 'Stocks', DateTime? startDate}) {
    _investmentProvider.addInvestment(label, amount,
        category: category, startDate: startDate);
  }

  void removeInvestment(int index) {
    _investmentProvider.removeInvestment(index);
  }

  void toggleInvestment(int index) {
    _investmentProvider.toggleInvestmentActive(index);
  }

  void updateInvestmentAmount(int index, double amount) {
    _investmentProvider.updateInvestmentAmount(index, amount);
  }

  DateTime selectedInvestmentDate = DateTime.now();
  TimeOfDay selectedInvestmentTime = TimeOfDay.fromDateTime(DateTime.now());

  void updateInvestmentDateTime(DateTime newDateTime) {
    selectedInvestmentDate = newDateTime;
    selectedInvestmentTime = TimeOfDay.fromDateTime(newDateTime);
    notifyListeners();
  }

  List<InvestmentModel> get allInvestments => _investmentProvider.investments;

  // Create or update a budget (keeps existing spent if present)
  Future<void> createOrUpdateBudget(String category, double amount,
      {String iconKey = 'others'}) async {
    final existing = getBudgetByCategory(category);
    if (existing != null) {
      // preserve spent
      final spent = existing.spent;
      // replace item while keeping id
      final newBudget = Budget(
          category: category,
          amount: amount,
          spent: spent,
          iconKey: iconKey,
          id: existing.id);
      final idx = _budgets.indexWhere((b) => b.id == existing.id);
      if (idx >= 0) _budgets[idx] = newBudget;
    } else {
      // create new
      final budget = Budget(
          category: category, amount: amount, spent: 0, iconKey: iconKey);
      _budgets.add(budget);
    }
    await _saveBudgets();
    notifyListeners();
  }

// Simple setter for budget amount (keeps spent, similar to createOrUpdate)
  Future<void> setBudgetAmount(String category, double amount,
      {String iconKey = 'others'}) async {
    await createOrUpdateBudget(category, amount, iconKey: iconKey);
  }

// Add alias used by advisor for setting a 'limit' (same as createOrUpdate)
  Future<void> setCategoryLimit(String category, double limit,
      {String iconKey = 'others'}) async {
    await createOrUpdateBudget(category, limit, iconKey: iconKey);
  }

  /// Example: interpret insight metadata and execute a sensible action.
  /// This is app-specific; adapt rules as needed.
  Future<void> applyInsightAction(
      String insightId, Map<String, dynamic> metadata) async {
    final amount = (metadata['recommended'] ?? metadata['amount'] ?? 0);
    final category =
        (metadata['category'] ?? metadata['targetCategory'] ?? 'Misc')
            .toString();

    if ((amount is num) && amount > 0) {
      // Create or update budget to suggested amount
      await createOrUpdateBudget(category, (amount).toDouble());
      return;
    }

    // If metadata indicates a "savings" action delegate to investment provider if available
    if (metadata['action'] == 'savings' && _investmentProvider != null) {
      await _investmentProvider.addInvestment(metadata['name'] ?? 'AutoSave',
          (amount is num) ? (amount).toDouble() : 0.0,
          category: 'Savings', startDate: DateTime.now());
      return;
    }

    // fallback: no-op
    debugPrint('applyInsightAction: no rule matched for insight $insightId');
  }
}
