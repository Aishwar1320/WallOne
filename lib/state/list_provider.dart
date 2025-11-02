import 'package:flutter/material.dart';
import 'package:intl/intl.dart'; // For date formatting
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

import 'package:wallone/state/balance_provider.dart';
import 'package:wallone/state/investment_provider.dart';

class AllListProvider {
  final int id;
  final String title;
  final String category;
  final double amount;
  final String date;
  final bool isIncome;
  final TransactionType transactionType;
  final String createdAt; // Add this field to track creation time
  final double? beforeBalance;

  AllListProvider({
    this.id = -1,
    required this.title,
    required this.category,
    required this.amount,
    required this.isIncome,
    String? date,
    String? createdAt,
    TransactionType? transactionType,
    this.beforeBalance,
  })  : date = date ?? DateTime.now().toIso8601String(),
        createdAt = createdAt ?? DateTime.now().toIso8601String(),
        transactionType = transactionType ??
            (isIncome ? TransactionType.income : TransactionType.expense);

  // Convert object to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'category': category,
      'amount': amount,
      'date': date,
      'isIncome': isIncome,
      'createdAt': createdAt, // Include in serialization
      'transactionType': transactionType.name,
      'beforeBalance': beforeBalance,
    };
  }

  // Create object from JSON
  factory AllListProvider.fromJson(Map<String, dynamic> json) {
    // Try to parse transactionType if available; otherwise infer from fields
    TransactionType parsedType = TransactionType.expense;
    try {
      if (json.containsKey('transactionType') &&
          json['transactionType'] is String) {
        final t = (json['transactionType'] as String).toLowerCase();
        if (t == 'income')
          parsedType = TransactionType.income;
        else if (t == 'investment')
          parsedType = TransactionType.investment;
        else
          parsedType = TransactionType.expense;
      } else {
        // infer from legacy fields
        final isIncome = json['isIncome'] == true;
        if (isIncome)
          parsedType = TransactionType.income;
        else {
          final title = (json['title'] ?? '').toString().toLowerCase();
          final category = (json['category'] ?? '').toString().toLowerCase();
          if (title.contains('investment') || category.contains('investment')) {
            parsedType = TransactionType.investment;
          } else {
            parsedType = TransactionType.expense;
          }
        }
      }
    } catch (_) {
      parsedType = TransactionType.expense;
    }

    double? parsedBefore;
    try {
      if (json.containsKey('beforeBalance') && json['beforeBalance'] != null) {
        parsedBefore = (json['beforeBalance'] is num)
            ? (json['beforeBalance'] as num).toDouble()
            : double.tryParse(json['beforeBalance'].toString());
      }
    } catch (_) {
      parsedBefore = null;
    }

    return AllListProvider(
      id: json['id'],
      title: json['title'] ?? '',
      category: json['category'] ?? '',
      amount:
          (json['amount'] is num) ? (json['amount'] as num).toDouble() : 0.0,
      date: json['date'],
      isIncome: json['isIncome'] == true,
      createdAt: json['createdAt'] ?? DateTime.now().toIso8601String(),
      transactionType: parsedType,
      beforeBalance: parsedBefore,
    );
  }

  @override
  String toString() {
    return 'AllListProvider(id: $id, title: $title, category: $category, amount: $amount, date: $date, isIncome: $isIncome, createdAt: $createdAt)';
  }
}

enum TransactionType { expense, income, investment }

class ListProvider with ChangeNotifier {
  final List<AllListProvider> _transactions = [];
  final BalanceProvider _balanceProvider;
  final InvestmentProvider _investmentProvider;
  int _nextId = 0;

  /// Optional callback invoked when a new transaction is added.
  void Function(AllListProvider transaction)? onTransactionAdded;

  // Add new properties to track current filter settings
  bool _isFilterActive = false;
  bool _isExpensesSelected = true;
  String _currentPeriod = 'All Dates'; // Changed default to 'All Dates'

  ListProvider(this._balanceProvider, this._investmentProvider);

  // Getter for all transactions
  List<AllListProvider> get transactions => _transactions;

