import 'dart:async';
import 'package:flutter/material.dart';
import 'package:wallone/models/balance_model.dart';
import 'package:wallone/utils/services/shared_pref.dart';
import 'package:wallone/state/list_provider.dart';

class BalanceProvider extends ChangeNotifier {
  String _currencyCode = 'INR';
  final List<String> supportedCurrencies = ['INR', 'USD', 'EUR', 'GBP', 'JPY'];
  String get currencyCode => _currencyCode;

  void setCurrency(String newCode) {
    if (newCode == _currencyCode) return;
    _currencyCode = newCode;
    notifyListeners();
  }

  ListProvider? _listProvider;
  late final BalanceStorage _storage;
  BalanceModel _balance = const BalanceModel();
  bool _showDateTimePicker = false;
  String?
      _lastResetDateString; // Cache the last reset date to avoid storage calls
  bool _isProcessingReset = false; // Prevent multiple simultaneous reset calls
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

  // Formatted getters for UI.
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
  BalanceProvider(BalanceStorage storage) {
    _storage = storage;
    _log('Constructor initialized');
    _initializeData();
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
      _lastResetDateString = balances['lastResetDate'];

      // NOTE: Daily reset is handled by ResetBalanceService, not here
      // await _checkAndPerformDailyReset(); // DISABLED

      _log('Balances loaded successfully');
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

  Future<bool> resetDailyBalance() async {
    // Prevent multiple simultaneous calls
    if (_isProcessingReset) {
      _log('Reset already in progress - ignoring additional call');
      return false;
    }

    try {
      _isProcessingReset = true;
      _log('Manual daily balance reset requested...');

      // Check both conditions: if daily values are non-zero OR if lastResetDate is not today
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final todayString = today.toIso8601String();

      final hasNonZeroDailyValues =
          _balance.dailyExpenses != 0 || _balance.dailyIncomes != 0;
      final isResetDateOutdated =
          _lastResetDateString == null || _lastResetDateString != todayString;

      _log(
          'Reset check: hasNonZeroDailyValues=$hasNonZeroDailyValues, isResetDateOutdated=$isResetDateOutdated');

      if (hasNonZeroDailyValues || isResetDateOutdated) {
        _balance = _balance.copyWith(
          dailyExpenses: 0,
          dailyIncomes: 0,
        );

        _lastResetDateString = todayString;
        await _storage.saveLastResetDate(today);
        await _saveBalances();

        if (hasNonZeroDailyValues) {
          _log('Daily balance reset completed - values were reset');
        } else {
          _log('Daily balance reset completed - only date was updated');
        }

        notifyListeners();
        return true; // Reset actually happened
      } else {
        _log('Daily balance already reset - skipping');
        return false; // Reset was skipped
      }
    } catch (e, stackTrace) {
      _logError('Failed to reset daily balance', e, stackTrace);
      return false;
    } finally {
      _isProcessingReset = false;
    }
  }

  void resetWeeklyBalance() {
    try {
      _log('Resetting weekly balance...');
      _balance = _balance.copyWith(
        weeklyExpenses: 0,
        weeklyIncomes: 0,
      );
      _saveBalances();
      notifyListeners();
      _log('Weekly balance reset successfully');
    } catch (e, stackTrace) {
      _logError('Failed to reset weekly balance', e, stackTrace);
    }
  }

  void resetMonthlyBalance() {
    try {
      _log('Resetting monthly balance...');
      _balance = _balance.copyWith(
        monthlyExpenses: 0,
        monthlyIncomes: 0,
      );
      _saveBalances();
      notifyListeners();
      _log('Monthly balance reset successfully');
    } catch (e, stackTrace) {
      _logError('Failed to reset monthly balance', e, stackTrace);
    }
  }

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

  Future<void> resetApp() async {
    _balance = const BalanceModel();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    _lastResetDateString = today.toIso8601String();
    await _storage.clearAll();
    await _storage.saveLastResetDate(today);
    await _storage.saveBalances(_balance.toMap());
    notifyListeners();
    _log('App reset: all balances have been reset.');
  }
}
