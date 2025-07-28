import 'dart:async';
import 'package:flutter/material.dart';
import 'package:wallone/utils/services/shared_pref.dart';
import 'list_provider.dart';

/// A class representing a single historical investment transaction.
class InvestmentTransaction {
  final double amount;
  final DateTime date;

  InvestmentTransaction(this.amount, this.date);
}

/// Represents an individual investment.
class Investment {
  final String name;
  final double amount;
  bool isActive;
  final DateTime startDate;
  DateTime lastDeductionDate;
  final String category;
  final List<double> monthlyDeductions;

  Investment({
    required this.name,
    required this.amount,
    this.isActive = true,
    DateTime? startDate,
    DateTime? lastDeductionDate,
    this.category = 'Other',
    List<double>? monthlyDeductions,
  })  : startDate = startDate ?? DateTime.now(),
        lastDeductionDate = lastDeductionDate ?? DateTime.now(),
        monthlyDeductions = monthlyDeductions ?? [];

  // Returns the cumulative sum of all deduction transactions.
  double get totalDeducted =>
      monthlyDeductions.fold(0.0, (sum, amount) => sum + amount);

  Investment copyWith({
    double? amount,
    bool? isActive,
    DateTime? lastDeductionDate,
    String? category,
  }) {
    return Investment(
      name: name,
      amount: amount ?? this.amount,
      isActive: isActive ?? this.isActive,
      startDate: startDate,
      lastDeductionDate: lastDeductionDate ?? this.lastDeductionDate,
      category: category ?? this.category,
      monthlyDeductions: monthlyDeductions,
    );
  }
}

/// Provider to manage balances, incomes, expenses, and investments.
class BalanceProvider with ChangeNotifier {
  // default currency
  String _currencyCode = 'INR';

  // optional: list of supported currencies
  static const List<String> supportedCurrencies = [
    'INR',
    'USD',
    'EUR',
    'GBP',
    'JPY'
  ];

  String get currencyCode => _currencyCode;

  void setCurrency(String newCode) {
    if (newCode == _currencyCode) return;
    _currencyCode = newCode;
    notifyListeners();
    // TODO: persist to disk if you want (SharedPreferences, hive, etc)
  }

  // --------------------------------------------------
  // VARIABLES & STATE
  // --------------------------------------------------
  ListProvider? _listProvider;
  late final BalanceStorage _storage;

  // Balances
  double _totalBalance = 0;
  double _dailyExpenses = 0;
  double _weeklyExpenses = 0;
  double _monthlyExpenses = 0;
  double _dailyIncomes = 0;
  double _weeklyIncomes = 0;
  double _monthlyIncomes = 0;

  // Historical total investments: maintained independently.
  double _totalInvestments = 0;

  // Historical log of all investment transactions.
  final List<InvestmentTransaction> _investmentTransactions = [];

  // Active investments list (only active ones are shown).
  List<Investment> _investments = [];

  // Investment deduction tracking.
  DateTime _lastInvestmentCheckDate = DateTime.now();
  bool _processingInvestments = false;

  bool _showDateTimePicker = false;

  // Logger tag.
  static const String _tag = 'BalanceProvider';

  // --------------------------------------------------
  // GETTERS
  // --------------------------------------------------
  ListProvider? get listProvider => _listProvider;
  double get totalBalance => _totalBalance;
  double get dailyExpenses => _dailyExpenses;
  double get weeklyExpenses => _weeklyExpenses;
  double get monthlyExpenses => _monthlyExpenses;
  double get dailyIncomes => _dailyIncomes;
  double get weeklyIncomes => _weeklyIncomes;
  double get monthlyIncomes => _monthlyIncomes;
  List<Investment> get investments => _investments;
  double get totalInvestments => _totalInvestments;

  // Formatted getters for UI.
  String get formattedTotalBalance => _formatValue(_totalBalance);
  String get formattedDailyExpenses => _formatValue(_dailyExpenses);
  String get formattedWeeklyExpenses => _formatValue(_weeklyExpenses);
  String get formattedMonthlyExpenses => _formatValue(_monthlyExpenses);
  String get formattedDailyIncomes => _formatValue(_dailyIncomes);
  String get formattedWeeklyIncomes => _formatValue(_weeklyIncomes);
  String get formattedMonthlyIncomes => _formatValue(_monthlyIncomes);

