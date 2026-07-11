import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'package:wallone/core/models/icon_map_model.dart';
import 'package:wallone/features/investments/models/investment_model.dart';
import 'package:wallone/features/dashboard/providers/balance_provider.dart';
import 'package:wallone/features/investments/providers/investment_provider.dart';
import 'package:wallone/features/transactions/providers/list_provider.dart';
import 'package:wallone/core/utils/constants.dart';

class Budget {
  final String category;
  final double amount;
  double spent;
  final String iconKey;
  final String id;
  final DateTime createdAt;

  Budget({
    required this.category,
    required this.amount,
    required this.spent,
    required this.iconKey,
    String? id,
    DateTime? createdAt,
  })  : id = id ?? DateTime.now().millisecondsSinceEpoch.toString(),
        createdAt = createdAt ?? DateTime.now();

  IconData get icon => iconMap[iconKey] ?? Icons.help_outline;

  double get progress {
    if (amount <= 0) return 0.0;
    final p = spent / amount;
    if (!p.isFinite) return 0.0;
    return p < 0 ? 0.0 : p;
  }

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
      'iconKey': iconKey,
      'createdAt': createdAt.toIso8601String(),
      // Note: We don't save 'spent' to Firestore anymore - it's calculated from transactions
    };
  }

  factory Budget.fromJson(Map<String, dynamic> json) {
    return Budget(
      id: json['id'] as String?,
      category: json['category'] as String,
      amount: (json['amount'] as num).toDouble(),
      spent: 0.0, // Always start at 0, will be calculated from transactions
      iconKey: json['iconKey'] as String,
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'] as String)
          : DateTime.now(),
    );
  }
}

class BudgetProvider with ChangeNotifier {
  final String _tag = 'BudgetProvider';
  final FirebaseFirestore _fs = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  final BalanceProvider _balanceProvider;
  final InvestmentProvider _investmentProvider;
  final ListProvider _listProvider;

  List<Budget> _budgets = [];
  bool _showAllBudgets = false;
  int _currentBudgetIndex = 0;
  bool _showDateTimePicker = false;

  // Firestore listeners
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _budgetsSub;
  StreamSubscription<User?>? _authSub;

  // Listen to investment provider changes
  VoidCallback? _investmentListener;
  VoidCallback? _listProviderListener;

  // Debouncing timer for sync
  Timer? _syncDebounceTimer;
  bool _isSyncing = false;

  BudgetProvider(
    this._balanceProvider,
    this._investmentProvider,
    this._listProvider,
  ) {
    _init();
  }

  void _log(String message) => debugPrint('[$_tag] $message');
  void _logError(String message, dynamic e, StackTrace? st) {
    debugPrint('[$_tag] ERROR: $message');
    if (e != null) debugPrint('[$_tag] Exception: $e');
    if (st != null) debugPrint('[$_tag] Stack: $st');
  }

  void _init() {
    // Subscribe to auth changes to attach/detach budgets collection listener
    _authSub = _auth.authStateChanges().listen((user) {
      _budgetsSub?.cancel();
      _budgetsSub = null;
      _budgets = [];
      notifyListeners();

      if (user != null) {
        _subscribeToBudgets(user.uid);
      }
    });

    // subscribe to investment provider changes to keep spent in sync
    _investmentListener = () {
      _debouncedSync();
    };
    _investmentProvider.addListener(_investmentListener!);

    _listProviderListener = () {
      _debouncedSync();
    };
    _listProvider.addListener(_listProviderListener!);
  }

  // -------------------------
  // Firestore refs
  // -------------------------
  CollectionReference<Map<String, dynamic>>? _budgetsCollection() {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return null;
    return _fs.collection('users').doc(uid).collection('budgets');
  }