  // New getters for filter state
  bool get isFilterActive => _isFilterActive;
  bool get isExpensesSelected => _isExpensesSelected;
  String get currentPeriod => _currentPeriod;

  List<String> get last7Days {
    return List.generate(7, (index) {
      final date = DateTime.now().subtract(Duration(days: index));
      return DateFormat('yyyy-MM-dd').format(date);
    });
  }

  void setFilterPeriod(String period) {
    _currentPeriod = period;
    notifyListeners(); // ✅ Ensures UI updates
  }

  // Modified: Get all transactions with optional filtering
  List<AllListProvider> getTransactions({bool applyFilter = false}) {
    List<AllListProvider> listToReturn =
        List.from(_transactions); // Create a copy

    if (applyFilter && _isFilterActive) {
      listToReturn =
          getFilteredTransactions(_isExpensesSelected, _currentPeriod);
    }

    // Sort by date (newest first) - this ensures consistent ordering
    listToReturn.sort((a, b) {
      try {
        final dateA = DateTime.parse(a.date);
        final dateB = DateTime.parse(b.date);
        return dateB.compareTo(dateA);
      } catch (_) {
        return 0;
      }
    });

    return listToReturn;
  }

  // Set filter parameters
  void setFilter({bool? isExpensesSelected, String? period, bool? isActive}) {
    bool shouldNotify = false;

    if (isExpensesSelected != null &&
        _isExpensesSelected != isExpensesSelected) {
      _isExpensesSelected = isExpensesSelected;
      shouldNotify = true;
    }

    if (period != null && _currentPeriod != period) {
      _currentPeriod = period;
      shouldNotify = true;
    }

    if (isActive != null && _isFilterActive != isActive) {
      _isFilterActive = isActive;
      shouldNotify = true;
    }

    if (shouldNotify) {
      notifyListeners();
    }
  }

  // UPDATED: Get filtered transactions based on type and specific date
  List<AllListProvider> getFilteredTransactions(
      bool isExpensesSelected, String selectedDate) {
    // First filter by transaction type
    var filtered = _transactions
        .where((t) => isExpensesSelected ? !t.isIncome : t.isIncome)
        .toList();

    // Then apply date filter if not 'All Dates'. We compare date-only for filtering
    // but keep full timestamp ordering so time-of-day is preserved.
    if (selectedDate != 'All Dates') {
      filtered = filtered.where((t) {
        try {
          final txnDate = DateTime.parse(t.date);

          // Support ISO key (yyyy-MM-dd) emitted by the filter control
          final txnIso = DateFormat('yyyy-MM-dd').format(txnDate);
          if (selectedDate == 'Today') {
            final todayIso = DateFormat('yyyy-MM-dd').format(DateTime.now());
            return txnIso == todayIso;
          }

          if (RegExp(r"^\d{4}-\d{2}-\d{2}").hasMatch(selectedDate)) {
            return txnIso == selectedDate;
          }

          // Fallback to legacy formats: compare dd-MM or dd-MM-yyyy
          final txnDateOnly = DateFormat('dd-MM-yyyy').format(txnDate);

          try {
            final legacy = DateFormat('dd-MM-yyyy').format(DateFormat('dd-MM')
                .parse(selectedDate + '-${DateTime.now().year}'));
            if (txnDateOnly == legacy) return true;
          } catch (_) {}

          return txnDateOnly == selectedDate;
        } catch (e) {
          print('Error parsing date for transaction ${t.id}: ${t.date}');
          return false;
        }
      }).toList();
    }

    // Sort by transaction timestamp (date) for consistent ordering (newest first).
    filtered.sort((a, b) {
      try {
        final dateA = DateTime.parse(a.date);
        final dateB = DateTime.parse(b.date);
        return dateB.compareTo(dateA);
      } catch (_) {
        return 0;
      }
    });

    return filtered;
  }

