class InvestmentTransactionModel {
  final double amount;
  final DateTime date;
  final String? id; // Optional unique identifier

  const InvestmentTransactionModel({
    required this.amount,
    required this.date,
    this.id,
  });

  InvestmentTransactionModel copyWith({
    double? amount,
    DateTime? date,
    String? id,
  }) {
    return InvestmentTransactionModel(
      amount: amount ?? this.amount,
      date: date ?? this.date,
      id: id ?? this.id,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'amount': amount,
      'date': date.toIso8601String(),
      if (id != null) 'id': id,
    };
  }

  factory InvestmentTransactionModel.fromMap(Map<String, dynamic> map) {
    return InvestmentTransactionModel(
      amount: (map['amount'] ?? 0).toDouble(),
      date: DateTime.parse(map['date']),
      id: map['id'],
    );
  }

  @override
  String toString() {
    return 'InvestmentTransactionModel(amount: $amount, date: $date, id: $id)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is InvestmentTransactionModel &&
        other.amount == amount &&
        other.date == date &&
        other.id == id;
  }

  @override
  int get hashCode => amount.hashCode ^ date.hashCode ^ id.hashCode;
}

class Investment {
  final String name;
  final double amount;
  bool isActive;
  final DateTime startDate;
  DateTime lastDeductionDate;
  final String category;
  final List<double> monthlyDeductions;

  Investment({
    required this.name,
    required this.amount,
    this.isActive = true,
    DateTime? startDate,
    DateTime? lastDeductionDate,
    this.category = 'Other',
    List<double>? monthlyDeductions,
  })  : startDate = startDate ?? DateTime.now(),
        lastDeductionDate = lastDeductionDate ?? DateTime.now(),
        monthlyDeductions = monthlyDeductions ?? [];

  // Returns the cumulative sum of all deduction transactions.
  double get totalDeducted =>
      monthlyDeductions.fold(0.0, (sum, amount) => sum + amount);

  Investment copyWith({
    double? amount,
    bool? isActive,
    DateTime? lastDeductionDate,
    String? category,
  }) {
    return Investment(
      name: name,
      amount: amount ?? this.amount,
      isActive: isActive ?? this.isActive,
      startDate: startDate,
      lastDeductionDate: lastDeductionDate ?? this.lastDeductionDate,
      category: category ?? this.category,
      monthlyDeductions: monthlyDeductions,
    );
  }
}
