// balance_storage.dart - Firestore-only, realtime-synced version (FIXED)
import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:wallone/models/investment_model.dart';

class BalanceStorage extends ChangeNotifier {
  BalanceStorage() {
    _init();
  }

  // --- Internal state (in-memory cache) ---
  Map<String, dynamic> _balances = {
    'totalBalance': 0.0,
    'dailyExpenses': 0.0,
    'weeklyExpenses': 0.0,
    'monthlyExpenses': 0.0,
    'dailyIncomes': 0.0,
    'weeklyIncomes': 0.0,
    'monthlyIncomes': 0.0,
    'lastResetDate': null,
    'totalInvestments': 0.0,
  };

  Map<String, double> _balanceHistory = {};
  List<InvestmentModel> _investments = [];
  DateTime? _lastInvestmentCheckDate;
  DateTime? _lastWeeklyResetDate;
  DateTime? _lastMonthlyResetDate;

  // --- Subscriptions ---
  StreamSubscription<User?>? _authSub;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _userDocSub;

  // --- Initialization: listen to auth and subscribe/unsubscribe to user doc ---
  void _init() {
    _authSub = FirebaseAuth.instance.authStateChanges().listen((user) async {
      await _userDocSub?.cancel();
      _userDocSub = null;

      if (user == null) {
        // logged out -> clear in-memory caches (but keep object usable)
        _balances = {
          'totalBalance': 0.0,
          'dailyExpenses': 0.0,
          'weeklyExpenses': 0.0,
          'monthlyExpenses': 0.0,
          'dailyIncomes': 0.0,
          'weeklyIncomes': 0.0,
          'monthlyIncomes': 0.0,
          'lastResetDate': null,
          'totalInvestments': 0.0,
        };
        _balanceHistory = {};
        _investments = [];
        _lastInvestmentCheckDate = null;
        _lastWeeklyResetDate = null;
        _lastMonthlyResetDate = null;
        notifyListeners();
      } else {
        _subscribeToFirestoreUser(user.uid);
      }
    });
  }

