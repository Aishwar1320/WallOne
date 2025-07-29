class InvestmentModel {
  final String name;
  final double amount;
  final bool isActive;
  final DateTime startDate;
  final DateTime lastDeductionDate;
  final String category;
  final List<double> monthlyDeductions;

  const InvestmentModel({
    required this.name,
    required this.amount,
    this.isActive = true,
    required this.startDate,
    required this.lastDeductionDate,
    this.category = 'Other',
    this.monthlyDeductions = const [],
  });

  // Factory constructor with defaults
  factory InvestmentModel.create({
    required String name,
    required double amount,
    bool isActive = true,
    DateTime? startDate,
    DateTime? lastDeductionDate,
    String category = 'Other',
    List<double>? monthlyDeductions,
  }) {
    final now = DateTime.now();
    return InvestmentModel(
      name: name,
      amount: amount,
      isActive: isActive,
      startDate: startDate ?? now,
      lastDeductionDate: lastDeductionDate ?? now,
      category: category,
      monthlyDeductions: monthlyDeductions ?? [amount],
    );
  }

  // Returns the cumulative sum of all deduction transactions
  double get totalDeducted =>
      monthlyDeductions.fold(0.0, (sum, amount) => sum + amount);

  InvestmentModel copyWith({
    String? name,
    double? amount,
    bool? isActive,
    DateTime? startDate,
    DateTime? lastDeductionDate,
    String? category,
    List<double>? monthlyDeductions,
  }) {
    return InvestmentModel(
      name: name ?? this.name,
      amount: amount ?? this.amount,
      isActive: isActive ?? this.isActive,
      startDate: startDate ?? this.startDate,
      lastDeductionDate: lastDeductionDate ?? this.lastDeductionDate,
      category: category ?? this.category,
      monthlyDeductions: monthlyDeductions ?? List.from(this.monthlyDeductions),
    );
  }

  // Add a new monthly deduction
  InvestmentModel addMonthlyDeduction(
      double deductionAmount, DateTime deductionDate) {
    final updatedDeductions = List<double>.from(monthlyDeductions)
      ..add(deductionAmount);

    return copyWith(
      monthlyDeductions: updatedDeductions,
      lastDeductionDate: deductionDate,
    );
  }

  // Remove a monthly deduction at specific index
  InvestmentModel removeMonthlyDeduction(int index) {
    if (index < 0 || index >= monthlyDeductions.length) {
      return this; // Return unchanged if invalid index
    }

    final updatedDeductions = List<double>.from(monthlyDeductions)
      ..removeAt(index);

    return copyWith(monthlyDeductions: updatedDeductions);
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'amount': amount,
      'isActive': isActive,
      'startDate': startDate.toIso8601String(),
      'lastDeductionDate': lastDeductionDate.toIso8601String(),
      'category': category,
      'monthlyDeductions': monthlyDeductions,
    };
  }

  factory InvestmentModel.fromMap(Map<String, dynamic> map) {
    return InvestmentModel(
      name: map['name'] ?? '',
      amount: (map['amount'] ?? 0).toDouble(),
      isActive: map['isActive'] ?? true,
      startDate:
          DateTime.parse(map['startDate'] ?? DateTime.now().toIso8601String()),
      lastDeductionDate: DateTime.parse(
          map['lastDeductionDate'] ?? DateTime.now().toIso8601String()),
      category: map['category'] ?? 'Other',
      monthlyDeductions: List<double>.from(map['monthlyDeductions'] ?? []),
    );
  }

  @override
  String toString() {
    return 'InvestmentModel(name: $name, amount: $amount, isActive: $isActive, startDate: $startDate, lastDeductionDate: $lastDeductionDate, category: $category, monthlyDeductions: $monthlyDeductions)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is InvestmentModel &&
        other.name == name &&
        other.amount == amount &&
        other.isActive == isActive &&
        other.startDate == startDate &&
        other.lastDeductionDate == lastDeductionDate &&
        other.category == category &&
        _listEquals(other.monthlyDeductions, monthlyDeductions);
  }

  @override
  int get hashCode {
    return name.hashCode ^
        amount.hashCode ^
        isActive.hashCode ^
        startDate.hashCode ^
        lastDeductionDate.hashCode ^
        category.hashCode ^
        monthlyDeductions.hashCode;
  }

  // Helper method for list equality
  bool _listEquals<T>(List<T>? a, List<T>? b) {
    if (a == null) return b == null;
    if (b == null || a.length != b.length) return false;
    for (int index = 0; index < a.length; index += 1) {
      if (a[index] != b[index]) return false;
    }
    return true;
  }
}
