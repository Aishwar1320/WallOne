import 'package:flutter/material.dart';

class TransactionTypeProvider with ChangeNotifier {
  bool _isExpensesSelected = true;

  bool get isExpensesSelected => _isExpensesSelected;

  void toggleTransactionType() {
    _isExpensesSelected = !_isExpensesSelected;
    notifyListeners();
  }

  // Method to reset the value to true (Expenses selected by default)
  void resetToExpenses() {
    _isExpensesSelected = true;
    notifyListeners();
  }

  // New method to set the transaction type explicitly.
  void setTransactionType(bool isExpensesSelected) {
    _isExpensesSelected = isExpensesSelected;
    notifyListeners();
  }
}