  // NEW: Method to get transactions for a specific date (helper method)
  List<AllListProvider> getTransactionsForDate(String dateFilter) {
    if (dateFilter == 'All Dates') {
      return getTransactions();
    }
    // Compare date-only (dd-MM-yyyy) but sort by full timestamp (date) so
    // transactions at specific times show in correct order.
    final result = _transactions.where((t) {
      try {
        final txnDate = DateTime.parse(t.date);
        final txnDateOnly = DateFormat('dd-MM-yyyy').format(txnDate);

        if (dateFilter == 'Today') {
          final today = DateFormat('dd-MM-yyyy').format(DateTime.now());
          return txnDateOnly == today;
        }

        // try legacy 'dd-MM' format by appending current year
        try {
          final legacy = DateFormat('dd-MM-yyyy').format(DateFormat('dd-MM')
              .parse(dateFilter + '-${DateTime.now().year}'));
          if (txnDateOnly == legacy) return true;
        } catch (_) {}

        return txnDateOnly == dateFilter;
      } catch (e) {
        print('Error parsing date for transaction ${t.id}: ${t.date}');
        return false;
      }
    }).toList();

    result.sort((a, b) {
      try {
        final da = DateTime.parse(a.date);
        final db = DateTime.parse(b.date);
        return db.compareTo(da);
      } catch (_) {
        return 0;
      }
    });

    return result;
  }

  // Load transactions from SharedPreferences
  Future<void> loadTransactions() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? savedData = prefs.getString('transactions');

      print('Loading transactions from SharedPreferences...');
      print('Raw saved data: $savedData');

      if (savedData != null && savedData.isNotEmpty) {
        final List<dynamic> decodedData = jsonDecode(savedData);
        print('Decoded ${decodedData.length} transactions from storage');

        _transactions.clear();

        if (decodedData.isNotEmpty) {
          final loadedTransactions = decodedData
              .map((data) => AllListProvider.fromJson(data))
              .toList();

          _transactions.addAll(loadedTransactions);

          // Set _nextId to one more than the highest existing ID
          _nextId =
              _transactions.map((t) => t.id).reduce((a, b) => a > b ? a : b) +
                  1;

          print('Successfully loaded ${_transactions.length} transactions');
          for (int i = 0; i < min(_transactions.length, 5); i++) {
            print(' - ${_transactions[i]}');
          }
          if (_transactions.length > 5) {
            print(' - ... and ${_transactions.length - 5} more');
          }
        } else {
          print('No transactions found in decoded data');
          _nextId = 0;
        }
      } else {
        print('No saved transactions found in SharedPreferences');
        _transactions.clear();
        _nextId = 0;
      }

      // Backfill beforeBalance for older data.
      // Prefer saved daily snapshots (for dates within last 30 days) when available.
      try {
        final prefs = await SharedPreferences.getInstance();
        final rawHistory = prefs.getString('balanceHistory');
        Map<String, double> history = {};
        if (rawHistory != null && rawHistory.isNotEmpty) {
          try {
            final dec = jsonDecode(rawHistory) as Map<String, dynamic>;
            dec.forEach((k, v) {
              try {
                history[k] =
                    (v is num) ? v.toDouble() : double.parse(v.toString());
              } catch (_) {}
            });
          } catch (_) {}
        }

        // Next: compute running fallback for transactions that don't have snapshots
        double running = _balanceProvider.totalBalance;
        final sorted = List<AllListProvider>.from(_transactions);
        sorted.sort((a, b) {
          try {
            final da = DateTime.parse(a.date);
            final db = DateTime.parse(b.date);
            return db.compareTo(da);
          } catch (_) {
            return 0;
          }
        });

        for (final t in sorted) {
          if (t.beforeBalance == null) {
            bool populated = false;
            try {
              final parsed = DateTime.parse(t.date);
              final dateOnly = DateTime(parsed.year, parsed.month, parsed.day);
              final diffDays = DateTime.now().difference(dateOnly).inDays;
              if (diffDays >= 0 && diffDays <= 30) {
                final key = dateOnly.toIso8601String().split('T')[0];
                if (history.containsKey(key)) {
                  final before = history[key]!;
                  final idx = _transactions.indexWhere((x) => x.id == t.id);
                  if (idx != -1) {
                    final old = _transactions[idx];
                    _transactions[idx] = AllListProvider(
                      id: old.id,
                      title: old.title,
                      category: old.category,
                      amount: old.amount,
                      isIncome: old.isIncome,
                      date: old.date,
                      createdAt: old.createdAt,
                      transactionType: old.transactionType,
                      beforeBalance: before,
                    );
                    populated = true;
                  }
                }
              }
            } catch (_) {}

            if (!populated) {
              final delta = t.isIncome ? t.amount : -t.amount;
              final before = running - delta;
              final idx = _transactions.indexWhere((x) => x.id == t.id);
              if (idx != -1) {
                final old = _transactions[idx];
                _transactions[idx] = AllListProvider(
                  id: old.id,
                  title: old.title,
                  category: old.category,
                  amount: old.amount,
                  isIncome: old.isIncome,
                  date: old.date,
                  createdAt: old.createdAt,
                  transactionType: old.transactionType,
                  beforeBalance: before,
                );
              }
            }
          }
          running = (t.beforeBalance ??
              (running - (t.isIncome ? t.amount : -t.amount)));
        }
      } catch (_) {}

