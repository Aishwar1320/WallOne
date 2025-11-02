import 'dart:async';
import 'package:flutter/material.dart';
import 'package:wallone/models/investment_model.dart';
import 'package:wallone/models/investment_transaction_model.dart';
import 'package:wallone/models/investment_summary_model.dart';
import 'package:wallone/state/list_provider.dart';
import 'package:wallone/state/balance_provider.dart';
import 'package:wallone/utils/services/shared_pref.dart';

/// Provider to manage user investments and their transaction history.
class InvestmentProvider with ChangeNotifier {
  final BalanceStorage storage;
  ListProvider? listProvider;
  BalanceProvider? balanceProvider;

  Map<String, dynamic> toJson() {
    return {
      'totalInvestment': _totalInvestments,
    };
  }

  List<InvestmentModel> _investments = [];
  List<InvestmentTransactionModel> _transactions = [];
  double _totalInvestments = 0;

  // Investment deduction tracking
  DateTime _lastInvestmentCheckDate = DateTime.now();
  bool _processingInvestments = false;
  Timer? _monthlyDeductionTimer;
  double lastMonthTotal = 0.0;

  // Initialization flag to prevent multiple loads
  bool _isInitialized = false;

  static const String _tag = 'InvestmentProvider';

  List<InvestmentModel> get investments => _investments;
  List<InvestmentTransactionModel> get investmentTransactions => _transactions;
  double get totalInvestments => _totalInvestments;

  InvestmentProvider(this.storage) {
    _initializeData();
  }

  /// Set the balance provider reference
  void setBalanceProvider(BalanceProvider provider) {
    balanceProvider = provider;
    _log('Balance provider set');
  }

  /// Initialize data and start periodic deduction checks
  Future<void> _initializeData() async {
    try {
      _log('Initializing investment data...');
      await loadInvestments();
      await _loadLastInvestmentCheckDate();
      _startMonthlyDeduction();
      _log('Investment data initialized successfully');
    } catch (e, stackTrace) {
      _logError('Failed to initialize investment data', e, stackTrace);
    }
  }

  /// Set the list provider and check for pending deductions
  void setListProvider(ListProvider provider) {
    listProvider = provider;
    _log('List provider set');
    // Check for pending deductions after a brief delay to ensure full initialization
    Future.delayed(Duration(milliseconds: 100), () {
      _checkPendingInvestmentDeductions();
    });
  }

  /// Load investments and reconstruct state
  Future<void> loadInvestments() async {
    // Prevent multiple simultaneous loads
    if (_isInitialized) {
      _log('Already initialized, skipping reload to prevent duplicates');
      return;
    }

    try {
      final raw = await storage.loadInvestments();
      final List<dynamic> items = List<dynamic>.from(raw);

      // Handle multiple possible return formats from storage:
      // 1) List<InvestmentModel> (current storage implementation)
      // 2) List<Map<String, dynamic>> or List<dynamic> where each item is a Map
      // Normalize whatever format storage returned into a List<InvestmentModel>
      _investments = [];
      if (items.isNotEmpty) {
        for (final e in items) {
          try {
            if (e == null) continue;
            if (e is InvestmentModel) {
              _investments.add(e);
            } else if (e is Map) {
              _investments
                  .add(InvestmentModel.fromMap(Map<String, dynamic>.from(e)));
            } else {
              // Try to call toMap() on the object (some storage variants)
              try {
                final dynamicMap = (e as dynamic).toMap();
                if (dynamicMap is Map) {
                  _investments.add(InvestmentModel.fromMap(
                      Map<String, dynamic>.from(dynamicMap)));
                } else {
                  debugPrint(
                      '[InvestmentProvider] Unknown investment item type: ${e.runtimeType}');
                }
              } catch (err) {
                debugPrint(
                    '[InvestmentProvider] Failed to convert investment item of type ${e.runtimeType}: $err');
              }
            }
          } catch (err) {
            debugPrint(
                '[InvestmentProvider] Skipping invalid investment item: $err');
          }
        }
      }

      // Clear and rebuild transactions with distributed dates (approx 30 days apart)
      _transactions.clear();
      for (final inv in _investments) {
        final len = inv.monthlyDeductions.length;
        for (int j = 0; j < len; j++) {
          final amount = inv.monthlyDeductions[j];
          final daysOffset = (len - 1 - j) * 30;
          final txDate =
              inv.lastDeductionDate.subtract(Duration(days: daysOffset));
          _transactions.add(InvestmentTransactionModel(
            amount: amount,
            date: txDate,
            id: '${inv.name}_${amount.toString()}_${txDate.toIso8601String()}_$j',
          ));
        }
      }

      _recalcTotal();
      _log(
          'Loaded ${_investments.length} investments with ${_transactions.length} transactions. Total: $_totalInvestments');

      // Mark as initialized to prevent future reloads
      _isInitialized = true;

      // Notify listeners after loading
      notifyListeners();
    } catch (e, stackTrace) {
      _logError('Failed to load investments', e, stackTrace);
      _investments = [];
      _transactions = [];
      _isInitialized = true; // Mark as initialized even on error
      notifyListeners();
    }
  }