  void _subscribeToBudgets(String uid) {
    try {
      final col = _fs.collection('users').doc(uid).collection('budgets');
      // Real-time updates of budgets collection
      _budgetsSub = col.snapshots().listen((snap) {
        _log('Received ${snap.docs.length} budgets from Firestore');

        _budgets = snap.docs.map((d) {
          final data = d.data();
          try {
            return Budget.fromJson({
              'id': d.id,
              'category': data['category'],
              'amount': data['amount'],
              'iconKey': data['iconKey'] ?? 'others',
              'createdAt': data['createdAt'],
            });
          } catch (e) {
            _log('Error parsing budget ${d.id}: $e');
            // Fallback: minimal budget
            return Budget(
                category: data['category'] ?? 'Misc',
                amount: (data['amount'] ?? 0).toDouble(),
                spent: 0.0,
                iconKey: data['iconKey'] ?? 'others',
                id: d.id,
                createdAt: data['createdAt'] != null
                    ? DateTime.parse(data['createdAt'])
                    : DateTime.now());
          }
        }).toList();

        // Immediately recalculate spent from transactions
        _syncSpentFromTransactions();
        notifyListeners();
      }, onError: (e, st) {
        _logError('Budgets snapshot error', e, st);
      });
    } catch (e, st) {
      _logError('Failed to subscribe to budgets', e, st);
    }
  }

  // -------------------------
  // Getters / UI flags
  // -------------------------
  bool get showAllBudgets => _showAllBudgets;
  int get currentBudgetIndex => _currentBudgetIndex;
  bool get showDateTimePicker => _showDateTimePicker;

  List<Budget> get budgets => List.unmodifiable(_budgets);

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

  Budget? getBudgetByCategory(String category) {
    try {
      return _budgets.firstWhere(
        (b) => b.category.toLowerCase() == category.toLowerCase(),
      );
    } catch (_) {
      return null;
    }
  }

  // -------------------------
  // Sync logic - IMPROVED
  // -------------------------

  /// Debounced sync to avoid multiple rapid calls
  void _debouncedSync() {
    _syncDebounceTimer?.cancel();
    _syncDebounceTimer = Timer(const Duration(milliseconds: 300), () {
      _syncSpentFromTransactions();
      notifyListeners();
    });
  }

  /// Immediately sync spent from transactions (synchronous calculation)
  void _syncSpentFromTransactions() {
    if (_isSyncing) {
      _log('Already syncing, skipping...');
      return;
    }

    try {
      _isSyncing = true;
      final transactions = _listProvider.transactions;
      final today = DateTime.now();
      final firstDayOfMonth = DateTime(today.year, today.month, 1);

      _log('Syncing budgets with ${transactions.length} transactions');

      // Reset spent for all budgets
      for (var b in _budgets) {
        b.spent = 0.0;
      }

      // Calculate spent from transactions
      for (var tx in transactions) {
        if (tx.isIncome) continue;

        DateTime? txDate;
        try {
          txDate = DateTime.parse(tx.date);
        } catch (e) {
          _log('Failed to parse transaction date: ${tx.date}');
          continue;
        }

        // Only count transactions from current month.
        // Since transactions are sorted by date descending from Firestore,
        // we can safely break early once we hit an older transaction.
        if (txDate.isBefore(firstDayOfMonth)) {
          break;
        }

        final budget = getBudgetByCategory(tx.category);
        if (budget != null) {
          // Only count transactions that occurred AFTER the budget was created
          if (txDate.isAfter(budget.createdAt) ||
              txDate.isAtSameMomentAs(budget.createdAt)) {
            budget.spent += tx.amount;
            _log(
                'Added ${tx.amount} to ${budget.category} (total: ${budget.spent})');
          }
        }
      }

      _log('Sync complete. Budget totals:');
      for (var b in _budgets) {
        _log('  ${b.category}: ${b.spent} / ${b.amount}');
      }
    } catch (e, st) {
      _logError('Failed to sync spent from transactions', e, st);
    } finally {
      _isSyncing = false;
    }
  }