  bool get showDateTimePicker => _showDateTimePicker;

  // --------------------------------------------------
  // CONSTRUCTOR & INITIALIZATION
  // --------------------------------------------------
  BalanceProvider(BalanceStorage storage) {
    _storage = storage;
    _log('Constructor initialized');
    _initializeData();
  }

  Future<void> _initializeData() async {
    try {
      _log('Initializing data...');
      // Load investments first, then balances.
      await _loadInvestments();
      await _loadBalances();
      await _loadLastInvestmentCheckDate();
      _startMonthlyDeduction();
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
      listProvider.loadTransactions().then((_) {
        _checkPendingInvestmentDeductions();
      }).catchError((e, stackTrace) {
        _logError('Error loading transactions in list provider', e, stackTrace);
      });
      _log('List provider set successfully');
    } catch (e, stackTrace) {
      _logError('Failed to set list provider', e, stackTrace);
    }
  }

  // --------------------------------------------------
  // UTILITY METHODS
  // --------------------------------------------------
  String _formatValue(double value) {
    try {
      if (value.abs() >= 1000) {
        double valueInK = value / 1000;
        return valueInK == valueInK.roundToDouble()
            ? '${valueInK.toInt()}k'
            : '${valueInK.toStringAsFixed(1)}k';
      }
      return value == value.roundToDouble()
          ? value.toInt().toString()
          : value.toStringAsFixed(2);
    } catch (e, stackTrace) {
      _logError('Error formatting value $value', e, stackTrace);
      return value.toString(); // Fallback
    }
  }

  /// Records an investment transaction as a permanent historical record.
  void recordInvestmentTransaction(double amount, {DateTime? date}) {
    final transaction = InvestmentTransaction(amount, date ?? DateTime.now());
    _investmentTransactions.add(transaction);
    // Recalculate the historical total as the sum of all recorded transactions.
    _totalInvestments =
        _investmentTransactions.fold(0.0, (sum, t) => sum + t.amount);
    _log(
        'Recorded transaction: +$amount at ${transaction.date.toIso8601String()}. New total investments: $_totalInvestments');
    _saveBalances();
  }

  /// Removes a historical investment transaction.
  /// This method searches for a transaction with the matching amount and date (within a small tolerance)
  /// and removes it, then recalculates the historical total.
  void removeHistoricalInvestmentTransaction(double amount, String dateString) {
    DateTime date = DateTime.parse(dateString);
    final histIndex = _investmentTransactions.indexWhere((t) =>
        t.amount == amount &&
        (t.date.difference(date).inSeconds).abs() <
            5); // allow a small time diff
    if (histIndex != -1) {
      _investmentTransactions.removeAt(histIndex);
      _totalInvestments =
          _investmentTransactions.fold(0.0, (sum, t) => sum + t.amount);
      _log(
          'Removed historical investment transaction of amount $amount. New total investments: $_totalInvestments');
      _saveBalances();
      notifyListeners();
    } else {
      _log(
          'No matching historical investment transaction found for amount $amount and date $dateString');
    }
  }

  // --------------------------------------------------
  // BALANCE MANAGEMENT
  // --------------------------------------------------

  Future<void> _loadBalances() async {
    try {
      _log('Loading balances...');
      final balances = await _storage.loadBalances();
      _totalBalance = (balances['totalBalance'] ?? 0).toDouble();
      _dailyExpenses = (balances['dailyExpenses'] ?? 0).toDouble();
      _weeklyExpenses = (balances['weeklyExpenses'] ?? 0).toDouble();
      _monthlyExpenses = (balances['monthlyExpenses'] ?? 0).toDouble();
      _dailyIncomes = (balances['dailyIncomes'] ?? 0).toDouble();
      _weeklyIncomes = (balances['weeklyIncomes'] ?? 0).toDouble();
      _monthlyIncomes = (balances['monthlyIncomes'] ?? 0).toDouble();
      _totalInvestments = (balances['totalInvestments'] ?? 0).toDouble();
      _log('Loaded total investments from storage: $_totalInvestments');
      final now = DateTime.now();
      final lastResetDateStr = balances['lastResetDate'];
      if (lastResetDateStr != null) {
        try {
          final lastReset =
              DateTime.parse(lastResetDateStr); // Already in local time
          final todayMidnight = DateTime(now.year, now.month, now.day);
          if (lastReset.isBefore(todayMidnight)) {
            _log('Daily reset needed...');
            await resetDailyBalance();
          }
        } catch (e, stackTrace) {
          _logError(
              "Error parsing lastResetDate: $lastResetDateStr", e, stackTrace);
          await _storage.saveLastResetDate(now);
        }
      } else {
        _log('No lastResetDate found, initializing with current time');
        await _storage.saveLastResetDate(now);
        await _saveBalances();
      }

      _log('Balances loaded successfully');
      notifyListeners();
    } catch (e, stackTrace) {
      _logError('Failed to load balances', e, stackTrace);
      _totalBalance = 0;
      _dailyExpenses = 0;
      _weeklyExpenses = 0;
      _monthlyExpenses = 0;
      _dailyIncomes = 0;
      _weeklyIncomes = 0;
      _monthlyIncomes = 0;
      notifyListeners();
    }
  }