  void _logError(String message, Object error, StackTrace stackTrace) {
    debugPrint('[$_tag ERROR] $message');
    debugPrint('Error details: $error');
    debugPrint('Stack trace: $stackTrace');
  }

  void _log(String message) {
    debugPrint('[$_tag] $message');
  }

  /// Save investments back to storage
  Future<void> saveInvestments() async {
    try {
      await storage.saveInvestments(_investments);
      _log('Investments saved: ${_investments.length} items');
    } catch (e, st) {
      _logError('Failed to save investments', e, st);
    }
  }

  /// Add a new investment with balance deduction
  Future<void> addInvestment(
    String name,
    double amount, {
    String category = 'Other',
    DateTime? startDate,
  }) async {
    try {
      _log('Adding investment: name=$name, amount=$amount, category=$category');

      if (name.isEmpty) {
        _logError('Invalid investment name: name cannot be empty', '',
            StackTrace.current);
        return;
      }
      if (amount <= 0) {
        _logError('Invalid investment amount: amount must be positive', '',
            StackTrace.current);
        return;
      }

      // Check balance if balance provider is available
      if (balanceProvider != null && balanceProvider!.totalBalance < amount) {
        _logError(
            'Insufficient balance (${balanceProvider!.totalBalance}) for investment amount ($amount)',
            '',
            StackTrace.current);
        return;
      }

      // Clean the name
      name = name.replaceAll(RegExp(r'[|\\]'), '');

      final inv = InvestmentModel.create(
        name: name,
        amount: amount,
        category: category,
        startDate: startDate,
      );

      _investments.add(inv);

      // Record the initial transaction (this updates _investments and _transactions)
      _recordTransactionInternal(inv.name, amount,
          date: startDate ?? DateTime.now());

      // Deduct from balance if balance provider is available
      if (balanceProvider != null) {
        balanceProvider!.addExpense(amount);
        _log('Deducted $amount from balance');
      }

      // Add to list provider if available
      if (listProvider != null) {
        final transaction = AllListProvider(
          title: "Investment",
          category: name,
          amount: amount,
          isIncome: false,
          date: (startDate ?? DateTime.now()).toIso8601String(),
          transactionType: TransactionType.investment,
        );

        listProvider!.addTransaction(transaction,
            updateBalance: false); // Don't update balance again
        _log('Added transaction to list provider');
      }

      await saveInvestments();

      // IMPORTANT: Notify listeners once after all operations
      notifyListeners();

      _log(
          'Investment added successfully. Total investments: $_totalInvestments');
    } catch (e, stackTrace) {
      _logError('Failed to add investment', e, stackTrace);
    }
  }

  /// Remove investment by index
  Future<void> removeInvestment(int index) async {
    try {
      _log('Removing investment at index: $index');
      if (index < 0 || index >= _investments.length) {
        _logError('Invalid index for removing investment: $index', '',
            StackTrace.current);
        return;
      }

      final removedInv = _investments.removeAt(index);

      // Remove all transactions associated with this investment
      _transactions
          .removeWhere((tx) => tx.id?.startsWith(removedInv.name) ?? false);

      _recalcTotal();
      await saveInvestments();

      // IMPORTANT: Notify listeners after removal
      notifyListeners();

      _log(
          'Investment "${removedInv.name}" removed successfully. Total: $_totalInvestments');
    } catch (e, stackTrace) {
      _logError('Failed to remove investment at index $index', e, stackTrace);
    }
  }

