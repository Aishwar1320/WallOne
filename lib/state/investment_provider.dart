import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'package:wallone/models/investment_model.dart';
import 'package:wallone/models/investment_transaction_model.dart';
import 'package:wallone/models/investment_summary_model.dart';
import 'package:wallone/state/list_provider.dart';
import 'package:wallone/state/balance_provider.dart';

/// Firestore-based InvestmentProvider with robust initialization and error handling
/// Firestore layout used:
/// users/{uid}/investments/current
/// users/{uid}/investments/list/{investmentId}
/// users/{uid}/investments/transactions/{txId}
class InvestmentProvider with ChangeNotifier {
  final String _tag = 'InvestmentProvider';
  final FirebaseFirestore _fs = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // External providers
  ListProvider? listProvider;
  BalanceProvider? balanceProvider;

  /// Per-investment simulation dates — each investment tracks its own
  /// next simulated deduction month independently.
  final Map<String, DateTime> _simulationDates = {};

  /// Returns (and lazily initialises) the next simulation date for [key].
  DateTime _nextSimDate(String key) {
    if (!_simulationDates.containsKey(key)) {
      // Find the investment to get its actual last deduction date
      final inv = _investments.cast<InvestmentModel?>().firstWhere(
            (i) => i?.id == key || i?.name == key,
            orElse: () => null,
          );

      DateTime baseDate = inv?.lastDeductionDate ?? DateTime.now();
      _simulationDates[key] =
          DateTime(baseDate.year, baseDate.month + 1, baseDate.day);
    }
    return _simulationDates[key]!;
  }

  // In-memory caches
  List<InvestmentModel> _investments = [];
  List<InvestmentTransactionModel> _transactions = [];
  double _totalInvestments = 0.0;

  // Tracking for percentage change (cumulative)
  double _percentageChange = 0.0;
  double _cumulativeExpected = 0.0;
  double _cumulativeActual = 0.0;
  final List<double> _percentageHistory = [];
  double lastMonthTotal = 0.0;

  // state flags
  bool _processingInvestments = false;
  bool _isInitialized = false;

  // Firestore subs
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _investmentsSub;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _transactionsSub;
  StreamSubscription<User?>? _authSub;

  InvestmentProvider() {
    _init();
  }

  @override
  void dispose() {
    _investmentsSub?.cancel();
    _investmentsSub = null;
    _transactionsSub?.cancel();
    _transactionsSub = null;
    _authSub?.cancel();
    _authSub = null;
    super.dispose();
  }

  // -------------------------
  // Logging helpers
  // -------------------------
  void _log(String msg) => debugPrint('[$_tag] $msg');
  void _logError(String msg, dynamic e, StackTrace? st) {
    debugPrint('[$_tag] ERROR: $msg');
    if (e != null) debugPrint('[$_tag] Exception: $e');
    if (st != null) debugPrint('[$_tag] Stack: $st');
  }

  // -------------------------
  // Public getters
  // -------------------------
  List<InvestmentModel> get investments => List.unmodifiable(_investments);
  List<InvestmentTransactionModel> get investmentTransactions =>
      List.unmodifiable(_transactions);
  double get totalInvestments => _totalInvestments;

  InvestmentSummaryModel get summary => InvestmentSummaryModel(
        totalInvestments: _totalInvestments,
        transactions: List.unmodifiable(_transactions),
        activeInvestments:
            _investments.where((i) => i.isActive).toList(growable: false),
        inactiveInvestments:
            _investments.where((i) => !i.isActive).toList(growable: false),
      );

  double get percentageChange => _percentageChange;
  List<double> get percentageHistory => List.unmodifiable(_percentageHistory);

  /// Recalculate percentage based on cumulative expected vs actual.
  /// [expectedThisCycle] = amount expected this cycle (all recurring)
  /// [actualThisCycle] = amount actually invested this cycle (active recurring)
  void _recalcPercentage({
    required double expectedThisCycle,
    required double actualThisCycle,
  }) {
    _cumulativeExpected += expectedThisCycle;
    _cumulativeActual += actualThisCycle;

    if (_cumulativeExpected <= 0) {
      _percentageChange = 0.0;
    } else {
      _percentageChange =
          ((_cumulativeActual / _cumulativeExpected) * 100).clamp(0.0, 100.0);
    }
    _percentageHistory.add(_percentageChange);
  }