  Future<void> _saveBalances() async {
    try {
      _log('Saving balances...');
      await _storage.saveBalances({
        'totalBalance': _totalBalance,
        'dailyExpenses': _dailyExpenses,
        'weeklyExpenses': _weeklyExpenses,
        'monthlyExpenses': _monthlyExpenses,
        'dailyIncomes': _dailyIncomes,
        'weeklyIncomes': _weeklyIncomes,
        'monthlyIncomes': _monthlyIncomes,
        'totalInvestments': _totalInvestments,
      });
      _log('Balances saved successfully');
    } catch (e, stackTrace) {
      _logError('Failed to save balances', e, stackTrace);
    }
  }

  void addIncome(double amount) {
    try {
      _log('Adding income: $amount');
      _totalBalance += amount;
      _dailyIncomes += amount;
      _weeklyIncomes += amount;
      _monthlyIncomes += amount;
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
      _totalBalance -= amount;
      _dailyExpenses += amount;
      _weeklyExpenses += amount;
      _monthlyExpenses += amount;
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
      _totalBalance += amount;
      _dailyExpenses -= amount;
      _weeklyExpenses -= amount;
      _monthlyExpenses -= amount;
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
      _totalBalance -= amount;
      _dailyIncomes -= amount;
      _weeklyIncomes -= amount;
      _monthlyIncomes -= amount;
      _saveBalances();
      notifyListeners();
      _log('Balance deducted for income successfully');
    } catch (e, stackTrace) {
      _logError('Failed to deduct balance for income: $amount', e, stackTrace);
    }
  }

  Future<void> resetDailyBalance() async {
    try {
      _log('Resetting daily balance...');
      final now = DateTime.now(); // Use local time
      _dailyExpenses = 0;
      _dailyIncomes = 0;
      await _storage.saveLastResetDate(now);
      await _saveBalances();
      notifyListeners();
      _log(
          'Daily balance reset successfully. New reset date: ${now.toIso8601String()}');
    } catch (e, stackTrace) {
      _logError('Failed to reset daily balance', e, stackTrace);
    }
  }

  void resetWeeklyBalance() {
    try {
      _log('Resetting weekly balance...');
      _weeklyExpenses = 0;
      _weeklyIncomes = 0;
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
      _monthlyExpenses = 0;
      _monthlyIncomes = 0;
      _saveBalances();
      notifyListeners();
      _log('Monthly balance reset successfully');
    } catch (e, stackTrace) {
      _logError('Failed to reset monthly balance', e, stackTrace);
    }
  }

  // --------------------------------------------------
  // INVESTMENT MANAGEMENT
  // --------------------------------------------------
  Future<void> addInvestment(
    String name,
    double amount, {
    String category = 'Other',
    DateTime? startDate,
  }) async {
    try {
      _log('Adding investment: name=$name, amount=$amount, category=$category');
      if (name.isEmpty) {
        _logError('Invalid investment name: name cannot be empty', null, null);
        return;
      }
      if (amount <= 0) {
        _logError(
            'Invalid investment amount: amount must be positive', null, null);
        return;
      }
      name = name.replaceAll(RegExp(r'[|\\]'), '');
      if (_totalBalance < amount) {
        _logError(
            'Insufficient balance ($_totalBalance) for investment amount ($amount)',
            null,
            null);
        return;
      }
      final newInvestment = Investment(
        name: name,
        amount: amount,
        isActive: true,
        startDate: startDate,
        category: category,
        monthlyDeductions: [amount],
      );
      _investments.add(newInvestment);
      // Record the initial investment transaction historically.
      recordInvestmentTransaction(amount);
      if (_listProvider != null) {
        _listProvider!.addTransaction(AllListProvider(
          title: "Investment",
          category: name,
          amount: amount,
          isIncome: false,
          date: DateTime.now().toIso8601String(),
        ));
      } else {
        _totalBalance -= amount;
        _dailyExpenses += amount;
        _weeklyExpenses += amount;
        _monthlyExpenses += amount;
        _saveBalances();
      }
      await _saveInvestments();
      _saveBalances();
      notifyListeners();
      _log(
          'Investment added successfully. Historical total investments: $_totalInvestments');
    } catch (e, stackTrace) {
      _logError('Failed to add investment', e, stackTrace);
    }
  }

