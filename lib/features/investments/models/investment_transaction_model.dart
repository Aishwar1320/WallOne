class InvestmentTransactionModel {
  final double amount;
  final DateTime date;
  final String? id; // Optional unique identifier
  final String?
      investmentName; // Name of the investment this transaction belongs to
  final String? note; // Optional note about the transaction

  const InvestmentTransactionModel({
    required this.amount,
    required this.date,
    this.id,
    this.investmentName,
    this.note,
  });

  InvestmentTransactionModel copyWith({
    double? amount,
    DateTime? date,
    String? id,
    String? investmentName,
    String? note,
  }) {
    return InvestmentTransactionModel(
      amount: amount ?? this.amount,
      date: date ?? this.date,
      id: id ?? this.id,
      investmentName: investmentName ?? this.investmentName,
      note: note ?? this.note,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'amount': amount,
      'date': date.toIso8601String(),
      if (id != null) 'id': id,
      if (investmentName != null) 'investmentName': investmentName,
      if (note != null) 'note': note,
    };
  }

  factory InvestmentTransactionModel.fromMap(Map<String, dynamic> map) {
    // Parse date safely
    DateTime parseDate(dynamic dateValue) {
      if (dateValue == null) return DateTime.now();
      if (dateValue is DateTime) return dateValue;
      try {
        return DateTime.parse(dateValue.toString());
      } catch (_) {
        return DateTime.now();
      }
    }

    // Parse amount safely
    double parseAmount(dynamic value) {
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

    return InvestmentTransactionModel(
      amount: parseAmount(map['amount']),
      date: parseDate(map['date']),
      id: map['id']?.toString(),
      investmentName: map['investmentName']?.toString(),
      note: map['note']?.toString(),
    );
  }

  @override
  String toString() {
    return 'InvestmentTransactionModel(amount: $amount, date: $date, id: $id, investmentName: $investmentName, note: $note)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is InvestmentTransactionModel &&
        other.amount == amount &&
        other.date == date &&
        other.id == id &&
        other.investmentName == investmentName &&
        other.note == note;
  }

  @override
  int get hashCode =>
      amount.hashCode ^
      date.hashCode ^
      id.hashCode ^
      investmentName.hashCode ^
      note.hashCode;
}
