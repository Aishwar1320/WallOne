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
  final String createdAt; // Add this field to track creation time

  AllListProvider({
    this.id = -1,
    required this.title,
    required this.category,
    required this.amount,
    required this.isIncome,
    String? date,
    String? createdAt,
  })  : date = date ?? DateTime.now().toIso8601String(),
        createdAt = createdAt ?? DateTime.now().toIso8601String();

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
    };
  }

  // Create object from JSON
  factory AllListProvider.fromJson(Map<String, dynamic> json) {
    return AllListProvider(
      id: json['id'],
      title: json['title'],
      category: json['category'],
      amount: json['amount'],
      date: json['date'],
      isIncome: json['isIncome'],
      createdAt: json['createdAt'] ??
          DateTime.now().toIso8601String(), // Handle legacy data
    );
  }

  @override
  String toString() {
    return 'AllListProvider(id: $id, title: $title, category: $category, amount: $amount, date: $date, isIncome: $isIncome, createdAt: $createdAt)';
  }
}

class ListProvider with ChangeNotifier {
  final List<AllListProvider> _transactions = [];
  final BalanceProvider _balanceProvider;
  final InvestmentProvider investmentProvider;
  int _nextId = 0;

  // Add new properties to track current filter settings
  bool _isFilterActive = false;
  bool _isExpensesSelected = true;
  String _currentPeriod = 'All Dates'; // Changed default to 'All Dates'

  ListProvider(this._balanceProvider, this.investmentProvider);

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

    // Sort by createdAt (newest first) - this ensures consistent ordering
    listToReturn.sort((a, b) {
      try {
        final dateA = DateTime.parse(a.createdAt);
        final dateB = DateTime.parse(b.createdAt);
        return dateB.compareTo(dateA);
      } catch (_) {
        // Fallback to date field if createdAt parsing fails
        try {
          final dateA = DateTime.parse(a.date);
          final dateB = DateTime.parse(b.date);
          return dateB.compareTo(dateA);
        } catch (_) {
          return 0;
        }
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

    // Then apply date filter if not 'All Dates'
    if (selectedDate != 'All Dates') {
      filtered = filtered.where((t) {
        try {
          // Parse the createdAt timestamp to get the date
          final createdAtDate = DateTime.parse(t.createdAt);
          final createdAtDateOnly = DateFormat('dd-MM').format(createdAtDate);

          // Handle 'Today' case
          if (selectedDate == 'Today') {
            final today = DateFormat('dd-MM').format(DateTime.now());
            return createdAtDateOnly == today;
          }

          // For specific dates in 'dd-MM' format
          return createdAtDateOnly == selectedDate;
        } catch (e) {
          print(
              'Error parsing createdAt for transaction ${t.id}: ${t.createdAt}');
          return false;
        }
      }).toList();
    }

    // Sort by createdAt for consistent ordering (newest first)
    filtered.sort((a, b) {
      try {
        final dateA = DateTime.parse(a.createdAt);
        final dateB = DateTime.parse(b.createdAt);
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

    return _transactions.where((t) {
      try {
        final createdAtDate = DateTime.parse(t.createdAt);
        final createdAtDateOnly = DateFormat('dd-MM').format(createdAtDate);

        if (dateFilter == 'Today') {
          final today = DateFormat('dd-MM').format(DateTime.now());
          return createdAtDateOnly == today;
        }

        return createdAtDateOnly == dateFilter;
      } catch (e) {
        print(
            'Error parsing createdAt for transaction ${t.id}: ${t.createdAt}');
        return false;
      }
    }).toList()
      ..sort((a, b) {
        try {
          final dateA = DateTime.parse(a.createdAt);
          final dateB = DateTime.parse(b.createdAt);
          return dateB.compareTo(dateA);
        } catch (_) {
          return 0;
        }
      });
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
    } catch (e, stackTrace) {
      print('Error saving transactions: $e');
      print('Stack trace: $stackTrace');
    }
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

    // Add new transaction at the beginning
    _transactions.insert(
        0,
        AllListProvider(
          id: _nextId++,
          title: transaction.title,
          category: transaction.category,
          amount: transaction.amount,
          isIncome: transaction.isIncome,
          date: transaction.date, // Keep the specified date
          createdAt: now, // Always use current time for createdAt
        ));

    if (updateBalance) {
      if (transaction.isIncome) {
        _balanceProvider.addIncome(transaction.amount);
      } else {
        _balanceProvider.addExpense(transaction.amount);
      }
    }

    saveTransactions();
    notifyListeners();
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
      if (oldTransaction.title.contains("Investment")) {
        // Find matching transaction in InvestmentProvider
        final parsedDate = DateTime.parse(oldTransaction.date);
        final histIndex = investmentProvider.investmentTransactions.indexWhere(
          (tx) =>
              tx.amount == oldTransaction.amount &&
              tx.date.isAtSameMomentAs(parsedDate),
        );
        if (histIndex != -1) {
          investmentProvider.removeTransaction(histIndex);
        }
      }

      // Update the transaction - preserve the original createdAt
      _transactions[index] = AllListProvider(
        id: updatedTransaction.id,
        title: updatedTransaction.title,
        category: updatedTransaction.category,
        amount: updatedTransaction.amount,
        isIncome: updatedTransaction.isIncome,
        date: updatedTransaction.date,
        createdAt: oldTransaction.createdAt, // Preserve original creation time
      );

      // Apply the effect of the updated transaction.
      if (updatedTransaction.isIncome) {
        _balanceProvider.addIncome(updatedTransaction.amount);
      } else {
        _balanceProvider.addExpense(updatedTransaction.amount);
      }

      // If the updated transaction is an investment, record it in history.
      if (updatedTransaction.title.contains("Investment")) {
        investmentProvider.recordTransaction(
            updatedTransaction.title, updatedTransaction.amount,
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
      if (removedTransaction.title.contains("Investment")) {
        final parsedDate = DateTime.parse(removedTransaction.date);
        final histIndex = investmentProvider.investmentTransactions.indexWhere(
          (tx) =>
              tx.amount == removedTransaction.amount &&
              tx.date.isAtSameMomentAs(parsedDate),
        );
        if (histIndex != -1) {
          investmentProvider.removeTransaction(histIndex);
        }
      }

      await saveTransactions();
      notifyListeners();
    } else {
      print('Transaction with id $id not found.');
    }
  }
}