  /// Removes an entire investment from the list.
  /// Historical transactions remain, so _totalInvestments is unchanged.
  void removeInvestment(int index) {
    try {
      _log('Removing investment at index: $index');
      if (index < 0 || index >= _investments.length) {
        _logError(
            'Invalid index for removing investment: $index (investments length: ${_investments.length})',
            null,
            null);
        return;
      }
      _investments.removeAt(index);
      _log('Investment removed permanently.');
      _saveInvestments();
      _saveBalances();
      notifyListeners();
    } catch (e, stackTrace) {
      _logError('Failed to remove investment at index $index', e, stackTrace);
    }
  }

  /// Toggles the active status of an investment.
  void toggleInvestment(int index) {
    try {
      _log('Toggling investment at index: $index');
      if (index < 0 || index >= _investments.length) {
        _logError(
            'Invalid index for toggling investment: $index (investments length: ${_investments.length})',
            null,
            null);
        return;
      }
      final investment = _investments[index];
      final newStatus = !investment.isActive;
      _investments[index] = investment.copyWith(isActive: newStatus);
      _saveInvestments();
      notifyListeners();
      _log(
          'Investment "${investment.name}" toggled to: ${newStatus ? "active" : "inactive"}');
    } catch (e, stackTrace) {
      _logError('Failed to toggle investment at index $index', e, stackTrace);
    }
  }

  /// Removes a specific investment transaction (monthly deduction) from an investment.
  /// This will remove the corresponding historical record and update _totalInvestments.
  void removeInvestmentTransaction(int investmentIndex, int transactionIndex) {
    try {
      _log(
          'Removing investment transaction at index $transactionIndex for investment at index $investmentIndex');
      if (investmentIndex < 0 || investmentIndex >= _investments.length) {
        _logError('Invalid investment index: $investmentIndex', null, null);
        return;
      }
      final inv = _investments[investmentIndex];
      if (transactionIndex < 0 ||
          transactionIndex >= inv.monthlyDeductions.length) {
        _logError(
            'Invalid transaction index: $transactionIndex for investment ${inv.name}',
            null,
            null);
        return;
      }
      double removedAmount = inv.monthlyDeductions[transactionIndex];
      inv.monthlyDeductions.removeAt(transactionIndex);
      // Remove the corresponding historical transaction.
      // We use the transaction's date from the list transaction (if available) for matching.
      // For this example, we'll assume the transaction date is the same as when it was recorded.
      // In a real-world scenario, you might store a unique id for each historical record.
      _log(
          'Attempting to remove historical record for amount $removedAmount with assumed date.');
      // Here we pass the removed amount and the current date as a proxy.
      removeHistoricalInvestmentTransaction(
          removedAmount, DateTime.now().toIso8601String());
      _saveInvestments();
      _saveBalances();
      notifyListeners();
    } catch (e, stackTrace) {
      _logError('Failed to remove investment transaction', e, stackTrace);
    }
  }

  Future<void> _saveInvestments() async {
    try {
      _log('Saving investments...');
      await _storage.saveInvestments(_investments);
      _log('Investments saved successfully. Count: ${_investments.length}');
    } catch (e, stackTrace) {
      _logError('Failed to save investments', e, stackTrace);
    }
  }

  Future<void> _loadInvestments() async {
    try {
      _log("Loading investments...");
      _investments = await _storage.loadInvestments();
      if (_investments.isEmpty) {
        _log("No investments found in storage");
      } else {
        _log("Loaded ${_investments.length} investments");
        for (int i = 0; i < _investments.length; i++) {
          final inv = _investments[i];
          _log(
              "  [$i] ${inv.name}: \$${inv.amount} (${inv.isActive ? 'active' : 'inactive'})");
        }
      }
      notifyListeners();
    } catch (e, stackTrace) {
      _logError("Error loading investments", e, stackTrace);
      _investments = [];
      notifyListeners();
    }
  }