  DocumentReference<Map<String, dynamic>>? _getUserDoc() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return null;
    return FirebaseFirestore.instance.collection('users').doc(uid);
  }

  Future<void> _subscribeToFirestoreUser(String uid) async {
    try {
      final docRef = FirebaseFirestore.instance.collection('users').doc(uid);
      _userDocSub = docRef.snapshots().listen((snapshot) {
        if (!snapshot.exists) {
          // No remote data yet
          return;
        }
        final data = snapshot.data() ?? {};

        // balances map
        final balances = (data['balances'] as Map<String, dynamic>?) ?? {};
        _balances = {
          'totalBalance': _toDouble(balances['totalBalance']),
          'dailyExpenses': _toDouble(balances['dailyExpenses']),
          'weeklyExpenses': _toDouble(balances['weeklyExpenses']),
          'monthlyExpenses': _toDouble(balances['monthlyExpenses']),
          'dailyIncomes': _toDouble(balances['dailyIncomes']),
          'weeklyIncomes': _toDouble(balances['weeklyIncomes']),
          'monthlyIncomes': _toDouble(balances['monthlyIncomes']),
          'lastResetDate': _parseTimestampToString(balances['lastResetDate']),
          'totalInvestments': _toDouble(balances['totalInvestments']),
        };

        // balanceHistory
        final historyRaw =
            (data['balanceHistory'] as Map<String, dynamic>?) ?? {};
        final Map<String, double> parsedHistory = {};
        historyRaw.forEach((k, v) {
          try {
            parsedHistory[k] = _toDouble(v);
          } catch (_) {
            // Skip invalid entries
          }
        });
        _balanceHistory = parsedHistory;

        // reset dates
        final resetDates = (data['resetDates'] as Map<String, dynamic>?) ?? {};
        _lastWeeklyResetDate =
            _parseTimestamp(resetDates['lastWeeklyResetDate']);
        _lastMonthlyResetDate =
            _parseTimestamp(resetDates['lastMonthlyResetDate']);

        // lastInvestmentCheckDate
        _lastInvestmentCheckDate =
            _parseTimestamp(data['lastInvestmentCheckDate']);

        // investments
        final investmentsRaw = (data['investments'] as List<dynamic>?) ?? [];
        final loadedInvestments = investmentsRaw
            .map((item) {
              try {
                final jsonData = item as Map<String, dynamic>;
                return InvestmentModel(
                  name: jsonData['name'] ?? '',
                  amount: _toDouble(jsonData['amount']),
                  isActive: jsonData['isActive'] ?? true,
                  startDate:
                      _parseTimestamp(jsonData['startDate']) ?? DateTime.now(),
                  lastDeductionDate:
                      _parseTimestamp(jsonData['lastDeductionDate']) ??
                          DateTime.now(),
                  category: jsonData['category'] ?? 'Other',
                  monthlyDeductions:
                      (jsonData['monthlyDeductions'] as List<dynamic>?)
                              ?.map((e) => _toDouble(e))
                              .toList() ??
                          [],
                );
              } catch (e) {
                debugPrint('Error parsing investment: $e');
                return null;
              }
            })
            .whereType<InvestmentModel>()
            .toList();
        _investments = loadedInvestments;

        notifyListeners();
      });
    } catch (e) {
      debugPrint('Error subscribing to user doc: $e');
    }
  }

  // --- Helper methods for safe data conversion ---
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

  String? _parseTimestampToString(dynamic value) {
    final dt = _parseTimestamp(value);
    return dt?.toIso8601String();
  }

  // --- Public getters to expose the in-memory data quickly ---
  Map<String, dynamic> get cachedBalances => Map.from(_balances);
  Map<String, double> get cachedBalanceHistory => Map.from(_balanceHistory);
  List<InvestmentModel> get cachedInvestments =>
      List.unmodifiable(_investments);
  DateTime? get cachedLastInvestmentCheckDate => _lastInvestmentCheckDate;
  DateTime? get cachedLastWeeklyResetDate => _lastWeeklyResetDate;
  DateTime? get cachedLastMonthlyResetDate => _lastMonthlyResetDate;

  // --- Loading helpers (will use in-memory cache if available, otherwise fetch once) ---
  Future<Map<String, dynamic>> loadBalances() async {
    // If we already have data (from subscription), return it immediately.
    if (_balances['totalBalance'] != null ||
        _balances.values.any((v) => v != null && v != 0.0)) {
      return cachedBalances;
    }

    final userDoc = _getUserDoc();
    if (userDoc == null) {
      return _getDefaultBalances();
    }

    try {
      final snapshot = await userDoc.get();
      if (snapshot.exists) {
        final data = snapshot.data();
        final balances = (data?['balances'] as Map<String, dynamic>?) ?? {};
        _balances = {
          'totalBalance': _toDouble(balances['totalBalance']),
          'dailyExpenses': _toDouble(balances['dailyExpenses']),
          'weeklyExpenses': _toDouble(balances['weeklyExpenses']),
          'monthlyExpenses': _toDouble(balances['monthlyExpenses']),
          'dailyIncomes': _toDouble(balances['dailyIncomes']),
          'weeklyIncomes': _toDouble(balances['weeklyIncomes']),
          'monthlyIncomes': _toDouble(balances['monthlyIncomes']),
          'lastResetDate': _parseTimestampToString(balances['lastResetDate']),
          'totalInvestments': _toDouble(balances['totalInvestments']),
        };
        return cachedBalances;
      }

      return _getDefaultBalances();
    } catch (e) {
      debugPrint('Error loading balances: $e');
      return _getDefaultBalances();
    }
  }

  Map<String, dynamic> _getDefaultBalances() {
    return {
      'totalBalance': 0.0,
      'dailyExpenses': 0.0,
      'weeklyExpenses': 0.0,
      'monthlyExpenses': 0.0,
      'dailyIncomes': 0.0,
      'weeklyIncomes': 0.0,
      'monthlyIncomes': 0.0,
      'lastResetDate': null,
      'totalInvestments': 0.0,
    };
  }

  Future<Map<String, double>> loadBalanceHistory() async {
    if (_balanceHistory.isNotEmpty) return Map.from(_balanceHistory);

    final userDoc = _getUserDoc();
    if (userDoc == null) return {};

    try {
      final snapshot = await userDoc.get();
      if (snapshot.exists) {
        final data = snapshot.data();
        final historyData =
            (data?['balanceHistory'] as Map<String, dynamic>?) ?? {};
        final Map<String, double> out = {};
        historyData.forEach((k, v) {
          try {
            out[k] = _toDouble(v);
          } catch (e) {
            debugPrint('Error parsing history entry: $e');
          }
        });
        _balanceHistory = out;
        return Map.from(_balanceHistory);
      }
      return {};
    } catch (e) {
      debugPrint('Error loading balance history: $e');
      return {};
    }
  }

  Future<void> saveBalanceHistory(Map<String, double> history) async {
    final userDoc = _getUserDoc();
    if (userDoc == null) return;

    try {
      await userDoc.set({'balanceHistory': history}, SetOptions(merge: true));
      _balanceHistory = Map.from(history);
      notifyListeners();
    } catch (e) {
      debugPrint('Error saving balance history: $e');
      rethrow;
    }
  }

  /// Save a snapshot for a date, prune older entries than [maxDays]
  Future<void> saveBalanceSnapshot(DateTime date, double totalBalance,
      {int maxDays = 30}) async {
    try {
      final key = _dateKey(date);
      final history = await loadBalanceHistory();
      history[key] = totalBalance;

      final cutoff = DateTime.now().subtract(Duration(days: maxDays));
      final keysToKeep = history.keys.where((k) {
        try {
          final d = DateTime.parse(k);
          return !d.isBefore(cutoff);
        } catch (e) {
          return false;
        }
      }).toList();

      final Map<String, double> pruned = {};
      for (final k in keysToKeep) {
        pruned[k] = history[k]!;
      }

      await saveBalanceHistory(pruned);
    } catch (e) {
      debugPrint('Error saving balance snapshot: $e');
      rethrow;
    }
  }

  Future<double?> getBalanceForDate(DateTime date) async {
    try {
      final history = await loadBalanceHistory();
      final key = _dateKey(date);
      if (history.containsKey(key)) return history[key];

      DateTime? best;
      for (final k in history.keys) {
        try {
          final d = DateTime.parse(k);
          if (!d.isAfter(date)) {
            if (best == null || d.isAfter(best)) best = d;
          }
        } catch (e) {
          // Skip invalid date keys
        }
      }
      if (best != null) return history[_dateKey(best)];
      return null;
    } catch (e) {
      debugPrint('Error getting balance for date: $e');
      return null;
    }
  }

  Future<void> saveBalances(Map<String, dynamic> balances) async {
    final userDoc = _getUserDoc();
    if (userDoc == null) {
      throw Exception('User must be signed in to save balances');
    }

    try {
      final toWrite = {
        'balances': {
          'totalBalance': _toDouble(balances['totalBalance']),
          'dailyExpenses': _toDouble(balances['dailyExpenses']),
          'weeklyExpenses': _toDouble(balances['weeklyExpenses']),
          'monthlyExpenses': _toDouble(balances['monthlyExpenses']),
          'dailyIncomes': _toDouble(balances['dailyIncomes']),
          'weeklyIncomes': _toDouble(balances['weeklyIncomes']),
          'monthlyIncomes': _toDouble(balances['monthlyIncomes']),
          'totalInvestments': _toDouble(balances['totalInvestments'] ?? 0),
        }
      };
      await userDoc.set(toWrite, SetOptions(merge: true));
      // update local cache
      _balances = {
        ..._balances,
        ...toWrite['balances'] as Map<String, dynamic>
      };
      notifyListeners();
    } catch (e) {
      debugPrint('Error saving balances: $e');
      rethrow;
    }
  }

  Future<void> saveLastResetDate(DateTime date) async {
    final userDoc = _getUserDoc();
    if (userDoc == null) return;
    final formatted = date.toIso8601String();
    try {
      await userDoc.set({
        'balances': {'lastResetDate': formatted}
      }, SetOptions(merge: true));
      _balances['lastResetDate'] = formatted;
      notifyListeners();
    } catch (e) {
      debugPrint('Error saving last reset date: $e');
      rethrow;
    }
  }

  Future<void> saveLastWeeklyResetDate(DateTime date) async {
    final userDoc = _getUserDoc();
    if (userDoc == null) return;
    final formatted = date.toIso8601String();
    try {
      await userDoc.set({
        'resetDates': {'lastWeeklyResetDate': formatted}
      }, SetOptions(merge: true));
      _lastWeeklyResetDate = date;
      notifyListeners();
    } catch (e) {
      debugPrint('Error saving weekly reset date: $e');
      rethrow;
    }
  }

  Future<void> saveLastMonthlyResetDate(DateTime date) async {
    final userDoc = _getUserDoc();
    if (userDoc == null) return;
    final formatted = date.toIso8601String();
    try {
      await userDoc.set({
        'resetDates': {'lastMonthlyResetDate': formatted}
      }, SetOptions(merge: true));
      _lastMonthlyResetDate = date;
      notifyListeners();
    } catch (e) {
      debugPrint('Error saving monthly reset date: $e');
      rethrow;
    }
  }

  Future<DateTime?> loadLastWeeklyResetDate() async {
    if (_lastWeeklyResetDate != null) return _lastWeeklyResetDate;
    final userDoc = _getUserDoc();
    if (userDoc == null) return null;
    try {
      final snapshot = await userDoc.get();
      if (snapshot.exists) {
        final data = snapshot.data();
        final resetDates = data?['resetDates'] as Map<String, dynamic>?;
        _lastWeeklyResetDate =
            _parseTimestamp(resetDates?['lastWeeklyResetDate']);
        return _lastWeeklyResetDate;
      }
      return null;
    } catch (e) {
      debugPrint('Error loading weekly reset date: $e');
      return null;
    }
  }

  Future<DateTime?> loadLastMonthlyResetDate() async {
    if (_lastMonthlyResetDate != null) return _lastMonthlyResetDate;
    final userDoc = _getUserDoc();
    if (userDoc == null) return null;
    try {
      final snapshot = await userDoc.get();
      if (snapshot.exists) {
        final data = snapshot.data();
        final resetDates = data?['resetDates'] as Map<String, dynamic>?;
        _lastMonthlyResetDate =
            _parseTimestamp(resetDates?['lastMonthlyResetDate']);
        return _lastMonthlyResetDate;
      }
      return null;
    } catch (e) {
      debugPrint('Error loading monthly reset date: $e');
      return null;
    }
  }

  Future<List<InvestmentModel>> loadInvestments() async {
    if (_investments.isNotEmpty) return List.unmodifiable(_investments);
    final userDoc = _getUserDoc();
    if (userDoc == null) return [];
    try {
      final snapshot = await userDoc.get();
      if (snapshot.exists) {
        final data = snapshot.data();
        final investmentsData = data?['investments'] as List<dynamic>?;
        if (investmentsData != null) {
          final loaded = investmentsData
              .map((item) {
                try {
                  final jsonData = item as Map<String, dynamic>;
                  return InvestmentModel(
                    name: jsonData['name'] ?? '',
                    amount: _toDouble(jsonData['amount']),
                    isActive: jsonData['isActive'] ?? true,
                    startDate: _parseTimestamp(jsonData['startDate']) ??
                        DateTime.now(),
                    lastDeductionDate:
                        _parseTimestamp(jsonData['lastDeductionDate']) ??
                            DateTime.now(),
                    category: jsonData['category'] ?? 'Other',
                    monthlyDeductions:
                        (jsonData['monthlyDeductions'] as List<dynamic>?)
                                ?.map((e) => _toDouble(e))
                                .toList() ??
                            [],
                  );
                } catch (e) {
                  debugPrint('Error parsing investment: $e');
                  return null;
                }
              })
              .whereType<InvestmentModel>()
              .toList();
          _investments = loaded;
          return loaded;
        }
      }
      return [];
    } catch (e) {
      debugPrint('Error loading investments: $e');
      return [];
    }
  }

  Future<void> saveInvestments(List<InvestmentModel> investments) async {
    final userDoc = _getUserDoc();
    if (userDoc == null) {
      throw Exception('User must be signed in to save investments');
    }
    try {
      final investmentsData = investments
          .map((inv) => {
                'name': inv.name,
                'amount': inv.amount,
                'isActive': inv.isActive,
                'startDate': inv.startDate.toIso8601String(),
                'lastDeductionDate': inv.lastDeductionDate.toIso8601String(),
                'category': inv.category,
                'monthlyDeductions': inv.monthlyDeductions,
              })
          .toList();

      await userDoc
          .set({'investments': investmentsData}, SetOptions(merge: true));
      _investments = List<InvestmentModel>.from(investments);
      notifyListeners();
    } catch (e) {
      debugPrint('Error saving investments: $e');
      rethrow;
    }
  }

  Future<void> migrateOldInvestments() async {
    // kept for compatibility: simply reload and re-save (no local storage used).
    try {
      final investments = await loadInvestments();
      await saveInvestments(investments);
    } catch (e) {
      debugPrint('Error migrating investments: $e');
    }
  }

  Future<DateTime> loadLastInvestmentCheckDate() async {
    if (_lastInvestmentCheckDate != null) return _lastInvestmentCheckDate!;
    final userDoc = _getUserDoc();
    if (userDoc == null) return DateTime.now();
    try {
      final snapshot = await userDoc.get();
      if (snapshot.exists) {
        final data = snapshot.data();
        _lastInvestmentCheckDate =
            _parseTimestamp(data?['lastInvestmentCheckDate']);
        return _lastInvestmentCheckDate ?? DateTime.now();
      }
      return DateTime.now();
    } catch (e) {
      debugPrint('Error loading investment check date: $e');
      return DateTime.now();
    }
  }

  Future<void> saveLastInvestmentCheckDate(DateTime date) async {
    final userDoc = _getUserDoc();
    if (userDoc == null) return;
    final formatted = date.toIso8601String();
    try {
      await userDoc
          .set({'lastInvestmentCheckDate': formatted}, SetOptions(merge: true));
      _lastInvestmentCheckDate = date;
      notifyListeners();
    } catch (e) {
      debugPrint('Error saving investment check date: $e');
      rethrow;
    }
  }

  // --- Clear user-specific data in Firestore ---
  Future<void> clearAll() async {
    final userDoc = _getUserDoc();
    if (userDoc == null) return;
    try {
      await userDoc.set({
        'balances': FieldValue.delete(),
        'balanceHistory': FieldValue.delete(),
        'investments': FieldValue.delete(),
        'resetDates': FieldValue.delete(),
        'lastInvestmentCheckDate': FieldValue.delete(),
      }, SetOptions(merge: true));

      // Clear local caches
      _balances = _getDefaultBalances();
      _balanceHistory = {};
      _investments = [];
      _lastInvestmentCheckDate = null;
      _lastWeeklyResetDate = null;
      _lastMonthlyResetDate = null;
      notifyListeners();
    } catch (e) {
      debugPrint('Error clearing all data: $e');
      rethrow;
    }
  }

  // --- Helper method for date key ---
  String _dateKey(DateTime date) {
    return DateTime(date.year, date.month, date.day)
        .toIso8601String()
        .split('T')
        .first;
  }

  @override
  void dispose() {
    _authSub?.cancel();
    _userDocSub?.cancel();
    super.dispose();
  }
}
