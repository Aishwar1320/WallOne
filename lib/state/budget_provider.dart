import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'package:wallone/models/icon_map_model.dart';
import 'package:wallone/models/investment_model.dart';
import 'package:wallone/state/balance_provider.dart';
import 'package:wallone/state/investment_provider.dart';
import 'package:wallone/utils/constants.dart';

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
      'spent': spent,
      'iconKey': iconKey,
    };
  }

  factory Budget.fromJson(Map<String, dynamic> json) {
    return Budget(
      id: json['id'] as String?,
      category: json['category'] as String,
      amount: (json['amount'] as num).toDouble(),
      spent: (json['spent'] as num).toDouble(),
      iconKey: json['iconKey'] as String,
    );
  }
}

class BudgetProvider with ChangeNotifier {
  final String _tag = 'BudgetProvider';
  final FirebaseFirestore _fs = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  final BalanceProvider _balanceProvider;
  final InvestmentProvider _investmentProvider;

  List<Budget> _budgets = [];
  bool _showAllBudgets = false;
  int _currentBudgetIndex = 0;
  bool _showDateTimePicker = false;

  // Firestore listeners
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _budgetsSub;
  StreamSubscription<User?>? _authSub;

  // Listen to investment provider changes
  VoidCallback? _investmentListener;

  BudgetProvider(this._balanceProvider, this._investmentProvider) {
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
      _syncWithBalanceProvider();
    };
    _investmentProvider.addListener(_investmentListener!);
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
        _budgets = snap.docs.map((d) {
          final data = d.data();
          try {
            return Budget.fromJson({
              'id': d.id,
              'category': data['category'],
              'amount': data['amount'],
              'spent': data['spent'] ?? 0.0,
              'iconKey': data['iconKey'] ?? 'others',
            });
          } catch (e) {
            // Fallback: minimal budget
            return Budget(
                category: data['category'] ?? 'Misc',
                amount: (data['amount'] ?? 0).toDouble(),
                spent: (data['spent'] ?? 0).toDouble(),
                iconKey: data['iconKey'] ?? 'others',
                id: d.id);
          }
        }).toList();

        // After loading budgets from Firestore, recalc spent from transactions
        _syncWithBalanceProvider(notify: false);
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
  // Sync logic - compute spent from transactions - FIXED
  // -------------------------
  /// Recomputes `spent` for each budget by scanning transactions from the investmentProvider's listProvider.
  /// If notify==true, calls notifyListeners() after recomputing.
  void _syncWithBalanceProvider({bool notify = true}) {
    try {
      // FIXED: Check if listProvider exists before accessing
      if (_investmentProvider.listProvider == null) {
        _log('listProvider is null - skipping sync');
        return;
      }

      final listProv = _investmentProvider.listProvider!;
      final transactions = listProv.transactions;
      final today = DateTime.now();
      final firstDayOfMonth = DateTime(today.year, today.month, 1);

      // reset spent
      for (var b in _budgets) {
        b.spent = 0.0;
      }

      for (var tx in transactions) {
        if (tx.isIncome) continue;
        // transaction.date is expected to be ISO string; adapt if different
        DateTime? txDate;
        try {
          txDate = DateTime.parse(tx.date);
        } catch (_) {
          continue;
        }
        if (txDate.isBefore(firstDayOfMonth)) continue;

        final budget = getBudgetByCategory(tx.category);
        if (budget != null) {
          budget.spent += tx.amount;
        }
      }

      // persist spent changes back to Firestore (optional)
      _persistSpentForAllBudgets().catchError((e, st) {
        _logError('Failed to persist spent after sync', e, st);
      });

      if (notify) notifyListeners();
    } catch (e, st) {
      _logError('Failed to sync with balanceProvider', e, st);
    }
  }

  Future<void> _persistSpentForAllBudgets() async {
    try {
      final col = _budgetsCollection();
      if (col == null) return;
      final batch = _fs.batch();
      for (final budget in _budgets) {
        final docRef = col.doc(budget.id);
        batch.set(docRef, {'spent': budget.spent}, SetOptions(merge: true));
      }
      await batch.commit();
    } catch (e, st) {
      _logError('Error persisting spent values', e, st);
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

      final budget = Budget(
        category: category,
        amount: amount,
        spent: 0.0,
        iconKey: iconKey,
      );

      await col.doc(budget.id).set(budget.toJson());
      // local cache will update from snapshot listener
      _log('Added budget ${budget.id}');
      return true;
    } catch (e, st) {
      _logError('Failed to add budget', e, st);
      return false;
    }
  }

  /// Updates a budget's spent (client-side) and persists
  Future<void> updateBudgetSpent(String id, double spent) async {
    try {
      final idx = _budgets.indexWhere((b) => b.id == id);
      if (idx != -1) {
        _budgets[idx].spent = spent;
        notifyListeners();
        final col = _budgetsCollection();
        if (col != null) {
          await col.doc(id).set({'spent': spent}, SetOptions(merge: true));
        }
      }
    } catch (e, st) {
      _logError('Failed to update budget spent', e, st);
    }
  }

  Future<void> removeBudget(String id) async {
    try {
      final col = _budgetsCollection();
      if (col == null) return;
      await col.doc(id).delete().catchError((_) {});
      // local cache will update via listener
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
        final updated = Budget(
          category: category,
          amount: amount,
          spent: existing.spent,
          iconKey: iconKey,
          id: existing.id,
        );
        await col
            .doc(updated.id)
            .set(updated.toJson(), SetOptions(merge: true));
      } else {
        final newBudget = Budget(
          category: category,
          amount: amount,
          spent: 0.0,
          iconKey: iconKey,
        );
        await col.doc(newBudget.id).set(newBudget.toJson());
      }
      // local cache will update from snapshot
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

  double get monthlySavings => totalBalance + totalInvestments;

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

  double get totalBalance => _balanceProvider.totalBalance;

  // -------------------------
  // Investment helpers (pass-throughs)
  // -------------------------
  void addInvestment(String label, double amount,
      {String category = 'Stocks',
      DateTime? startDate,
      bool isOneTime = false}) {
    _investmentProvider.addInvestment(label, amount,
        category: category, startDate: startDate, isOneTime: isOneTime);
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
    _budgetsSub?.cancel();
    _authSub?.cancel();
    if (_investmentListener != null) {
      _investmentProvider.removeListener(_investmentListener!);
    }
    super.dispose();
  }
}