  // -------------------------
  // CRUD: Add / Update / Remove budgets
  // -------------------------
  Future<bool> addBudget(String category, double amount, String iconKey) async {
    try {
      final col = _budgetsCollection();
      if (col == null) {
        _log('User not signed in - cannot add budget');
        return false;
      }

      // Check if budget already exists for this category
      final existing = getBudgetByCategory(category);
      if (existing != null) {
        _log('Budget already exists for category $category');
        return false;
      }

      final budget = Budget(
        category: category,
        amount: amount,
        spent: 0.0,
        iconKey: iconKey,
      );

      final jsonData = budget.toJson();
      _log('Saving budget to Firebase: $jsonData');

      col.doc(budget.id).set(jsonData).catchError((e) {
        _logError('Failed to add budget to Firestore', e, null);
      });
      // Local cache will update from snapshot listener
      // Then _syncSpentFromTransactions will be called automatically
      _log('✅ Queued budget ${budget.id} to Firestore');
      return true;
    } catch (e, st) {
      _logError('❌ Failed to add budget', e, st);
      return false;
    }
  }

  Future<bool> updateBudget(
      String budgetId, String category, double amount, String iconKey) async {
    try {
      final col = _budgetsCollection();
      if (col == null) {
        _log('User not signed in - cannot update budget');
        return false;
      }

      final budgetIndex = _budgets.indexWhere((b) => b.id == budgetId);
      if (budgetIndex == -1) {
        _log('Budget not found');
        return false;
      }

      final budget = _budgets[budgetIndex];
      final updatedBudget = Budget(
        category: category,
        amount: amount,
        spent: budget.spent, // Keep current spent value
        iconKey: iconKey,
        id: budgetId,
        createdAt: budget.createdAt, // Preserve creation date
      );

      col.doc(budgetId).set(updatedBudget.toJson()).catchError((e) {
        _logError('Failed to update budget in Firestore', e, null);
      });
      _log('✅ Queued update for budget $budgetId');
      return true;
    } catch (e, st) {
      _logError('Failed to update budget', e, st);
      return false;
    }
  }


  Future<void> removeBudget(String id) async {
    try {
      final col = _budgetsCollection();
      if (col == null) return;

      _log('Removing budget $id');
      col.doc(id).delete().catchError((e) {
        _logError('Failed to delete budget in Firestore', e, null);
      });
      // Local cache will update via listener
      _log('✅ Queued removal for budget $id');
    } catch (e, st) {
      _logError('Failed to remove budget', e, st);
    }
  }

  Future<void> createOrUpdateBudget(String category, double amount,
      {String iconKey = 'others'}) async {
    try {
      final existing = getBudgetByCategory(category);
      final col = _budgetsCollection();
      if (col == null) {
        _log('User not signed in - cannot create/update budget');
        return;
      }

      if (existing != null) {
        // Update existing budget
        final updated = Budget(
          category: category,
          amount: amount,
          spent: existing.spent,
          iconKey: iconKey,
          id: existing.id,
          createdAt: existing.createdAt, // Preserve creation date
        );
        col.doc(updated.id).set(updated.toJson()).catchError((e) {
          _logError('Failed to update existing budget for $category', e, null);
        });
        _log('✅ Queued updated existing budget for $category');
      } else {
        // Create new budget
        final newBudget = Budget(
          category: category,
          amount: amount,
          spent: 0.0,
          iconKey: iconKey,
        );
        col.doc(newBudget.id).set(newBudget.toJson()).catchError((e) {
          _logError('Failed to create new budget for $category', e, null);
        });
        _log('✅ Queued new budget for $category');
      }
      // Local cache will update from snapshot
    } catch (e, st) {
      _logError('Failed to createOrUpdateBudget', e, st);
    }
  }

  Future<void> setBudgetAmount(String category, double amount,
      {String iconKey = 'others'}) async {
    await createOrUpdateBudget(category, amount, iconKey: iconKey);
  }

