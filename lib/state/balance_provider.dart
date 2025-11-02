import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wallone/models/balance_model.dart';
import 'package:wallone/pages/onboarding_page.dart';
import 'package:wallone/state/adviser_provider.dart';
import 'package:wallone/state/budget_provider.dart';
import 'package:wallone/state/category_provider.dart';
import 'package:wallone/state/investment_provider.dart';
import 'package:wallone/utils/services/shared_pref.dart';
import 'package:wallone/state/list_provider.dart';

class BalanceProvider extends ChangeNotifier {
  String _currencyCode = 'INR';
  final List<String> supportedCurrencies = ['INR', 'USD', 'EUR', 'GBP', 'JPY'];
  String get currencyCode => _currencyCode;

  Map<String, dynamic> toJson() {
    return {
      'balance': _balance,
    };
  }

  void setCurrency(String newCode) {
    if (newCode == _currencyCode) return;
    _currencyCode = newCode;
    notifyListeners();
  }

  void saveBalances() {
    _saveBalances();
  }

  ListProvider? _listProvider;
  late final BalanceStorage _storage;

  BalanceModel _balance = const BalanceModel();
  bool _showDateTimePicker = false;
  final String _tag = 'BalanceProvider';

  // --------------------------------------------------
  // GETTERS
  // --------------------------------------------------
  ListProvider? get listProvider => _listProvider;
  double get totalBalance => _balance.totalBalance;
  double get dailyExpenses => _balance.dailyExpenses;
  double get weeklyExpenses => _balance.weeklyExpenses;
  double get monthlyExpenses => _balance.monthlyExpenses;
  double get dailyIncomes => _balance.dailyIncomes;
  double get weeklyIncomes => _balance.weeklyIncomes;
  double get monthlyIncomes => _balance.monthlyIncomes;

  // Formatted getters for UI
  String get formattedTotalBalance => _balance.formattedTotalBalance;
  String get formattedDailyExpenses => _balance.formattedDailyExpenses;
  String get formattedWeeklyExpenses => _balance.formattedWeeklyExpenses;
  String get formattedMonthlyExpenses => _balance.formattedMonthlyExpenses;
  String get formattedDailyIncomes => _balance.formattedDailyIncomes;
  String get formattedWeeklyIncomes => _balance.formattedWeeklyIncomes;
  String get formattedMonthlyIncomes => _balance.formattedMonthlyIncomes;
  bool get showDateTimePicker => _showDateTimePicker;

  // --------------------------------------------------
  // CONSTRUCTOR & INITIALIZATION
  // --------------------------------------------------
  BalanceProvider(BalanceStorage storage) {
    _storage = storage;
    _log('Constructor initialized');
    _initializeData();
  }

  // Expose a helper that returns saved balance snapshot for a given date
  Future<double?> getSavedBalanceForDate(DateTime date) async {
    try {
      return await _storage.getBalanceForDate(date);
    } catch (e) {
      return null;
    }
  }

  Future<void> _initializeData() async {
    try {
      _log('Initializing data...');
      await _loadBalances();
      _log('Data initialized successfully');
    } catch (e, stackTrace) {
      _logError('Failed to initialize data', e, stackTrace);
    }
  }

  // --------------------------------------------------
  // SETTERS
  // --------------------------------------------------
  void setListProvider(ListProvider listProvider) {
    try {
      _log('Setting list provider...');
      _listProvider = listProvider;
      listProvider.loadTransactions().catchError((e, stackTrace) {
        _logError('Error loading transactions in list provider', e, stackTrace);
      });
      _log('List provider set successfully');
    } catch (e, stackTrace) {
      _logError('Failed to set list provider', e, stackTrace);
    }
  }

  // --------------------------------------------------
  // BALANCE MANAGEMENT
  // --------------------------------------------------
  Future<void> _loadBalances() async {
    try {
      _log('Loading balances...');
      final balances = await _storage.loadBalances();
      _balance = BalanceModel.fromMap(balances);

      _log('Balances loaded successfully');
      _log(
          'Daily: expenses=${_balance.dailyExpenses}, incomes=${_balance.dailyIncomes}');
      _log(
          'Weekly: expenses=${_balance.weeklyExpenses}, incomes=${_balance.weeklyIncomes}');
      _log(
          'Monthly: expenses=${_balance.monthlyExpenses}, incomes=${_balance.monthlyIncomes}');

      notifyListeners();
    } catch (e, stackTrace) {
      _logError('Failed to load balances', e, stackTrace);
      _balance = const BalanceModel();
      notifyListeners();
    }
  }