  // --------------------------------------------------
  // INVESTMENT DEDUCTION PROCESSING
  // --------------------------------------------------
  void simulateInvestmentDeduction() async {
    try {
      _log('Simulating full investment deduction (forced)');

      final now = DateTime.now();
      bool hasDeductions = false;

      final activeInvestments = _investments.where((i) => i.isActive).toList();
      _log('Simulating ${activeInvestments.length} active investments');

      for (final inv in activeInvestments) {
        if (_totalBalance < inv.amount) {
          _log(
              'Insufficient balance ($_totalBalance) for ${inv.name} (${inv.amount}). Skipping deduction.');
          continue;
        }

        // Deduct balance and log
        _totalBalance -= inv.amount;
        _dailyExpenses += inv.amount;
        _weeklyExpenses += inv.amount;
        _monthlyExpenses += inv.amount;

        // Update last deduction date
        inv.lastDeductionDate = now;
        inv.monthlyDeductions.add(inv.amount);

        // Add transaction (optional logging)
        if (_listProvider != null) {
          _listProvider!.addTransaction(
            AllListProvider(
              title: "Investment",
              category: inv.name,
              amount: inv.amount,
              isIncome: false,
              date: now.toIso8601String(),
            ),
            updateBalance: false,
          );
        }

        recordInvestmentTransaction(inv.amount);

        _log("Simulated deduction for ${inv.name} at $now");
        hasDeductions = true;
      }

      if (hasDeductions) {
        await _saveInvestments();
        await _saveBalances();

        // // Optionally update totalInvestments here, if it's computed from active investments:
        // _recalculateTotalInvestments();

        notifyListeners();
        _log('Simulation complete. State updated.');
      } else {
        _log('No deductions simulated (maybe insufficient balance)');
      }
    } catch (e, stackTrace) {
      _logError('Failed to simulate investment deduction', e, stackTrace);
    }
  }

  void _checkPendingInvestmentDeductions() {
    try {
      if (_listProvider == null) {
        _log(
            'Cannot check pending investment deductions: list provider is null');
        return;
      }
      final now = DateTime.now();
      final hoursSinceLastCheck =
          now.difference(_lastInvestmentCheckDate).inHours;
      _log(
          'Checking pending investment deductions. Hours since last check: $hoursSinceLastCheck');
      if (hoursSinceLastCheck < 12) {
        _log(
            'Skipping investment deduction check (checked within last 12 hours)');
        return;
      }
      _processInvestmentDeductions();
    } catch (e, stackTrace) {
      _logError('Failed to check pending investment deductions', e, stackTrace);
    }
  }

  void _startMonthlyDeduction() {
    try {
      _log('Starting monthly deduction timer');
      Timer.periodic(const Duration(days: 1), (timer) {
        _log('Timer triggered for investment deduction check');
        if (_listProvider != null) {
          _processInvestmentDeductions();
        } else {
          _log(
              'Skipping scheduled investment deduction: list provider is null');
        }
      });
    } catch (e, stackTrace) {
      _logError('Failed to start monthly deduction timer', e, stackTrace);
    }
  }