  Map<String, dynamic> toJson() {
    return {
      'totalInvestment': _totalInvestments,
    };
  }

  // -------------------------
  // Provider setters
  // -------------------------
  void setBalanceProvider(BalanceProvider provider) {
    balanceProvider = provider;
    _log('Balance provider set');
  }

  void setListProvider(ListProvider provider) {
    listProvider = provider;
    _log('List provider set');
    // Check for pending deductions after a brief delay to ensure full initialization
    Future.delayed(const Duration(milliseconds: 100), () {
      _checkPendingInvestmentDeductions();
    });
  }

  // -------------------------
  // Firestore refs
  // -------------------------
  DocumentReference<Map<String, dynamic>>? _currentDocRefForUid(String? uid) {
    if (uid == null) return null;
    return _fs
        .collection('users')
        .doc(uid)
        .collection('investments')
        .doc('current');
  }

  CollectionReference<Map<String, dynamic>>? _listColForUid(String? uid) {
    if (uid == null) return null;
    return _fs
        .collection('users')
        .doc(uid)
        .collection('investments')
        .doc('current')
        .collection('list');
  }

  CollectionReference<Map<String, dynamic>>? _txColForUid(String? uid) {
    if (uid == null) return null;
    return _fs
        .collection('users')
        .doc(uid)
        .collection('investments')
        .doc('current')
        .collection('transactions');
  }

  DocumentReference<Map<String, dynamic>>? get _currentDocRef {
    final uid = _auth.currentUser?.uid;
    return _currentDocRefForUid(uid);
  }

  CollectionReference<Map<String, dynamic>>? get _listCol {
    final uid = _auth.currentUser?.uid;
    return _listColForUid(uid);
  }

  CollectionReference<Map<String, dynamic>>? get _txCol {
    final uid = _auth.currentUser?.uid;
    return _txColForUid(uid);
  }

  // -------------------------
  // Initialization: auth watcher + subscriptions
  // -------------------------
  void _init() {
    _authSub = _auth.authStateChanges().listen((user) {
      // cancel previous subscriptions
      _investmentsSub?.cancel();
      _transactionsSub?.cancel();
      _investmentsSub = null;
      _transactionsSub = null;

      _investments = [];
      _transactions = [];
      _totalInvestments = 0.0;
      _percentageChange = 0.0;
      _cumulativeExpected = 0.0;
      _cumulativeActual = 0.0;
      _percentageHistory.clear();
      _isInitialized = false;
      notifyListeners();

      if (user != null) {
        _subscribeToInvestments(user.uid);
        _subscribeToTransactions(user.uid);
        // load once and process pending deductions on login
        _loadMetaAndRunInit();
      }
    });
  }

  Future<void> _loadMetaAndRunInit() async {
    try {
      _log('Initializing investment data...');
      await loadInvestments(); // loads investments into _investments
      await loadTransactions(); // loads stored transactions
      await _updateTotalFromTransactions();

      // Check for pending deductions after initialization
      Future.delayed(const Duration(milliseconds: 500), () {
        if (listProvider != null && balanceProvider != null) {
          _checkPendingInvestmentDeductions();
        }
      });

      _isInitialized = true;
      _log('Investment data initialized successfully');
    } catch (e, st) {
      _logError('Failed to initialize investment data', e, st);
      _isInitialized = true; // Mark as initialized even on error
    }
  }

  // -------------------------
  // Subscriptions
  // -------------------------
  void _subscribeToInvestments(String uid) {
    try {
      final col = _listColForUid(uid);
      if (col == null) return;

      _investmentsSub = col.snapshots().listen((snap) {
        // Prevent duplicate loads
        if (_isInitialized && snap.docs.length == _investments.length) {
          _log('Skipping duplicate investment load');
          return;
        }

        _investments = snap.docs.map((d) {
          final m = d.data();
          try {
            return InvestmentModel.fromMap({
              'name': m['name'] ?? d.id,
              'amount': _toDouble(m['amount']),
              'category': m['category'] ?? 'Other',
              'startDate': _parseTimestamp(m['startDate']) ?? DateTime.now(),
              'isActive': m['isActive'] ?? true,
              'monthlyDeductions': (m['monthlyDeductions'] as List<dynamic>?)
                      ?.map((e) => _toDouble(e))
                      .toList() ??
                  [],
              'id': d.id,
              'lastDeductionDate':
                  _parseTimestamp(m['lastDeductionDate']) ?? DateTime.now(),
              'isOneTime': m['isOneTime'] ?? false,
            });
          } catch (e) {
            _logError('Error parsing investment ${d.id}', e, null);
            // fallback minimal model
            return InvestmentModel.create(
              name: m['name'] ?? d.id,
              amount: _toDouble(m['amount']),
              category: m['category'] ?? 'Other',
              startDate: _parseTimestamp(m['startDate']) ?? DateTime.now(),
              isOneTime: m['isOneTime'] as bool? ?? false,
            );
          }
        }).toList();

        _updateTotalFromTransactions();
        notifyListeners();
      }, onError: (e, st) {
        _logError('Investments snapshot error', e, st);
      });
    } catch (e, st) {
      _logError('Failed to subscribe to investments', e, st);
    }
  }