  /// Records an investment transaction as a permanent historical record.
  void recordInvestmentTransaction(double amount, {DateTime? date}) {
    final transaction = InvestmentTransactionModel(
      amount: amount,
      date: date ?? DateTime.now(),
    );
    investmentTransactions.add(transaction);

    // Recalculate the historical total as the sum of all recorded transactions.
    _totalInvestments =
        investmentTransactions.fold(0.0, (sum, t) => sum + t.amount);

    _log(
      'Recorded transaction: +$amount at ${transaction.date.toIso8601String()}. '
      'New total investments: $_totalInvestments',
    );

    if (balanceProvider != null) {
      balanceProvider!.saveBalances();
    }

    notifyListeners();
  }

  double get percentageChange {
    if (lastMonthTotal == 0) return 0.0;
    return ((totalInvestments - lastMonthTotal) / lastMonthTotal) * 100;
  }

  void updateLastMonthTotal() {
    lastMonthTotal = investments.fold(0.0, (sum, inv) {
      final monthsSinceStart =
          DateTime.now().difference(inv.startDate).inDays / 30;
      return monthsSinceStart >= 1 ? sum + inv.amount : sum;
    });
    notifyListeners();
  }

  /// Removes a historical investment transaction.
  void removeHistoricalInvestmentTransaction(double amount, String dateString) {
    final date = DateTime.parse(dateString);
    final index = investmentTransactions.indexWhere((t) =>
        t.amount == amount && (t.date.difference(date).inSeconds).abs() < 5);

    if (index != -1) {
      investmentTransactions.removeAt(index);
      _totalInvestments =
          investmentTransactions.fold(0.0, (sum, t) => sum + t.amount);

      _log(
        'Removed historical investment transaction of amount $amount. '
        'New total investments: $_totalInvestments',
      );

      if (balanceProvider != null) {
        balanceProvider!.saveBalances();
      }

      notifyListeners();
    } else {
      _log(
        'No matching historical investment transaction found for amount $amount '
        'and date $dateString',
      );
    }
  }

  /// Toggle active state of an investment
  Future<void> toggleInvestmentActive(int index) async {
    try {
      _log('Toggling investment at index: $index');
      if (index < 0 || index >= _investments.length) {
        _logError('Invalid index for toggling investment: $index', '',
            StackTrace.current);
        return;
      }

      final inv = _investments[index];
      final newStatus = !inv.isActive;
      _investments[index] = inv.copyWith(isActive: newStatus);

      await saveInvestments();

      // IMPORTANT: Notify listeners after toggle
      notifyListeners();

      _log(
          'Investment "${inv.name}" toggled to: ${newStatus ? "active" : "inactive"}');
    } catch (e, stackTrace) {
      _logError('Failed to toggle investment at index $index', e, stackTrace);
    }
  }

  /// Internal method to record a deduction transaction for given investment name
  /// This does NOT call notifyListeners - caller is responsible for that
  void _recordTransactionInternal(String invName, double amount,
      {DateTime? date}) {
    try {
      final invIndex = _investments.indexWhere((inv) => inv.name == invName);
      if (invIndex == -1) {
        _logError('Investment not found: $invName', '', StackTrace.current);
        return;
      }

      final inv = _investments[invIndex];
      final dedDate = date ?? DateTime.now();
      final updatedInv = inv.addMonthlyDeduction(amount, dedDate);
      _investments[invIndex] = updatedInv;

      final tx = InvestmentTransactionModel(
        amount: amount,
        date: dedDate,
        id: '${inv.name}_${amount.toString()}_${dedDate.toIso8601String()}_${updatedInv.monthlyDeductions.length}',
      );
      _transactions.add(tx);

      _recalcTotal();
      _log(
          'Recorded transaction: +$amount for $invName at ${dedDate.toIso8601String()}. New total: $_totalInvestments');
    } catch (e, stackTrace) {
      _logError('Failed to record transaction for $invName', e, stackTrace);
    }
  }

