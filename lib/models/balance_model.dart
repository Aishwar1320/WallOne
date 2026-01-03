class BalanceModel {
  final double totalBalance;
  final double dailyExpenses;
  final double weeklyExpenses;
  final double monthlyExpenses;
  final double dailyIncomes;
  final double weeklyIncomes;
  final double monthlyIncomes;
  final String? dailyKey;
  final String? weeklyKey;
  final String? monthlyKey;

  const BalanceModel({
    this.totalBalance = 0.0,
    this.dailyExpenses = 0.0,
    this.weeklyExpenses = 0.0,
    this.monthlyExpenses = 0.0,
    this.dailyIncomes = 0.0,
    this.weeklyIncomes = 0.0,
    this.monthlyIncomes = 0.0,
    this.dailyKey,
    this.weeklyKey,
    this.monthlyKey,
  });

  // Create a copy with updated values
  BalanceModel copyWith({
    double? totalBalance,
    double? dailyExpenses,
    double? weeklyExpenses,
    double? monthlyExpenses,
    double? dailyIncomes,
    double? weeklyIncomes,
    double? monthlyIncomes,
    String? dailyKey,
    String? weeklyKey,
    String? monthlyKey,
  }) {
    return BalanceModel(
      totalBalance: totalBalance ?? this.totalBalance,
      dailyExpenses: dailyExpenses ?? this.dailyExpenses,
      weeklyExpenses: weeklyExpenses ?? this.weeklyExpenses,
      monthlyExpenses: monthlyExpenses ?? this.monthlyExpenses,
      dailyIncomes: dailyIncomes ?? this.dailyIncomes,
      weeklyIncomes: weeklyIncomes ?? this.weeklyIncomes,
      monthlyIncomes: monthlyIncomes ?? this.monthlyIncomes,
      dailyKey: dailyKey ?? this.dailyKey,
      weeklyKey: weeklyKey ?? this.weeklyKey,
      monthlyKey: monthlyKey ?? this.monthlyKey,
    );
  }

  // Convert to Map for storage
  Map<String, dynamic> toMap() {
    return {
      'totalBalance': totalBalance,
      'dailyExpenses': dailyExpenses,
      'weeklyExpenses': weeklyExpenses,
      'monthlyExpenses': monthlyExpenses,
      'dailyIncomes': dailyIncomes,
      'weeklyIncomes': weeklyIncomes,
      'monthlyIncomes': monthlyIncomes,
      if (dailyKey != null) 'dailyKey': dailyKey,
      if (weeklyKey != null) 'weeklyKey': weeklyKey,
      if (monthlyKey != null) 'monthlyKey': monthlyKey,
    };
  }

  // Create from Map (from storage)
  factory BalanceModel.fromMap(Map<String, dynamic> map) {
    return BalanceModel(
      totalBalance: (map['totalBalance'] ?? 0).toDouble(),
      dailyExpenses: (map['dailyExpenses'] ?? 0).toDouble(),
      weeklyExpenses: (map['weeklyExpenses'] ?? 0).toDouble(),
      monthlyExpenses: (map['monthlyExpenses'] ?? 0).toDouble(),
      dailyIncomes: (map['dailyIncomes'] ?? 0).toDouble(),
      weeklyIncomes: (map['weeklyIncomes'] ?? 0).toDouble(),
      monthlyIncomes: (map['monthlyIncomes'] ?? 0).toDouble(),
      dailyKey: map['dailyKey'] as String?,
      weeklyKey: map['weeklyKey'] as String?,
      monthlyKey: map['monthlyKey'] as String?,
    );
  }

  // Formatted getters for UI
  String get formattedTotalBalance => formatValue(totalBalance);
  String get formattedDailyExpenses => formatValue(dailyExpenses);
  String get formattedWeeklyExpenses => formatValue(weeklyExpenses);
  String get formattedMonthlyExpenses => formatValue(monthlyExpenses);
  String get formattedDailyIncomes => formatValue(dailyIncomes);
  String get formattedWeeklyIncomes => formatValue(weeklyIncomes);
  String get formattedMonthlyIncomes => formatValue(monthlyIncomes);

  String formatValue(double value) {
    try {
      if (value.abs() >= 1000) {
        double valueInK = value / 1000;
        return valueInK == valueInK.roundToDouble()
            ? '${valueInK.toInt()}k'
            : '${valueInK.toStringAsFixed(1)}k';
      }
      return value == value.roundToDouble()
          ? value.toInt().toString()
          : value.toStringAsFixed(2);
    } catch (e) {
      return value.toString(); // Fallback
    }
  }

  @override
  String toString() {
    return 'BalanceModel(totalBalance: $totalBalance, dailyExpenses: $dailyExpenses, weeklyExpenses: $weeklyExpenses, monthlyExpenses: $monthlyExpenses, dailyIncomes: $dailyIncomes, weeklyIncomes: $weeklyIncomes, monthlyIncomes: $monthlyIncomes, dailyKey: $dailyKey, weeklyKey: $weeklyKey, monthlyKey: $monthlyKey)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is BalanceModel &&
        other.totalBalance == totalBalance &&
        other.dailyExpenses == dailyExpenses &&
        other.weeklyExpenses == weeklyExpenses &&
        other.monthlyExpenses == monthlyExpenses &&
        other.dailyIncomes == dailyIncomes &&
        other.weeklyIncomes == weeklyIncomes &&
        other.monthlyIncomes == monthlyIncomes &&
        other.dailyKey == dailyKey &&
        other.weeklyKey == weeklyKey &&
        other.monthlyKey == monthlyKey;
  }

  @override
  int get hashCode {
    return totalBalance.hashCode ^
        dailyExpenses.hashCode ^
        weeklyExpenses.hashCode ^
        monthlyExpenses.hashCode ^
        dailyIncomes.hashCode ^
        weeklyIncomes.hashCode ^
        monthlyIncomes.hashCode ^
        dailyKey.hashCode ^
        weeklyKey.hashCode ^
        monthlyKey.hashCode;
  }
}