  void _subscribeToTransactions(String uid) {
    try {
      final col = _txColForUid(uid);
      if (col == null) return;

      _transactionsSub = col.snapshots().listen((snap) {
        _transactions = snap.docs.map((d) {
          final m = d.data();
          DateTime dt = _parseTimestamp(m['date']) ?? DateTime.now();
          return InvestmentTransactionModel(
            id: d.id,
            amount: _toDouble(m['amount']),
            date: dt,
            investmentName: m['investmentName'] as String? ?? '',
            note: m['note'] as String?,
          );
        }).toList();

        // Check for duplicate transaction IDs
        final ids = _transactions.map((tx) => tx.id).toSet();
        if (ids.length != _transactions.length) {
          _log(
              'WARNING: Duplicate transaction IDs detected! ${_transactions.length} transactions but only ${ids.length} unique IDs');
        }

        _updateTotalFromTransactions();
        notifyListeners();
      }, onError: (e, st) {
        _logError('Transactions snapshot error', e, st);
      });
    } catch (e, st) {
      _logError('Failed to subscribe to transactions', e, st);
    }
  }

  // -------------------------
  // Helper: Parse Timestamp or DateTime string and convert to double
  // -------------------------
  DateTime? _parseTimestamp(dynamic value) {
    if (value == null) return null;
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is String) {
      try {
        return DateTime.parse(value);
      } catch (_) {
        return null;
      }
    }
    return null;
  }

  double _toDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is num) return value.toDouble();
    try {
      return double.parse(value.toString());
    } catch (_) {
      return 0.0;
    }
  }

  // -------------------------
  // Load once helpers (if needed)
  // -------------------------
  Future<void> loadInvestments() async {
    // Prevent multiple simultaneous loads
    if (_isInitialized) {
      _log('Already initialized, skipping reload to prevent duplicates');
      return;
    }

    try {
      final col = _listCol;
      if (col == null) return;

      final snap = await col.get();
      _investments = snap.docs.map((d) {
        final m = d.data();
        return InvestmentModel.fromMap({
          'name': m['name'] ?? d.id,
          'amount': _toDouble(m['amount']),
          'category': m['category'] ?? 'Other',
          'startDate': _parseTimestamp(m['startDate']) ?? DateTime.now(),
          'isActive': m['isActive'] ?? true,
          'monthlyDeductions': (m['monthlyDeductions'] as List<dynamic>?)
                  ?.map((e) => _toDouble(e))
                  .toList() ??
              [],
          'id': d.id,
          'lastDeductionDate':
              _parseTimestamp(m['lastDeductionDate']) ?? DateTime.now(),
          'isOneTime': m['isOneTime'] ?? false,
        });
      }).toList();

      _log('Loaded ${_investments.length} investments');
      notifyListeners();
    } catch (e, st) {
      _logError('Failed to load investments', e, st);
    }
  }

  Future<void> loadTransactions() async {
    try {
      final col = _txCol;
      if (col == null) return;

      final snap = await col.orderBy('date', descending: true).get();
      _transactions = snap.docs.map((d) {
        final m = d.data();
        DateTime dt = _parseTimestamp(m['date']) ?? DateTime.now();
        return InvestmentTransactionModel(
          id: d.id,
          amount: _toDouble(m['amount']),
          date: dt,
          investmentName: m['investmentName'] as String? ?? '',
          note: m['note'] as String?,
        );
      }).toList();

      _log('Loaded ${_transactions.length} transactions');
      notifyListeners();
    } catch (e, st) {
      _logError('Failed to load transactions', e, st);
    }
  }

  // -------------------------
  // Save / persist investments & transactions
  // -------------------------
  Future<void> saveInvestments() async {
    try {
      final col = _listCol;
      if (col == null) {
        throw Exception('User must be signed in to save investments');
      }

      final batch = _fs.batch();
      for (final inv in _investments) {
        final docRef = col.doc(inv.id ?? inv.name);
        final data = {
          'name': inv.name,
          'amount': inv.amount,
          'category': inv.category,
          'startDate': Timestamp.fromDate(inv.startDate),
          'isActive': inv.isActive,
          'monthlyDeductions': inv.monthlyDeductions,
          'lastDeductionDate': Timestamp.fromDate(inv.lastDeductionDate),
        };
        batch.set(docRef, data, SetOptions(merge: true));
      }
      await batch.commit();
      _log('Saved ${_investments.length} investments to Firestore');

      // update current doc's totalInvestments
      await _updateCurrentDocMeta();
    } catch (e, st) {
      _logError('Failed to save investments', e, st);
    }
  }

  Future<void> _saveTransactionToFirestore(
      InvestmentTransactionModel tx) async {
    try {
      final col = _txCol;
      if (col == null) {
        throw Exception('User must be signed in to save transactions');
      }
      final docRef = col.doc(tx.id ?? _newTxId(tx));
      await docRef.set({
        'amount': tx.amount,
        'date': Timestamp.fromDate(tx.date),
        'investmentName': tx.investmentName ?? '',
        if (tx.note != null) 'note': tx.note,
      }, SetOptions(merge: true));
      _log('Saved transaction ${docRef.id}');
    } catch (e, st) {
      _logError('Failed to save transaction', e, st);
    }
  }

  Future<void> _deleteTransactionFromFirestore(String txId) async {
    try {
      final col = _txCol;
      if (col == null) return;
      await col.doc(txId).delete().catchError((_) {});
      _log('Deleted transaction $txId');
    } catch (e, st) {
      _logError('Failed to delete transaction $txId', e, st);
    }
  }

  // -------------------------
  // Utility helpers
  // -------------------------
  String _newTxId(InvestmentTransactionModel tx) {
    return '${tx.investmentName}_${tx.amount}_${tx.date.millisecondsSinceEpoch}';
  }

  Future<void> _updateTotalFromTransactions() async {
    final old = _totalInvestments;
    _totalInvestments = _transactions.fold(0.0, (s, tx) => s + tx.amount);

    _log(
        'Recalc: ${_transactions.length} transactions, total changed from $old to $_totalInvestments');

    if (_totalInvestments != old) {
      await _updateCurrentDocMeta();
    }
  }

  Future<void> _updateCurrentDocMeta() async {
    try {
      final current = _currentDocRef;
      if (current == null) return;
      await current.set({
        'totalInvestments': _totalInvestments,
        'lastInvestmentCheckDate': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e, st) {
      _logError('Failed to update current meta doc', e, st);
    }
  }

  void updateLastMonthTotal() {
    lastMonthTotal = investments.fold(0.0, (sum, inv) {
      final monthsSinceStart =
          DateTime.now().difference(inv.startDate).inDays / 30;
      return monthsSinceStart >= 1 ? sum + inv.amount : sum;
    });
    notifyListeners();
  }

  // -------------------------
  // CRUD operations
  // -------------------------
  Future<void> addInvestment(
    String name,
    double amount, {
    String category = 'Other',
    DateTime? startDate,
    bool isOneTime = false,
  }) async {
    try {
      _log(
          'Adding investment: name=$name, amount=$amount, category=$category, isOneTime=$isOneTime');

      if (name.trim().isEmpty) {
        throw Exception('Investment name cannot be empty');
      }
      if (amount <= 0) {
        throw Exception('Amount must be > 0');
      }

      // Check balance if balance provider is available
      if (balanceProvider != null && balanceProvider!.totalBalance < amount) {
        _logError(
            'Insufficient balance (${balanceProvider!.totalBalance}) for investment amount ($amount)',
            '',
            StackTrace.current);
        return;
      }

      final col = _listCol;
      if (col == null) {
        _log('User not signed in - cannot add investment');
        return;
      }

      // Clean the name
      name = name.replaceAll(RegExp(r'[|\\]'), '');

      final inv = InvestmentModel.create(
        name: name,
        amount: amount,
        category: category,
        startDate: startDate,
        isOneTime: isOneTime,
      );

      // Persist investment doc
      final docRef = col.doc(inv.id ?? inv.name);
      await docRef.set({
        'name': inv.name,
        'amount': inv.amount,
        'category': inv.category,
        'startDate': Timestamp.fromDate(inv.startDate),
        'isActive': inv.isActive,
        'monthlyDeductions': inv.monthlyDeductions,
        'lastDeductionDate': Timestamp.fromDate(inv.lastDeductionDate),
        'isOneTime': inv.isOneTime ?? false,
      }, SetOptions(merge: true));

      // Deduct amount from balance and add a transaction record
      final now = startDate ?? DateTime.now();
      final tx = InvestmentTransactionModel(
        id: _newTxId(InvestmentTransactionModel(
            amount: amount, date: now, investmentName: inv.name)),
        amount: amount,
        date: now,
        investmentName: inv.name,
        note: 'Initial investment',
      );
      await _saveTransactionToFirestore(tx);

      // If balanceProvider is available, deduct
      if (balanceProvider != null) {
        balanceProvider!.addExpense(amount);
        _log('Deducted $amount from balance');
      }

      // If listProvider is available, add an app-level transaction
      if (listProvider != null) {
        final listTx = AllListProvider(
          title: 'Investment',
          category: inv.name,
          amount: amount,
          isIncome: false,
          date: now.toIso8601String(),
          transactionType: TransactionType.investment,
        );
        await listProvider!.addTransaction(listTx, updateBalance: false);
        _log('Added transaction to list provider');
      }

      // Local cache will update via snapshot; but we also force a reload to ensure consistency
      await loadInvestments();
      await loadTransactions();
      await _updateTotalFromTransactions();

      final bool isRecur = !isOneTime;
      _recalcPercentage(
        expectedThisCycle: isRecur ? amount : 0.0,
        actualThisCycle: isRecur ? amount : 0.0,
      );
      notifyListeners();
      _log(
          'Investment added successfully. Total investments: $_totalInvestments');
    } catch (e, st) {
      _logError('Failed to add investment', e, st);
    }
  }

  Future<void> removeInvestment(int index) async {
    try {
      _log('Removing investment at index: $index');
      if (index < 0 || index >= _investments.length) {
        _logError('Invalid index for removeInvestment: $index', null, null);
        return;
      }

      final inv = _investments[index];
      final col = _listCol;
      if (col != null) {
        await col.doc(inv.id ?? inv.name).delete().catchError((_) {});
      }

      // delete associated transactions
      final txCol = _txCol;
      if (txCol != null) {
        final q =
            await txCol.where('investmentName', isEqualTo: inv.name).get();
        final batch = _fs.batch();
        for (final d in q.docs) batch.delete(d.reference);
        if (q.docs.isNotEmpty) await batch.commit();
      }

      // reload
      await loadInvestments();
      await loadTransactions();
      await _updateTotalFromTransactions();

      if (_investments.isEmpty) {
        _percentageChange = 0.0;
        _cumulativeExpected = 0.0;
        _cumulativeActual = 0.0;
        _percentageHistory.clear();
      }

      notifyListeners();
      _log(
          'Investment "${inv.name}" removed successfully. Total: $_totalInvestments');
    } catch (e, st) {
      _logError('Failed to remove investment', e, st);
    }
  }

  Future<void> toggleInvestmentActive(int index) async {
    try {
      _log('Toggling investment at index: $index');
      if (index < 0 || index >= _investments.length) return;

      final inv = _investments[index];
      final newStatus = !inv.isActive;
      final col = _listCol;
      if (col == null) return;

      final docRef = col.doc(inv.id ?? inv.name);
      await docRef.set({'isActive': newStatus}, SetOptions(merge: true));

      // local cache will be updated by snapshot; but update immediately for UX
      _investments[index] = inv.copyWith(isActive: newStatus);

      notifyListeners();
      _log(
          'Investment "${inv.name}" toggled to: ${newStatus ? "active" : "inactive"}');
    } catch (e, st) {
      _logError('Failed to toggle investment active', e, st);
    }
  }

  Future<void> updateInvestmentAmount(int index, double amount) async {
    try {
      _log('Updating investment amount at index $index to $amount');
      if (index < 0 || index >= _investments.length) return;
      if (amount <= 0) throw Exception('Amount must be positive');

      final inv = _investments[index];
      final col = _listCol;
      if (col == null) return;

      final docRef = col.doc(inv.id ?? inv.name);
      await docRef.set({'amount': amount}, SetOptions(merge: true));

      // local optimistic update
      _investments[index] = inv.copyWith(amount: amount);

      notifyListeners();
      _log('Investment amount updated successfully');
    } catch (e, st) {
      _logError('Failed to update investment amount', e, st);
    }
  }

  // -------------------------
  // Transaction helpers
  // -------------------------
  Future<void> recordInvestmentTransaction(double amount,
      {DateTime? date, String? investmentName, String? note}) async {
    try {
      final now = date ?? DateTime.now();
      final tx = InvestmentTransactionModel(
        id: _newTxId(InvestmentTransactionModel(
            amount: amount, date: now, investmentName: investmentName ?? '')),
        amount: amount,
        date: now,
        investmentName: investmentName ?? '',
        note: note,
      );
      await _saveTransactionToFirestore(tx);

      // Update caches
      await loadTransactions();
      await _updateTotalFromTransactions();

      // Persist current meta
      await _updateCurrentDocMeta();

      // If balance provider exists, save balances to persist totals etc.
      if (balanceProvider != null) {
        await balanceProvider!.saveBalances();
      }

      notifyListeners();
      _log('Recorded investment transaction ${tx.id}');
    } catch (e, st) {
      _logError('Failed to record investment transaction', e, st);
    }
  }

  /// Remove a historical investment transaction by amount and date
  Future<void> removeHistoricalInvestmentTransaction(
      double amount, String dateString) async {
    try {
      // Parse the date string to find matching transaction
      DateTime? targetDate;
      try {
        targetDate = DateTime.parse(dateString);
      } catch (e) {
        _logError('Invalid date string: $dateString', e, null);
        return;
      }

      // Find transaction matching the amount and date
      final txCol = _txCol;
      if (txCol == null) return;

      // Query for transactions with matching amount
      final q = await txCol.where('amount', isEqualTo: amount).get();

      // Find the transaction with matching date
      String? txIdToDelete;
      for (final doc in q.docs) {
        final data = doc.data();
        final txDate = _parseTimestamp(data['date']);
        if (txDate != null) {
          // Compare dates (ignoring time component for flexibility)
          if (txDate.year == targetDate.year &&
              txDate.month == targetDate.month &&
              txDate.day == targetDate.day) {
            txIdToDelete = doc.id;
            break;
          }
        }
      }

      if (txIdToDelete != null) {
        await _deleteTransactionFromFirestore(txIdToDelete);
        await loadTransactions();
        await _updateTotalFromTransactions();
        if (balanceProvider != null) await balanceProvider!.saveBalances();

        notifyListeners();
        _log('Removed historical transaction $txIdToDelete');
      } else {
        _log(
            'No matching transaction found for amount $amount on date $dateString');
      }
    } catch (e, st) {
      _logError('Failed to remove historical transaction', e, st);
    }
  }

  // -------------------------
  // Deductions processing
  // -------------------------

  /// Check for pending investment deductions
  void _checkPendingInvestmentDeductions() {
    try {
      if (listProvider == null || balanceProvider == null) {
        _log(
            'Cannot check pending investment deductions: providers not available');
        return;
      }

      // Load last check date from Firestore
      _loadLastInvestmentCheckDate().then((_) {
        final now = DateTime.now();
        final currentDoc = _currentDocRef;
        if (currentDoc == null) return;

        currentDoc.get().then((snap) {
          if (snap.exists) {
            final data = snap.data();
            final lastCheck = _parseTimestamp(data?['lastInvestmentCheckDate']);

            if (lastCheck != null) {
              final hoursSinceLastCheck = now.difference(lastCheck).inHours;
              _log(
                  'Checking pending investment deductions. Hours since last check: $hoursSinceLastCheck');

              if (hoursSinceLastCheck < 12) {
                _log(
                    'Skipping investment deduction check (checked within last 12 hours)');
                return;
              }
            }
          }

          processInvestmentDeductions();
        });
      });
    } catch (e, st) {
      _logError('Failed to check pending investment deductions', e, st);
    }
  }

  Future<void> _loadLastInvestmentCheckDate() async {
    try {
      final currentDoc = _currentDocRef;
      if (currentDoc == null) return;

      final snap = await currentDoc.get();
      if (snap.exists) {
        final data = snap.data();
        final lastCheck = _parseTimestamp(data?['lastInvestmentCheckDate']);
        if (lastCheck != null) {
          _log(
              'Last investment check date loaded: ${lastCheck.toIso8601String()}');
        }
      }
    } catch (e, st) {
      _logError('Failed to load last investment check date', e, st);
    }
  }

  /// Process investment deductions for all active investments.
  /// Pass [simulatedDate] to override the wall-clock date used for
  /// transaction timestamps (used by the simulate feature).
  Future<void> processInvestmentDeductions({
    bool force = false,
    DateTime? simulatedDate,
  }) async {
    if (_processingInvestments) {
      _log('Already processing investments. Skipping.');
      return;
    }

    _processingInvestments = true;
    _log('Processing investment deductions... (forced: $force)');

    try {
      final col = _listCol;
      final txCol = _txCol;
      if (col == null || txCol == null) {
        _log('User not signed in - skipping deductions');
        _processingInvestments = false;
        return;
      }

      // load latest investments before processing
      await loadInvestments();
      await loadTransactions();

      final now = simulatedDate ?? DateTime.now();
      bool anyDeduction = false;

      final batch = _fs.batch();
      final activeInvestments = _investments
          .where((i) => i.isActive && !(i.isOneTime ?? false))
          .toList();
      _log(
          'Processing ${activeInvestments.length} active investments (excluding one-time savings)');

      for (int i = 0; i < activeInvestments.length; i++) {
        final inv = activeInvestments[i];
        final lastDeduction = inv.lastDeductionDate;

        _log(
            'Investment: ${inv.name}, Amount: ${inv.amount}, Last deduction: ${lastDeduction.toIso8601String()}');

        // skip if already deducted this month (unless forced)
        if (!force &&
            now.year == lastDeduction.year &&
            now.month == lastDeduction.month) {
          _log('Skipping ${inv.name}, already deducted this month.');
          continue;
        }

        // check balance
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

          await listProvider!.addTransaction(transaction,
              updateBalance: false); // Balance already updated above
        }

        // create transaction doc
        final txId = '${inv.name}_${inv.amount}_${now.millisecondsSinceEpoch}';
        final txRef = txCol.doc(txId);
        batch.set(txRef, {
          'amount': inv.amount,
          'date': Timestamp.fromDate(now),
          'investmentName': inv.name,
          'note': 'Monthly deduction',
        });

        // update investment's lastDeductionDate and monthlyDeductions
        final invIdx = _investments
            .indexWhere((x) => x.id == inv.id || x.name == inv.name);
        if (invIdx != -1) {
          final currentInv = _investments[invIdx];
          final newMonthlyDeductions =
              List<double>.from(currentInv.monthlyDeductions);
          newMonthlyDeductions.add(currentInv.amount);

          final invRef = col.doc(currentInv.id ?? currentInv.name);
          batch.set(
              invRef,
              {
                'monthlyDeductions': newMonthlyDeductions,
                'lastDeductionDate': Timestamp.fromDate(now),
              },
              SetOptions(merge: true));
        }

        anyDeduction = true;
      }

      if (anyDeduction) {
        await batch.commit();
        _log('Committed batch for deductions');

        // refresh caches
        await loadInvestments();
        await loadTransactions();
        await _updateTotalFromTransactions();

        // update current doc last check date
        await _currentDocRef?.set(
            {'lastInvestmentCheckDate': FieldValue.serverTimestamp()},
            SetOptions(merge: true));

        notifyListeners();
        _log(
            'Investment deductions processed successfully. Total: $_totalInvestments');
      } else {
        _log('No investment deductions were processed');
      }
    } catch (e, st) {
      _logError('Error while processing investment deductions', e, st);
    } finally {
      _processingInvestments = false;
      _log('Finished processing investment deductions');
    }
  }

  /// Simulate investment deductions (for testing/demo).
  /// Each investment tracks its OWN simulation date independently,
  /// advancing by one month per call so the chart shows clear growth
  /// even when investments were added at different real-world times.
  Future<void> simulateInvestmentDeduction() async {
    try {
      // All recurring (non-one-time) investments
      final allRecurring =
          _investments.where((i) => !(i.isOneTime ?? false)).toList();
      final expectedAmt =
          allRecurring.fold(0.0, (sum, inv) => sum + inv.amount);

      // Only active recurring investments — what WILL actually be invested
      final activeInvestments = allRecurring.where((i) => i.isActive).toList();
      final actualAmt =
          activeInvestments.fold(0.0, (sum, inv) => sum + inv.amount);

      // Update lastMonthTotal for backward compat
      lastMonthTotal = expectedAmt;

      if (activeInvestments.isEmpty) {
        _log('No active non-one-time investments to simulate.');
        _recalcPercentage(
          expectedThisCycle: expectedAmt,
          actualThisCycle: actualAmt,
        );
        notifyListeners();
        return;
      }

      for (final inv in activeInvestments) {
        final key = inv.id ?? inv.name;
        final simDate = _nextSimDate(key);
        _log('Simulating "${inv.name}" for $simDate');

        // Deduct from balance
        if (balanceProvider != null) {
          balanceProvider!.addExpense(inv.amount);
        }

        // Add to general transaction list (for history)
        if (listProvider != null) {
          await listProvider!.addTransaction(
            AllListProvider(
              title: 'Investment',
              category: inv.name,
              amount: inv.amount,
              isIncome: false,
              date: simDate.toIso8601String(),
              transactionType: TransactionType.investment,
            ),
            updateBalance: false,
          );
        }

        // Write investment transaction to Firestore
        await recordInvestmentTransaction(
          inv.amount,
          date: simDate,
          investmentName: inv.name,
          note: 'Simulated monthly deduction',
        );

        // Advance THIS investment's simulation clock by one month
        _simulationDates[key] = DateTime(
          simDate.year,
          simDate.month + 1,
          simDate.day,
        );
      }

      await _updateTotalFromTransactions();
      _recalcPercentage(
        expectedThisCycle: expectedAmt,
        actualThisCycle: actualAmt,
      );
      notifyListeners();
    } catch (e, st) {
      _logError('Failed to simulate investment deduction', e, st);
    }
  }

  // -------------------------
  // Insight actions
  // -------------------------
  Future<void> handleInsightAction(
      String insightId, Map<String, dynamic> metadata) async {
    final amount = (metadata['recommended'] ?? metadata['amount'] ?? 0);
    if ((amount is num) && amount > 0) {
      await addInvestment(
        metadata['name'] ?? 'AutoSave',
        (amount).toDouble(),
        category: metadata['category'] ?? 'Savings',
        startDate: DateTime.now(),
      );
    }
  }

  // -------------------------
  // Clear and utility methods
  // -------------------------
  Future<void> clearAll() async {
    try {
      _log('Clearing all investments and transactions');

      final col = _listCol;
      final txCol = _txCol;
      final current = _currentDocRef;

      if (txCol != null) {
        QuerySnapshot<Map<String, dynamic>> q;
        do {
          q = await txCol.limit(500).get();
          if (q.docs.isEmpty) break;
          final batch = _fs.batch();
          for (final d in q.docs) batch.delete(d.reference);
          await batch.commit();
        } while (q.docs.isNotEmpty);
      }

      if (col != null) {
        QuerySnapshot<Map<String, dynamic>> q;
        do {
          q = await col.limit(500).get();
          if (q.docs.isEmpty) break;
          final batch = _fs.batch();
          for (final d in q.docs) batch.delete(d.reference);
          await batch.commit();
        } while (q.docs.isNotEmpty);
      }

      if (current != null) {
        await current.set({
          'totalInvestments': 0,
          'lastInvestmentCheckDate': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }

      // clear local caches
      _investments.clear();
      _transactions.clear();
      _totalInvestments = 0.0;
      lastMonthTotal = 0.0;

      notifyListeners();
      _log('All investments and transactions cleared');
    } catch (e, st) {
      _logError('Failed to clear all investments', e, st);
    }
  }

  Future<bool> verifyClear() async {
    try {
      final col = _listCol;
      final txCol = _txCol;
      final current = _currentDocRef;
      final curExists = current == null ? true : (await current.get()).exists;
      final listEmpty =
          col == null ? true : (await col.limit(1).get()).docs.isEmpty;
      final txEmpty =
          txCol == null ? true : (await txCol.limit(1).get()).docs.isEmpty;
      _log(
          'verifyClear: curExists=$curExists listEmpty=$listEmpty txEmpty=$txEmpty');
      return !curExists && listEmpty && txEmpty;
    } catch (e, st) {
      _logError('Failed to verify clear', e, st);
      return false;
    }
  }
}