  Future<void> _processInvestmentDeductions({bool force = false}) async {
    if (_processingInvestments) {
      _log('Already processing investments. Skipping.');
      return;
    }
    _processingInvestments = true;
    _log('Processing investment deductions... (forced: $force)');
    try {
      _lastInvestmentCheckDate = DateTime.now();
      await _storage.saveLastInvestmentCheckDate(_lastInvestmentCheckDate);
      _log(
          'Updated last investment check date: ${_lastInvestmentCheckDate.toIso8601String()}');
      bool hasDeductions = false;
      final now = DateTime.now();
      final activeInvestments = _investments.where((i) => i.isActive).toList();
      _log('Processing ${activeInvestments.length} active investments');
      for (final inv in activeInvestments) {
        final lastDeduction = inv.lastDeductionDate;
        _log(
            'Investment: ${inv.name}, Amount: ${inv.amount}, Last deduction: ${lastDeduction.toIso8601String()}');
        if (!force &&
            now.year == lastDeduction.year &&
            now.month == lastDeduction.month) {
          _log('Skipping ${inv.name}, already deducted this month.');
          continue;
        }
        if (_totalBalance < inv.amount) {
          _log(
              'Insufficient balance ($_totalBalance) for ${inv.name} (${inv.amount}). Skipping deduction.');
          continue;
        }
        _log('Deducting investment: ${inv.name}, amount: ${inv.amount}');
        _totalBalance -= inv.amount;
        _dailyExpenses += inv.amount;
        _weeklyExpenses += inv.amount;
        _monthlyExpenses += inv.amount;
        if (_listProvider != null) {
          _listProvider!.addTransaction(
            AllListProvider(
              title: "Investment",
              category: inv.name,
              amount: inv.amount,
              isIncome: false,
              date: now.toIso8601String(),
            ),
            updateBalance: false,
          );
        }

        inv.lastDeductionDate = now;
        _log(
            "Updated last deduction date for ${inv.name}: ${inv.lastDeductionDate.toIso8601String()}");

        inv.monthlyDeductions.add(inv.amount);
        recordInvestmentTransaction(inv.amount);
        hasDeductions = true;
      }
      if (hasDeductions) {
        await _saveInvestments();
        await _saveBalances();
        notifyListeners();
        _log('Investment deductions processed successfully');
      } else {
        _log('No investment deductions were processed');
      }
    } catch (e, stackTrace) {
      _logError('Failed to process investment deductions', e, stackTrace);
    } finally {
      _processingInvestments = false;
      _log('Finished processing investment deductions');
    }
  }

  Future<void> _loadLastInvestmentCheckDate() async {
    try {
      _log('Loading last investment check date...');
      final lastDate = await _storage.loadLastInvestmentCheckDate();
      _lastInvestmentCheckDate = lastDate;
      _log(
          'Last investment check date loaded: ${_lastInvestmentCheckDate.toIso8601String()}');
    } catch (e, stackTrace) {
      _logError('Failed to load last investment check date', e, stackTrace);
      _lastInvestmentCheckDate = DateTime.now();
    }
  }

  // Update an existing investment amount.
  void updateInvestmentAmount(int index, double newAmount) {
    try {
      _log('Updating investment amount at index $index to $newAmount');
      if (index < 0 || index >= _investments.length) {
        _logError(
            'Invalid index for updating investment amount: $index', null, null);
        return;
      }
      if (newAmount <= 0) {
        _logError('Invalid investment amount: $newAmount (must be positive)',
            null, null);
        return;
      }
      final investment = _investments[index];
      _log(
          'Updating ${investment.name} from ${investment.amount} to $newAmount');
      _investments[index] = investment.copyWith(amount: newAmount);
      _saveInvestments();
      _saveBalances();
      notifyListeners();
      _log('Investment amount updated successfully');
    } catch (e, stackTrace) {
      _logError(
          'Failed to update investment amount at index $index', e, stackTrace);
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

  // --------------------------------------------------
  // LOGGING UTILITIES
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

  // RESTET EVERYTHING IN APP
  Future<void> resetApp() async {
    // Reset balances
    _totalBalance = 0;
    _dailyExpenses = 0;
    _weeklyExpenses = 0;
    _monthlyExpenses = 0;
    _dailyIncomes = 0;
    _weeklyIncomes = 0;
    _monthlyIncomes = 0;
    _totalInvestments = 0;

    // Clear investment-related data
    _investmentTransactions.clear();
    _investments.clear();

    // Update last reset dates to now
    final now = DateTime.now();
    await _storage.clearAll();
    await _storage.saveLastResetDate(now);
    await _storage.saveLastInvestmentCheckDate(now);

    // Save the reset balances and investments to storage
    await _storage.saveBalances({
      'totalBalance': _totalBalance,
      'dailyExpenses': _dailyExpenses,
      'weeklyExpenses': _weeklyExpenses,
      'monthlyExpenses': _monthlyExpenses,
      'dailyIncomes': _dailyIncomes,
      'weeklyIncomes': _weeklyIncomes,
      'monthlyIncomes': _monthlyIncomes,
      'totalInvestments': _totalInvestments,
    });
    await _storage.saveInvestments(_investments);

    notifyListeners();
    _log(
        'App reset: all balances, incomes, expenses, and investments have been reset.');
  }
}
