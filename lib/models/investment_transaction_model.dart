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
