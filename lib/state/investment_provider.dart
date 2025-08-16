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
    // Don't automatically load transactions here to avoid circular calls
    // Instead, check for pending deductions after a brief delay
    Future.delayed(Duration(milliseconds: 100), () {
      _checkPendingInvestmentDeductions();
    });
  }

  /// Load investments and reconstruct state
  Future<void> loadInvestments() async {
    try {
      final raw = await storage.loadInvestments();
      _investments = raw
          .map((e) => InvestmentModel.fromMap(
                Map<String, dynamic>.from(e as Map),
              ))
          .toList();

      // Rebuild transactions list from monthly deductions
      _transactions.clear();
      for (final inv in _investments) {
        for (int i = 0; i < inv.monthlyDeductions.length; i++) {
          final amount = inv.monthlyDeductions[i];
          _transactions.add(InvestmentTransactionModel(
            amount: amount,
            date: inv.lastDeductionDate,
            id: '${inv.name}_${amount.toString()}_${inv.lastDeductionDate.toIso8601String()}_$i',
          ));
        }
      }

      _recalcTotal();
      _log(
          'Loaded ${_investments.length} investments with ${_transactions.length} transactions');

      // Notify listeners after loading
      notifyListeners();
    } catch (e, stackTrace) {
      _logError('Failed to load investments', e, stackTrace);
      _investments = [];
      _transactions = [];
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

      // Record the initial transaction
      recordTransaction(inv.name, amount, date: startDate ?? DateTime.now());

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
        );

        listProvider!.addTransaction(transaction,
            updateBalance: false); // Don't update balance again
        _log('Added transaction to list provider');
      }

      await saveInvestments();

      // IMPORTANT: Notify listeners after all operations
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

      _log('Investment "${removedInv.name}" removed successfully');
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

  /// Record a deduction transaction for given investment name
  void recordTransaction(String invName, double amount, {DateTime? date}) {
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
        id: '${inv.name}_${dedDate.toIso8601String()}_${inv.monthlyDeductions.length}',
      );
      _transactions.add(tx);

      _recalcTotal();
      _log(
          'Recorded transaction: +$amount for $invName at ${dedDate.toIso8601String()}. New total: $_totalInvestments');

      // Note: Don't call notifyListeners here if called from addInvestment to avoid double notification
    } catch (e, stackTrace) {
      _logError('Failed to record transaction for $invName', e, stackTrace);
    }
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
    _totalInvestments = _transactions.fold(0.0, (sum, tx) => sum + tx.amount);
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
          );

          listProvider!.addTransaction(transaction,
              updateBalance: false); // Balance already updated above
        }

        // Update investment
        final invIndex = _investments.indexWhere((i) => i.name == inv.name);
        if (invIndex != -1) {
          _investments[invIndex] = inv.addMonthlyDeduction(inv.amount, now);
          _log(
              "Updated last deduction date for ${inv.name}: ${now.toIso8601String()}");
        }

        // Record transaction
        recordTransaction(inv.name, inv.amount, date: now);
        hasDeductions = true;
      }

      if (hasDeductions) {
        await saveInvestments();
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

  /// Simulate investment deduction (for testing)
  Future<void> simulateInvestmentDeduction() async {
    try {
      _log('Simulating full investment deduction (forced)');
      await _processInvestmentDeductions(force: true);
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
