// ✅ balance_storage.dart
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
    'lastWeeklyResetDate',
    'lastMonthlyResetDate',
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

  Future<void> saveLastResetDate(DateTime date) async {
    final formattedDate = date.toIso8601String();
    await _prefs.setString('lastResetDate', formattedDate);
  }

  Future<void> saveLastWeeklyResetDate(DateTime date) async {
    await _prefs.setString('lastWeeklyResetDate', date.toIso8601String());
  }

  Future<void> saveLastMonthlyResetDate(DateTime date) async {
    await _prefs.setString('lastMonthlyResetDate', date.toIso8601String());
  }

  Future<DateTime?> loadLastWeeklyResetDate() async {
    final dateStr = _prefs.getString('lastWeeklyResetDate');
    return dateStr != null ? _parseDate(dateStr) : null;
  }

  Future<DateTime?> loadLastMonthlyResetDate() async {
    final dateStr = _prefs.getString('lastMonthlyResetDate');
    return dateStr != null ? _parseDate(dateStr) : null;
  }

  Future<List<InvestmentModel>> loadInvestments() async {
    try {
      final investmentData = _prefs.getStringList('investments');
      if (investmentData == null) return [];

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
                category: jsonData['category'] ?? 'Other',
                monthlyDeductions:
                    (jsonData['monthlyDeductions'] as List<dynamic>?)
                            ?.map((e) => e as double)
                            .toList() ??
                        [],
              );
            } catch (e) {
              return null;
            }
          })
          .whereType<InvestmentModel>()
          .toList();
    } catch (e) {
      return [];
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

      await _prefs.setStringList('investments', investmentData);
    } catch (e) {}
  }

  Future<void> migrateOldInvestments() async {
    try {
      final investments = await loadInvestments();
      await saveInvestments(investments);
    } catch (e) {}
  }

  Future<DateTime> loadLastInvestmentCheckDate() async {
    final dateStr = _prefs.getString('lastInvestmentCheckDate');
    return dateStr != null ? _parseDate(dateStr) : DateTime.now();
  }

  Future<void> saveLastInvestmentCheckDate(DateTime date) async {
    final formattedDate = date.toIso8601String();
    await _prefs.setString('lastInvestmentCheckDate', formattedDate);
  }

  DateTime _parseDate(String? dateStr) {
    if (dateStr == null) return DateTime.now();
    try {
      return DateTime.parse(dateStr);
    } catch (e) {
      try {
        final parts = dateStr.split('-').map(int.parse).toList();
        return DateTime(parts[0], parts[1], parts[2]);
      } catch (e) {
        return DateTime.now();
      }
    }
  }

  String? _fixDateFormat(String? dateStr) {
    if (dateStr == null) return null;
    try {
      return DateTime.parse(dateStr).toIso8601String();
    } catch (e) {
      try {
        final parts = dateStr.split('-').map(int.parse).toList();
        return DateTime(parts[0], parts[1], parts[2]).toIso8601String();
      } catch (e) {
        return DateTime.now().toIso8601String();
      }
    }
  }

  Future<void> clearAll() async {
    await Future.wait(_balanceKeys.map((key) => _prefs.remove(key)));
  }
}