  Future<void> setCategoryLimit(String category, double limit,
      {String iconKey = 'others'}) async {
    await createOrUpdateBudget(category, limit, iconKey: iconKey);
  }

  // -------------------------
  // Helpers exposing balances/investments
  // -------------------------
  double get monthlyIncome => _balanceProvider.monthlyIncomes;

  /// Net worth: total liquid balance + total invested amount.
  double get netWorth => totalBalance + totalInvestments;

  double get dailyUsage {
    final now = DateTime.now();
    final daysInMonth = DateTime(now.year, now.month + 1, 0).day;
    final remainingDays = daysInMonth - now.day + 1;
    final remainingBalance = totalBalance;
    return remainingDays > 0
        ? remainingBalance / remainingDays
        : remainingBalance;
  }

  double get weeklyUsage {
    final remainingBalance = totalBalance;
    if (remainingBalance <= 0) return 0.0;
    return remainingBalance / 7.0;
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
  double get monthlySavings => _balanceProvider.monthlyIncomes - _balanceProvider.monthlyExpenses;

  double get totalBalance => _balanceProvider.totalBalance;

  // -------------------------
  // Investment date/time helpers (needed by investment card UI)
  // -------------------------
  DateTime selectedInvestmentDate = DateTime.now();
  TimeOfDay selectedInvestmentTime = TimeOfDay.fromDateTime(DateTime.now());

  void updateInvestmentDateTime(DateTime newDateTime) {
    selectedInvestmentDate = newDateTime;
    selectedInvestmentTime = TimeOfDay.fromDateTime(newDateTime);
    notifyListeners();
  }

  List<InvestmentModel> get allInvestments => _investmentProvider.investments;

  // -------------------------
  // Insight actions
  // -------------------------
  Future<void> applyInsightAction(
      String insightId, Map<String, dynamic> metadata) async {
    final amount = (metadata['recommended'] ?? metadata['amount'] ?? 0);
    final category =
        (metadata['category'] ?? metadata['targetCategory'] ?? 'Misc')
            .toString();

    if ((amount is num) && amount > 0) {
      await createOrUpdateBudget(category, (amount).toDouble());
      return;
    }

    if (metadata['action'] == 'savings') {
      await _investmentProvider.addInvestment(metadata['name'] ?? 'AutoSave',
          (amount is num) ? (amount).toDouble() : 0.0,
          category: 'Savings', startDate: DateTime.now());
      return;
    }

    debugPrint('applyInsightAction: no rule matched for insight $insightId');
  }

  // -------------------------
  // Manual refresh (useful for debugging)
  // -------------------------
  void forceRefresh() {
    _log('Force refresh requested');
    _syncSpentFromTransactions();
    notifyListeners();
  }

  // -------------------------
  // Cleanup & verification
  // -------------------------
  Future<void> clearAllBudgetsFromFirestore() async {
    try {
      final col = _budgetsCollection();
      if (col == null) return;
      QuerySnapshot<Map<String, dynamic>> q;
      do {
        q = await col.limit(500).get();
        if (q.docs.isEmpty) break;
        final batch = _fs.batch();
        for (final d in q.docs) {
          batch.delete(d.reference);
        }
        await batch.commit();
      } while (q.docs.isNotEmpty);
      _log('All budgets cleared from Firestore');
    } catch (e, st) {
      _logError('Failed to clear budgets collection', e, st);
    }
  }

  @override
  void dispose() {
    _syncDebounceTimer?.cancel();
    _budgetsSub?.cancel();
    _budgetsSub = null;
    _authSub?.cancel();
    _authSub = null;
    if (_investmentListener != null) {
      _investmentProvider.removeListener(_investmentListener!);
    }
    if (_listProviderListener != null) {
      _listProvider.removeListener(_listProviderListener!);
    }
    super.dispose();
  }
}