      notifyListeners();
    } catch (e, stackTrace) {
      print('Error loading transactions: $e');
      print('Stack trace: $stackTrace');

      // Reset to empty state on error
      _transactions.clear();
      _nextId = 0;
      notifyListeners();
    }
  }

  // Helper function to get min of two integers
  int min(int a, int b) => a < b ? a : b;

  // Save transactions to SharedPreferences
  Future<void> saveTransactions() async {
    try {
      if (_transactions.isEmpty) {
        print('No transactions to save.');
        // Still save empty array to clear any existing data
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('transactions', jsonEncode([]));
        return;
      }

      final prefs = await SharedPreferences.getInstance();

      // Sort transactions by createdAt before saving for consistency
      _transactions.sort((a, b) {
        try {
          final dateA = DateTime.parse(a.createdAt);
          final dateB = DateTime.parse(b.createdAt);
          return dateB.compareTo(dateA);
        } catch (_) {
          return 0;
        }
      });

      // Encode all transactions to JSON
      final encodedData =
          jsonEncode(_transactions.map((t) => t.toJson()).toList());

      print('Saving ${_transactions.length} transactions');
      await prefs.setString('transactions', encodedData);

      // Update nextId to be greater than any existing ID
      if (_transactions.isNotEmpty) {
        _nextId =
            _transactions.map((t) => t.id).reduce((a, b) => a > b ? a : b) + 1;
      }

      print('Transactions saved successfully');
      // After persisting transactions, rebuild daily snapshots for the last 30 days
      try {
        await _rebuildAndSaveBalanceHistory();
      } catch (_) {}
    } catch (e, stackTrace) {
      print('Error saving transactions: $e');
      print('Stack trace: $stackTrace');
    }
  }

  // Rebuild balanceHistory for the last 30 days and save to SharedPreferences.
  Future<void> _rebuildAndSaveBalanceHistory({int days = 30}) async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // newest-first
      final sorted = List<AllListProvider>.from(_transactions);
      // sort newest-first by transaction date
      sorted.sort((a, b) {
        try {
          final da = DateTime.parse(a.date);
          final db = DateTime.parse(b.date);
          return db.compareTo(da);
        } catch (_) {
          return 0;
        }
      });

      double running = _balanceProvider.totalBalance;
      final Map<String, double> history = {};

      // ensure today's snapshot
      final todayKey = DateTime.now().toIso8601String().split('T')[0];
      history[todayKey] = running;

      // We'll also update _transactions' beforeBalance values for dates within window
      for (final t in sorted) {
        try {
          final parsed = DateTime.parse(t.date);
          final dateOnly = DateTime(parsed.year, parsed.month, parsed.day);
          final key = dateOnly.toIso8601String().split('T')[0];
          final diffDays = DateTime.now().difference(dateOnly).inDays;

          if (diffDays >= 0 && diffDays <= days) {
            // record snapshot for date if not recorded yet
            if (!history.containsKey(key)) {
              history[key] = running;
            }

            // compute beforeBalance for this transaction (balance before transaction)
            final delta = t.isIncome ? t.amount : -t.amount;
            final before = running - delta;

            final idx = _transactions.indexWhere((x) => x.id == t.id);
            if (idx != -1) {
              final old = _transactions[idx];
              _transactions[idx] = AllListProvider(
                id: old.id,
                title: old.title,
                category: old.category,
                amount: old.amount,
                isIncome: old.isIncome,
                date: old.date,
                createdAt: old.createdAt,
                transactionType: old.transactionType,
                beforeBalance: before,
              );
            }

            // move running backward after applying transaction
            running = before;
          } else {
            // transaction older than window: still move running backwards
            final delta = t.isIncome ? t.amount : -t.amount;
            running = running - delta;
          }
        } catch (_) {}
      }

      // prune older than days
      final cutoff = DateTime.now().subtract(Duration(days: days));
      final pruned = <String, double>{};
      history.forEach((k, v) {
        try {
          final d = DateTime.parse(k);
          if (!d.isBefore(cutoff)) pruned[k] = v;
        } catch (_) {}
      });

      // Persist updated transactions (with beforeBalance populated) and balanceHistory
      try {
        final txEncoded =
            jsonEncode(_transactions.map((t) => t.toJson()).toList());
        await prefs.setString('transactions', txEncoded);
      } catch (_) {}

      await prefs.setString('balanceHistory', jsonEncode(pruned));
      // Notify UI that transactions (beforeBalance) may have changed
      notifyListeners();
    } catch (_) {}
  }

  // Add a new transaction and update balances
  void addTransaction(AllListProvider transaction,
      {bool updateBalance = true}) {
    print('Adding a new transaction: $transaction');
    print('Adding transaction with:');
    print(' - Title: ${transaction.title}');
    print(' - Category: ${transaction.category}');
    print(' - Amount: ${transaction.amount}');
    print(' - Date: ${transaction.date}');
    print(' - isIncome: ${transaction.isIncome}');

    _addTransactionInternal(transaction, updateBalance);
    notifyListeners();
  }

  // Internal method to add transaction
  void _addTransactionInternal(
      AllListProvider transaction, bool updateBalance) {
    // Generate new ID
    _nextId = _transactions.isEmpty
        ? 0
        : _transactions.map((t) => t.id).reduce((a, b) => a > b ? a : b) + 1;

    final now = DateTime.now().toIso8601String();

    // Create new transaction instance and insert at the beginning
    final newTransaction = AllListProvider(
      id: _nextId++,
      title: transaction.title,
      category: transaction.category,
      amount: transaction.amount,
      isIncome: transaction.isIncome,
      date: transaction.date, // Keep the specified date
      createdAt: now, // Always use current time for createdAt
      transactionType: transaction.transactionType,
      // compute beforeBalance as the balance before this transaction
      beforeBalance:
          null, // will attempt to populate from saved snapshots asynchronously
    );

    _transactions.insert(0, newTransaction);

    if (updateBalance) {
      if (transaction.isIncome) {
        _balanceProvider.addIncome(transaction.amount);
      } else {
        _balanceProvider.addExpense(transaction.amount);
      }
    }

    // If this transaction represents an investment, record it in the
    // InvestmentProvider only when this add operation is responsible for
    // applying the financial effect (updateBalance == true).
    //
    // InvestmentProvider calls (such as addInvestment or scheduled deductions)
    // already record the investment transaction themselves and call
    // listProvider.addTransaction(..., updateBalance: false) to avoid double
    // counting. Respect that contract here.
    try {
      if (transaction.transactionType == TransactionType.investment &&
          updateBalance == true) {
        DateTime parsedDate;
        try {
          parsedDate = DateTime.parse(transaction.date);
        } catch (_) {
          parsedDate = DateTime.now();
        }

        _investmentProvider.recordInvestmentTransaction(transaction.amount,
            date: parsedDate);
      }
    } catch (e) {
      // swallow errors to avoid breaking transaction flow
    }

    saveTransactions();
    notifyListeners();

    // Notify optional external listener (e.g. AI advisor) about the new transaction.
    try {
      onTransactionAdded?.call(newTransaction);
    } catch (_) {}

    // Attempt to populate beforeBalance from saved snapshots (for past dates within 30 days).
    // We do this asynchronously because getSavedBalanceForDate is async.
    () async {
      try {
        final parsed = DateTime.tryParse(newTransaction.date);
        if (parsed == null) return;
        final dateOnly = DateTime(parsed.year, parsed.month, parsed.day);
        final diffDays = DateTime.now().difference(dateOnly).inDays;
        if (diffDays >= 0 && diffDays <= 30) {
          final snap = await _balanceProvider.getSavedBalanceForDate(dateOnly);
          if (snap != null) {
            final idx =
                _transactions.indexWhere((t) => t.id == newTransaction.id);
            if (idx != -1) {
              final old = _transactions[idx];
              _transactions[idx] = AllListProvider(
                id: old.id,
                title: old.title,
                category: old.category,
                amount: old.amount,
                isIncome: old.isIncome,
                date: old.date,
                createdAt: old.createdAt,
                transactionType: old.transactionType,
                beforeBalance: snap,
              );
              await saveTransactions();
              notifyListeners();
            }
          }
        }
      } catch (_) {}
    }();
  }

  // Edit an existing transaction and update balances
  void editTransaction(AllListProvider updatedTransaction) {
    final index =
        _transactions.indexWhere((t) => t.id == updatedTransaction.id);
    if (index != -1) {
      final oldTransaction = _transactions[index];

      // Reverse the effect of the old transaction on balances.
      if (oldTransaction.isIncome) {
        _balanceProvider.deductBalanceForIncome(oldTransaction.amount);
      } else {
        _balanceProvider.deductBalanceOnDelete(oldTransaction.amount);
      }

      // If the old transaction is an investment, remove its historical record.
      if (oldTransaction.transactionType == TransactionType.investment) {
        _investmentProvider.removeHistoricalInvestmentTransaction(
            oldTransaction.amount, oldTransaction.date);
      }

      // Update the transaction - preserve the original createdAt and transactionType
      _transactions[index] = AllListProvider(
        id: updatedTransaction.id,
        title: updatedTransaction.title,
        category: updatedTransaction.category,
        amount: updatedTransaction.amount,
        isIncome: updatedTransaction.isIncome,
        date: updatedTransaction.date,
        createdAt: oldTransaction.createdAt, // Preserve original creation time
        transactionType: updatedTransaction.transactionType,
        beforeBalance: oldTransaction.beforeBalance,
      );

      // Apply the effect of the updated transaction.
      if (updatedTransaction.isIncome) {
        _balanceProvider.addIncome(updatedTransaction.amount);
      } else {
        _balanceProvider.addExpense(updatedTransaction.amount);
      }

      // If the updated transaction is an investment, record it in history.
      if (updatedTransaction.transactionType == TransactionType.investment) {
        _investmentProvider.recordInvestmentTransaction(
            updatedTransaction.amount,
            date: DateTime.parse(updatedTransaction.date));
      }

      saveTransactions();
      notifyListeners();
    }
  }

  // Remove a transaction and update balances
  Future<void> removeTransaction(int id, BuildContext context) async {
    // Find the index of the transaction with the given id.
    final index = _transactions.indexWhere((t) => t.id == id);
    if (index != -1) {
      // Remove the transaction from the list.
      final removedTransaction = _transactions.removeAt(index);

      // Update balances.
      if (removedTransaction.isIncome) {
        _balanceProvider.deductBalanceForIncome(removedTransaction.amount);
      } else {
        _balanceProvider.deductBalanceOnDelete(removedTransaction.amount);
      }

      // If the removed transaction is investment-related, update historical transactions.
      if (removedTransaction.transactionType == TransactionType.investment) {
        _investmentProvider.removeHistoricalInvestmentTransaction(
            removedTransaction.amount, removedTransaction.date);
      }

      await saveTransactions();
      notifyListeners();
    } else {
      print('Transaction with id $id not found.');
    }
  }

  Future<void> clearTransactions() async {
    _transactions.clear();
    _nextId = 0;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('transactions', jsonEncode([])); // Save empty list
    notifyListeners();
  }
}