  /// Public method to record a transaction (kept for backwards compatibility)
  void recordTransaction(String invName, double amount, {DateTime? date}) {
    _recordTransactionInternal(invName, amount, date: date);
    notifyListeners();
  }

  /// Remove a transaction and its corresponding deduction
  Future<void> removeTransaction(int txIndex) async {
    try {
      _log('Removing transaction at index: $txIndex');
      if (txIndex < 0 || txIndex >= _transactions.length) {
        _logError(
            'Invalid transaction index: $txIndex', '', StackTrace.current);
        return;
      }

      final tx = _transactions.removeAt(txIndex);
      final removedAmount = tx.amount;

      // Find investment by matching id prefix
      final invName = tx.id?.split('_').first;
      final invIndex = _investments.indexWhere((i) => i.name == invName);
      if (invIndex != -1) {
        final inv = _investments[invIndex];
        final dedIndex = inv.monthlyDeductions.indexOf(tx.amount);
        if (dedIndex != -1) {
          _investments[invIndex] = inv.removeMonthlyDeduction(dedIndex);
          _log('Removed deduction of $removedAmount from investment $invName');
        }
      }

      _recalcTotal();
      await saveInvestments();

      // IMPORTANT: Notify listeners after removal
      notifyListeners();

      _log('Transaction removed. New total investments: $_totalInvestments');
    } catch (e, stackTrace) {
      _logError(
          'Failed to remove transaction at index $txIndex', e, stackTrace);
    }
  }

  /// Update investment amount
  Future<void> updateInvestmentAmount(int index, double newAmount) async {
    try {
      _log('Updating investment amount at index $index to $newAmount');
      if (index < 0 || index >= _investments.length) {
        _logError('Invalid index for updating investment amount: $index', '',
            StackTrace.current);
        return;
      }
      if (newAmount <= 0) {
        _logError('Invalid investment amount: $newAmount (must be positive)',
            '', StackTrace.current);
        return;
      }

      final investment = _investments[index];
      _log(
          'Updating ${investment.name} from ${investment.amount} to $newAmount');
      _investments[index] = investment.copyWith(amount: newAmount);

      await saveInvestments();

      // IMPORTANT: Notify listeners after update
      notifyListeners();

      _log('Investment amount updated successfully');
    } catch (e, stackTrace) {
      _logError(
          'Failed to update investment amount at index $index', e, stackTrace);
    }
  }

  /// Generate a summary model
  InvestmentSummaryModel get summary => InvestmentSummaryModel(
        totalInvestments: _totalInvestments,
        transactions: _transactions,
        activeInvestments: _investments.where((i) => i.isActive).toList(),
        inactiveInvestments: _investments.where((i) => !i.isActive).toList(),
      );

  void _recalcTotal() {
    final oldTotal = _totalInvestments;
    _totalInvestments = _transactions.fold(0.0, (sum, tx) => sum + tx.amount);
    _log(
        'Recalc: ${_transactions.length} transactions, total changed from $oldTotal to $_totalInvestments');

    // Debug: Log transaction details to spot duplicates
    if (_transactions.isNotEmpty) {
      final ids = _transactions.map((tx) => tx.id).toSet();
      if (ids.length != _transactions.length) {
        _log(
            'WARNING: Duplicate transaction IDs detected! ${_transactions.length} transactions but only ${ids.length} unique IDs');
      }
    }
  }

  // --------------------------------------------------
  // INVESTMENT DEDUCTION PROCESSING
  // --------------------------------------------------

  /// Start the monthly deduction timer
  void _startMonthlyDeduction() {
    try {
      _log('Starting monthly deduction timer');
      _monthlyDeductionTimer?.cancel(); // Cancel existing timer if any
      _monthlyDeductionTimer = Timer.periodic(const Duration(days: 1), (timer) {
        _log('Timer triggered for investment deduction check');
        if (listProvider != null && balanceProvider != null) {
          _processInvestmentDeductions();
        } else {
          _log(
              'Skipping scheduled investment deduction: providers not available');
        }
      });
    } catch (e, stackTrace) {
      _logError('Failed to start monthly deduction timer', e, stackTrace);
    }
  }

