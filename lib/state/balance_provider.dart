import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wallone/models/balance_model.dart';
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
  String? _lastResetDateString;
  String? _lastWeeklyResetDateString;
  String? _lastMonthlyResetDateString;

  // Separate flags for different reset types
  bool _isProcessingDailyReset = false;
  bool _isProcessingWeeklyReset = false;
  bool _isProcessingMonthlyReset = false;
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
      await _loadResetDates(); // Load all reset dates from SharedPreferences
      _log('Data initialized successfully');
    } catch (e, stackTrace) {
      _logError('Failed to initialize data', e, stackTrace);
    }
  }

  // Load reset dates from SharedPreferences
  Future<void> _loadResetDates() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _lastWeeklyResetDateString = prefs.getString('lastWeeklyResetDate');
      _lastMonthlyResetDateString = prefs.getString('lastMonthlyResetDate');

      _log(
          'Reset dates loaded - Weekly: $_lastWeeklyResetDateString, Monthly: $_lastMonthlyResetDateString');
    } catch (e, stackTrace) {
      _logError('Failed to load reset dates', e, stackTrace);
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
    if (_isProcessingDailyReset) {
      _log('Daily reset already in progress - ignoring additional call');
      return false;
    }

    try {
      _isProcessingDailyReset = true;
      _log('Manual daily balance reset requested...');

      // Check both conditions: if daily values are non-zero OR if lastResetDate is not today
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final todayString =
          today.toIso8601String().split('T')[0]; // Use only date part

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
      _isProcessingDailyReset = false;
    }
  }

  Future<bool> resetWeeklyBalance() async {
    if (_isProcessingWeeklyReset) {
      _log('Weekly reset already in progress - ignoring additional call');
      return false;
    }

    try {
      _isProcessingWeeklyReset = true;
      _log('Manual weekly balance reset requested...');

      final prefs = await SharedPreferences.getInstance();
      final now = DateTime.now();
      final currentWeekKey = _getWeekKey(now);

      // Check if reset is needed
      final lastReset = prefs.getString('lastWeeklyResetDate');
      final isResetOutdated = lastReset == null || lastReset != currentWeekKey;
      final hasNonZeroValues =
          _balance.weeklyExpenses != 0 || _balance.weeklyIncomes != 0;

      _log(
          'Weekly reset check: currentWeek=$currentWeekKey, lastReset=$lastReset, hasNonZeroValues=$hasNonZeroValues');

      if (hasNonZeroValues || isResetOutdated) {
        _balance = _balance.copyWith(
          weeklyExpenses: 0,
          weeklyIncomes: 0,
        );

        _lastWeeklyResetDateString = currentWeekKey;
        await prefs.setString('lastWeeklyResetDate', currentWeekKey);
        await _saveBalances();

        _log('Weekly reset completed for week: $currentWeekKey');
        notifyListeners();
        return true;
      } else {
        _log('Weekly balance already reset - skipping');
        return false;
      }
    } catch (e, stackTrace) {
      _logError('Failed to reset weekly balance', e, stackTrace);
      return false;
    } finally {
      _isProcessingWeeklyReset = false;
    }
  }

  Future<bool> resetMonthlyBalance() async {
    if (_isProcessingMonthlyReset) {
      _log('Monthly reset already in progress - ignoring additional call');
      return false;
    }

    try {
      _isProcessingMonthlyReset = true;
      _log('Manual monthly balance reset requested...');

      final prefs = await SharedPreferences.getInstance();
      final now = DateTime.now();
      final currentMonthKey = _getMonthKey(now);

      // Check if reset is needed
      final lastReset = prefs.getString('lastMonthlyResetDate');
      final isResetOutdated = lastReset == null || lastReset != currentMonthKey;
      final hasNonZeroValues =
          _balance.monthlyExpenses != 0 || _balance.monthlyIncomes != 0;

      _log(
          'Monthly reset check: currentMonth=$currentMonthKey, lastReset=$lastReset, hasNonZeroValues=$hasNonZeroValues');

      if (hasNonZeroValues || isResetOutdated) {
        _balance = _balance.copyWith(
          monthlyExpenses: 0,
          monthlyIncomes: 0,
        );

        _lastMonthlyResetDateString = currentMonthKey;
        await prefs.setString('lastMonthlyResetDate', currentMonthKey);
        await _saveBalances();

        _log('Monthly reset completed for month: $currentMonthKey');
        notifyListeners();
        return true;
      } else {
        _log('Monthly balance already reset - skipping');
        return false;
      }
    } catch (e, stackTrace) {
      _logError('Failed to reset monthly balance', e, stackTrace);
      return false;
    } finally {
      _isProcessingMonthlyReset = false;
    }
  }

  // Helper methods to generate consistent keys
  String _getWeekKey(DateTime date) {
    final monday = date.subtract(Duration(days: date.weekday - 1));
    final mondayDateOnly = DateTime(monday.year, monday.month, monday.day);

    final firstDayOfYear = DateTime(mondayDateOnly.year, 1, 1);
    final firstMonday = firstDayOfYear.weekday == DateTime.monday
        ? firstDayOfYear
        : firstDayOfYear
            .add(Duration(days: DateTime.monday - firstDayOfYear.weekday + 7));

    final weekNumber =
        ((mondayDateOnly.difference(firstMonday).inDays) / 7).floor() + 1;

    return '${mondayDateOnly.year}-W${weekNumber.toString().padLeft(2, '0')}-${mondayDateOnly.month.toString().padLeft(2, '0')}-${mondayDateOnly.day.toString().padLeft(2, '0')}';
  }

  String _getMonthKey(DateTime date) =>
      '${date.year}-${date.month.toString().padLeft(2, '0')}';

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
    // 1️⃣ Reset in-memory balance
    _balance = const BalanceModel();

    // 2️⃣ Reset in-memory dates
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    _lastResetDateString = today.toIso8601String().split('T')[0];
    _lastWeeklyResetDateString = null;
    _lastMonthlyResetDateString = null;

    // 3️⃣ Clear all stored balance/investment data
    await _storage.clearAll();
    await listProvider?.clearTransactions();

    // 4️⃣ Save fresh reset date + zero balance
    await _storage.saveLastResetDate(today);
    await _storage.saveBalances(_balance.toMap());
    await _storage.saveInvestments([]); // Clear investments
    await _storage.saveLastInvestmentCheckDate(today);

    // 5️⃣ Clear any extra preferences outside BalanceStorage if needed
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear(); // ⚠️ Clears ALL keys in SharedPreferences

    // 6️⃣ Notify UI
    notifyListeners();
    _log('App reset: all balances, investments, and reset dates cleared.');
  }
}