  Future<void> _saveBalances() async {
    try {
      _log('Saving balances...');
      await _storage.saveBalances(_balance.toMap());
      // Also save a daily snapshot for today's date
      try {
        await _storage.saveBalanceSnapshot(
            DateTime.now(), _balance.totalBalance);
      } catch (e) {
        // Ignore snapshot errors
      }
      _log('Balances saved successfully');
    } catch (e, stackTrace) {
      _logError('Failed to save balances', e, stackTrace);
    }
  }

  void addIncome(double amount) {
    try {
      _log('Adding income: $amount');
      _balance = _balance.copyWith(
        totalBalance: _balance.totalBalance + amount,
        dailyIncomes: _balance.dailyIncomes + amount,
        weeklyIncomes: _balance.weeklyIncomes + amount,
        monthlyIncomes: _balance.monthlyIncomes + amount,
      );
      _saveBalances();
      notifyListeners();
      _log('Income added successfully');
    } catch (e, stackTrace) {
      _logError('Failed to add income: $amount', e, stackTrace);
    }
  }

  void addExpense(double amount) {
    try {
      _log('Adding expense: $amount');
      _balance = _balance.copyWith(
        totalBalance: _balance.totalBalance - amount,
        dailyExpenses: _balance.dailyExpenses + amount,
        weeklyExpenses: _balance.weeklyExpenses + amount,
        monthlyExpenses: _balance.monthlyExpenses + amount,
      );
      _saveBalances();
      notifyListeners();
      _log('Expense added successfully');
    } catch (e, stackTrace) {
      _logError('Failed to add expense: $amount', e, stackTrace);
    }
  }

  void deductBalanceOnDelete(double amount) {
    try {
      _log('Deducting balance on delete: $amount');
      _balance = _balance.copyWith(
        totalBalance: _balance.totalBalance + amount,
        dailyExpenses: _balance.dailyExpenses - amount,
        weeklyExpenses: _balance.weeklyExpenses - amount,
        monthlyExpenses: _balance.monthlyExpenses - amount,
      );
      _saveBalances();
      notifyListeners();
      _log('Balance deducted on delete successfully');
    } catch (e, stackTrace) {
      _logError('Failed to deduct balance on delete: $amount', e, stackTrace);
    }
  }

  void deductBalanceForIncome(double amount) {
    try {
      _log('Deducting balance for income: $amount');
      _balance = _balance.copyWith(
        totalBalance: _balance.totalBalance - amount,
        dailyIncomes: _balance.dailyIncomes - amount,
        weeklyIncomes: _balance.weeklyIncomes - amount,
        monthlyIncomes: _balance.monthlyIncomes - amount,
      );
      _saveBalances();
      notifyListeners();
      _log('Balance deducted for income successfully');
    } catch (e, stackTrace) {
      _logError('Failed to deduct balance for income: $amount', e, stackTrace);
    }
  }

  // --------------------------------------------------
  // RESET METHODS (Called by ResetBalanceService)
  // --------------------------------------------------

  /// Resets daily balance values to 0
  /// This method is called by ResetBalanceService
  void resetDailyValues() {
    try {
      _log('Resetting daily values to 0...');
      _balance = _balance.copyWith(
        dailyExpenses: 0,
        dailyIncomes: 0,
      );
      _saveBalances();
      notifyListeners();
      _log('Daily values reset successfully');
    } catch (e, stackTrace) {
      _logError('Failed to reset daily values', e, stackTrace);
    }
  }

  /// Resets weekly balance values to 0
  /// This method is called by ResetBalanceService
  void resetWeeklyValues() {
    try {
      _log('Resetting weekly values to 0...');
      _balance = _balance.copyWith(
        weeklyExpenses: 0,
        weeklyIncomes: 0,
      );
      _saveBalances();
      notifyListeners();
      _log('Weekly values reset successfully');
    } catch (e, stackTrace) {
      _logError('Failed to reset weekly values', e, stackTrace);
    }
  }

  /// Resets monthly balance values to 0
  /// This method is called by ResetBalanceService
  void resetMonthlyValues() {
    try {
      _log('Resetting monthly values to 0...');
      _balance = _balance.copyWith(
        monthlyExpenses: 0,
        monthlyIncomes: 0,
      );
      _saveBalances();
      notifyListeners();
      _log('Monthly values reset successfully');
    } catch (e, stackTrace) {
      _logError('Failed to reset monthly values', e, stackTrace);
    }
  }

  // --------------------------------------------------
  // UI HELPERS
  // --------------------------------------------------

  void toggleDateTimePicker() {
    try {
      _log(
          'Toggling date time picker from $_showDateTimePicker to ${!_showDateTimePicker}');
      _showDateTimePicker = !_showDateTimePicker;
      notifyListeners();
    } catch (e, stackTrace) {
      _logError('Failed to toggle date time picker', e, stackTrace);
    }
  }

