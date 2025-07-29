import 'package:shared_preferences/shared_preferences.dart';
import 'package:wallone/models/investment_model.dart';
import 'dart:convert';

class BalanceStorage {
  static const _balanceKeys = {
    'totalBalance',
    'dailyExpenses',
    'weeklyExpenses',
    'monthlyExpenses',
    'dailyIncomes',
    'weeklyIncomes',
    'monthlyIncomes',
    'lastResetDate',
    'investments',
    'lastInvestmentCheckDate',
    'totalInvestments',
  };

  final SharedPreferences _prefs;

  BalanceStorage(this._prefs);

  static Future<BalanceStorage> create() async {
    final prefs = await SharedPreferences.getInstance();
    return BalanceStorage(prefs);
  }

  // ✅ Load Balances with Date Format Fix
  Future<Map<String, dynamic>> loadBalances() async {
    return {
      'totalBalance': _prefs.getDouble('totalBalance') ?? 0,
      'dailyExpenses': _prefs.getDouble('dailyExpenses') ?? 0,
      'weeklyExpenses': _prefs.getDouble('weeklyExpenses') ?? 0,
      'monthlyExpenses': _prefs.getDouble('monthlyExpenses') ?? 0,
      'dailyIncomes': _prefs.getDouble('dailyIncomes') ?? 0,
      'weeklyIncomes': _prefs.getDouble('weeklyIncomes') ?? 0,
      'monthlyIncomes': _prefs.getDouble('monthlyIncomes') ?? 0,
      'lastResetDate': _fixDateFormat(_prefs.getString('lastResetDate')),
      'totalInvestments': _prefs.getDouble('totalInvestments') ?? 0,
    };
  }

  Future<void> saveBalances(Map<String, dynamic> balances) async {
    print("Saving balances: $balances");
    await _prefs.setDouble('totalBalance', balances['totalBalance']);
    await _prefs.setDouble('dailyExpenses', balances['dailyExpenses']);
    await _prefs.setDouble('weeklyExpenses', balances['weeklyExpenses']);
    await _prefs.setDouble('monthlyExpenses', balances['monthlyExpenses']);
    await _prefs.setDouble('dailyIncomes', balances['dailyIncomes']);
    await _prefs.setDouble('weeklyIncomes', balances['weeklyIncomes']);
    await _prefs.setDouble('monthlyIncomes', balances['monthlyIncomes']);
    await _prefs.setDouble(
        'totalInvestments', balances['totalInvestments'] ?? 0);
  }

  // ✅ Fix Date Format Before Saving
  Future<void> saveLastResetDate(DateTime date) async {
    final formattedDate = date.toIso8601String();
    print("Saving last reset date (formatted): $formattedDate");
    await _prefs.setString('lastResetDate', formattedDate);
  }

  // ✅ Investment Methods
  Future<List<InvestmentModel>> loadInvestments() async {
    try {
      final investmentData = _prefs.getStringList('investments');

      if (investmentData == null) {
        print("No investments found in storage.");
        return [];
      }

      print("Loading investments from storage: $investmentData");

      return investmentData
          .map((data) {
            try {
              final jsonData = jsonDecode(data);
              return InvestmentModel(
                name: jsonData['name'],
                amount: jsonData['amount'],
                isActive: jsonData['isActive'],
                startDate: _parseDate(jsonData['startDate']),
                lastDeductionDate: _parseDate(jsonData['lastDeductionDate']),
                category: jsonData['category'] ?? 'Other', // Default category
                monthlyDeductions:
                    (jsonData['monthlyDeductions'] as List<dynamic>?)
                            ?.map((e) => e as double)
                            .toList() ??
                        [], // Default empty list
              );
            } catch (e) {
              print("Error parsing investment: $e");
              return null;
            }
          })
          .whereType<InvestmentModel>()
          .toList();
    } catch (e) {
      print("Failed to load investments: $e");
      return []; // Return an empty list as a fallback
    }
  }

  Future<void> migrateOldInvestments() async {
    try {
      final investments = await loadInvestments();
      print("Migrating old investments: $investments");
      await saveInvestments(investments);
    } catch (e) {
      print("Failed to migrate old investments: $e");
    }
  }

  // ✅ Improved Date Parsing with Format Fix
  DateTime _parseDate(String? dateStr) {
    if (dateStr == null) {
      print("Null date received, using current date.");
      return DateTime.now();
    }

    try {
      return DateTime.parse(dateStr); // Correct format
    } catch (e) {
      try {
        final parts = dateStr.split('-').map(int.parse).toList();
        final fixedDate = DateTime(parts[0], parts[1], parts[2]);
        print("Fixed date format: $fixedDate");
        return fixedDate;
      } catch (e) {
        print("Invalid date: $dateStr - Defaulting to today.");
        return DateTime.now();
      }
    }
  }

  // ✅ Fix Invalid Date Formats from SharedPreferences
  String? _fixDateFormat(String? dateStr) {
    if (dateStr == null) return null;

    try {
      return DateTime.parse(dateStr).toIso8601String(); // Ensure correct format
    } catch (e) {
      try {
        final parts = dateStr.split('-').map(int.parse).toList();
        final formattedDate =
            DateTime(parts[0], parts[1], parts[2]).toIso8601String();
        print("Fixed stored date format: $formattedDate");
        return formattedDate;
      } catch (e) {
        print(
            "Invalid stored date format: $dateStr - Setting default to today.");
        return DateTime.now().toIso8601String();
      }
    }
  }

  Future<void> saveInvestments(List<InvestmentModel> investments) async {
    try {
      final investmentData = investments
          .map((inv) => jsonEncode({
                'name': inv.name,
                'amount': inv.amount,
                'isActive': inv.isActive,
                'startDate': inv.startDate.toIso8601String(),
                'lastDeductionDate': inv.lastDeductionDate.toIso8601String(),
                'category': inv.category,
                'monthlyDeductions': inv.monthlyDeductions,
              }))
          .toList();

      print("Saving investments: $investmentData");

      await _prefs.setStringList('investments', investmentData);
    } catch (e) {
      print("Failed to save investments: $e");
      // Optionally, retry saving or notify the user
    }
  }

  // ✅ Investment check date methods
  Future<DateTime> loadLastInvestmentCheckDate() async {
    final dateStr = _prefs.getString('lastInvestmentCheckDate');
    print("Loading last investment check date: $dateStr");
    return dateStr != null ? _parseDate(dateStr) : DateTime.now();
  }

  Future<void> saveLastInvestmentCheckDate(DateTime date) async {
    final formattedDate = date.toIso8601String();
    print("Saving last investment check date: $formattedDate");
    await _prefs.setString('lastInvestmentCheckDate', formattedDate);
  }

  DateTime? getLastResetDate() {
    final dateStr = _prefs.getString('lastResetDate');
    if (dateStr == null) return null;

    try {
      return DateTime.parse(dateStr);
    } catch (e) {
      print("Invalid lastResetDate format: $dateStr");
      return null;
    }
  }

  // ✅ Clear all data (for debugging/reset)
  Future<void> clearAll() async {
    print("Clearing all balance and investment data...");
    await Future.wait(_balanceKeys.map((key) => _prefs.remove(key)));
    print("All data cleared.");
  }
}