  /// Check for pending investment deductions
  void _checkPendingInvestmentDeductions() {
    try {
      if (listProvider == null || balanceProvider == null) {
        _log(
            'Cannot check pending investment deductions: providers not available');
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

  /// Process investment deductions
  Future<void> _processInvestmentDeductions({bool force = false}) async {
    if (_processingInvestments) {
      _log('Already processing investments. Skipping.');
      return;
    }

    _processingInvestments = true;
    _log('Processing investment deductions... (forced: $force)');

    try {
      _lastInvestmentCheckDate = DateTime.now();
      await storage.saveLastInvestmentCheckDate(_lastInvestmentCheckDate);
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

        // Check balance before deduction
        if (balanceProvider != null &&
            balanceProvider!.totalBalance < inv.amount) {
          _log(
              'Insufficient balance (${balanceProvider!.totalBalance}) for ${inv.name} (${inv.amount}). Skipping deduction.');
          continue;
        }

        _log('Deducting investment: ${inv.name}, amount: ${inv.amount}');

        // Deduct from balance
        if (balanceProvider != null) {
          balanceProvider!.addExpense(inv.amount);
        }

        // Add transaction through list provider
        if (listProvider != null) {
          final transaction = AllListProvider(
            title: "Investment",
            category: inv.name,
            amount: inv.amount,
            isIncome: false,
            date: now.toIso8601String(),
            transactionType: TransactionType.investment,
          );

          listProvider!.addTransaction(transaction,
              updateBalance: false); // Balance already updated above
        }

        // Record transaction internally (without notifying)
        _recordTransactionInternal(inv.name, inv.amount, date: now);
        _log(
            "Updated last deduction date for ${inv.name}: ${now.toIso8601String()}");
        hasDeductions = true;
      }

      if (hasDeductions) {
        await saveInvestments();
        notifyListeners();
        _log(
            'Investment deductions processed successfully. Total: $_totalInvestments');
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

  /// Simulate investment deduction (for testing)
  Future<void> simulateInvestmentDeduction() async {
    try {
      _log('Simulating full investment deduction (forced)');

      // Store current total as "last month" before deduction
      lastMonthTotal = investments.fold(0.0, (sum, inv) => sum + inv.amount);

      await _processInvestmentDeductions(force: true);

      notifyListeners();
    } catch (e, stackTrace) {
      _logError('Failed to simulate investment deduction', e, stackTrace);
    }
  }

  /// Load last investment check date
  Future<void> _loadLastInvestmentCheckDate() async {
    try {
      _log('Loading last investment check date...');
      final lastDate = await storage.loadLastInvestmentCheckDate();
      _lastInvestmentCheckDate = lastDate;
      _log(
          'Last investment check date loaded: ${_lastInvestmentCheckDate.toIso8601String()}');
    } catch (e, stackTrace) {
      _logError('Failed to load last investment check date', e, stackTrace);
      _lastInvestmentCheckDate = DateTime.now();
    }
  }

  Future<void> handleInsightAction(
      String insightId, Map<String, dynamic> metadata) async {
    final amount = (metadata['recommended'] ?? metadata['amount'] ?? 0);
    if ((amount is num) && amount > 0) {
      await addInvestment(metadata['name'] ?? 'AutoSave', (amount).toDouble(),
          category: metadata['category'] ?? 'Savings',
          startDate: DateTime.now());
    }
  }

  /// Clear all investments and transactions
  Future<void> clearAll() async {
    try {
      _log('Clearing all investments and transactions');
      _investments.clear();
      _transactions.clear();
      _totalInvestments = 0;
      _lastInvestmentCheckDate = DateTime.now();

      await saveInvestments();
      await storage.saveLastInvestmentCheckDate(_lastInvestmentCheckDate);

      notifyListeners();
      _log('All investments and transactions cleared');
    } catch (e, stackTrace) {
      _logError('Failed to clear all investments', e, stackTrace);
    }
  }

  @override
  void dispose() {
    _monthlyDeductionTimer?.cancel();
    super.dispose();
  }
}