  // --------------------------------------------------
  // LOGGING
  // --------------------------------------------------

  void _log(String message) {
    print('[$_tag] $message');
  }

  void _logError(String message, dynamic error, StackTrace? stackTrace) {
    print('[$_tag] ERROR: $message');
    if (error != null) {
      print('[$_tag] Exception details: $error');
    }
    if (stackTrace != null) {
      print('[$_tag] Stack trace: $stackTrace');
    }
  }

  // --------------------------------------------------
  // APP RESET
  // --------------------------------------------------

  Future<void> resetApp(
    AIAdvisorProvider aiAdvisorProvider,
    BuildContext context, {
    CategoryProvider? categoryProvider,
    BudgetProvider? budgetProvider,
    InvestmentProvider? investmentProvider,
  }) async {
    try {
      _log('Starting complete app reset...');

      // 1️⃣ Reset in-memory values
      _balance = const BalanceModel();
      _showDateTimePicker = false;

      // 2️⃣ Clear all stored data in storage
      await _storage.clearAll();

      // 3️⃣ Clear transactions
      if (listProvider != null) {
        await listProvider!.clearTransactions();
        _log('Transactions cleared');
      }

      // 4️⃣ Clear investments
      if (investmentProvider != null) {
        await investmentProvider.clearAll();
        _log('Investments cleared');
      }

      // 5️⃣ Save zero balance + reset dates
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      await _storage.saveLastResetDate(today);
      await _storage.saveBalances(_balance.toMap());
      await _storage.saveInvestments([]);
      await _storage.saveLastInvestmentCheckDate(today);
      await _storage.saveBalanceHistory({});

      // 6️⃣ Clear AI cache
      await aiAdvisorProvider.clearCache();
      _log('AI cache cleared');

      // 7️⃣ Clear budgets
      if (budgetProvider != null) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove('budgets');
        _log('Budgets cleared');
      }

      // 8️⃣ Reset categories to defaults
      if (categoryProvider != null) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove('categories');
        _log('Categories reset to defaults');
      }

      // 9️⃣ Completely wipe all SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('userName');
      await prefs.remove('coverImagePath');
      await prefs.remove('profileImagePath');
      await prefs.remove('userEmail');
      await prefs.remove('geminiApiKey');
      await prefs.remove('totalBalance');
      await prefs.remove('dailyExpenses');
      await prefs.remove('weeklyExpenses');
      await prefs.remove('monthlyExpenses');
      await prefs.remove('dailyIncomes');
      await prefs.remove('weeklyIncomes');
      await prefs.remove('monthlyIncomes');
      await prefs.remove('lastResetDate');
      await prefs.remove('lastWeeklyResetDate');
      await prefs.remove('lastMonthlyResetDate');
      await prefs.remove('lastInvestmentCheckDate');
      await prefs.remove('balanceHistory');
      await prefs.remove('transactions');
      await prefs.remove('investments');
      await prefs.remove('totalInvestments');
      await prefs.remove('budgets');
      await prefs.remove('categories');
      await prefs.remove('ai_insights');
      await prefs.remove('ai_settings');
      await prefs.remove('executed_insights');
      await prefs.remove('dismissed_insights');

      _log('All SharedPreferences cleared');

      // 🔟 Notify UI listeners
      notifyListeners();

      _log('Full reset complete — all data cleared');

      // 1️⃣1️⃣ Navigate back to onboarding screen
      if (context.mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const OnboardingPage()),
          (route) => false,
        );
        _log('Navigated to onboarding page');
      }
    } catch (e, stackTrace) {
      _logError('Failed to complete app reset', e, stackTrace);

      if (context.mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Reset Failed'),
            content: Text('Failed to reset app: $e'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
    }
  }

  /// Helper method to verify reset was successful
  Future<bool> verifyReset() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      final hasBalance = prefs.containsKey('totalBalance');
      final hasTransactions = prefs.containsKey('transactions');
      final hasInvestments = prefs.containsKey('investments');
      final hasUserName = prefs.containsKey('userName');

      final isReset =
          !hasBalance && !hasTransactions && !hasInvestments && !hasUserName;

      _log('Reset verification: ${isReset ? "SUCCESS" : "FAILED"}');
      _log(
          'Has balance: $hasBalance, Has transactions: $hasTransactions, Has investments: $hasInvestments, Has userName: $hasUserName');

      return isReset;
    } catch (e, stackTrace) {
      _logError('Failed to verify reset', e, stackTrace);
      return false;
    }
  }
}
