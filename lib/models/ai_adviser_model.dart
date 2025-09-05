import 'dart:math';

/// ---------------------- Enums ----------------------

enum AdviceType {
  budget,
  saving,
  investment,
  spending,
  warning,
  prediction,
  optimization,
  behavioral
}

enum AdvicePriority { low, medium, high, critical }

/// ---------------------- Config ----------------------

class AdvisorConfig {
  final double emergencyFundTargetMonths;
  final double savingsRateTarget;
  final double budgetUtilizationOptimal;
  final double volatilityThreshold;
  final int maxInsights;

  const AdvisorConfig({
    this.emergencyFundTargetMonths = 6.0,
    this.savingsRateTarget = 0.20,
    this.budgetUtilizationOptimal = 0.85,
    this.volatilityThreshold = 0.30,
    this.maxInsights = 6,
  });
}

/// ---------------------- Insight Model ----------------------

class AIInsight {
  final String id;
  final String title;
  final String description;
  final AdviceType type;
  final AdvicePriority priority;
  final double confidence; // 0.0 - 1.0
  final String icon;
  final bool actionable;
  final Map<String, dynamic>? metadata;
  final String? actionHint;

  AIInsight({
    required this.id,
    required this.title,
    required this.description,
    required this.type,
    required this.priority,
    required this.confidence,
    required this.icon,
    this.actionable = false,
    this.metadata,
    this.actionHint,
  });

  /// ✅ JSON factory
  factory AIInsight.fromJson(Map<String, dynamic> json) {
    return AIInsight(
      id: json['id']?.toString() ??
          DateTime.now().millisecondsSinceEpoch.toString(),
      title: json['title'] ?? '',
      description: json['description'] ?? '',
      type: _parseAdviceType(json['type']),
      priority: _parseAdvicePriority(json['priority']),
      confidence: (json['confidence'] is num)
          ? (json['confidence'] as num).toDouble()
          : 0.0,
      icon: json['icon'] ?? '💡',
      actionable: json['actionable'] ?? false,
      metadata: json['metadata'] != null
          ? Map<String, dynamic>.from(json['metadata'])
          : null,
      actionHint: json['actionHint'],
    );
  }

  /// ✅ JSON encoder
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'type': type.toString().split('.').last,
      'priority': priority.toString().split('.').last,
      'confidence': confidence,
      'icon': icon,
      'actionable': actionable,
      'metadata': metadata,
      'actionHint': actionHint,
    };
  }

  @override
  bool operator ==(Object other) => other is AIInsight && other.id == id;

  @override
  int get hashCode => id.hashCode;
}

/// ---------------------- Helpers ----------------------

AdviceType _parseAdviceType(dynamic value) {
  if (value is String) {
    return AdviceType.values.firstWhere(
      (e) => e.toString().split('.').last.toLowerCase() == value.toLowerCase(),
      orElse: () => AdviceType.budget,
    );
  }
  return AdviceType.budget;
}

AdvicePriority _parseAdvicePriority(dynamic value) {
  if (value is String) {
    return AdvicePriority.values.firstWhere(
      (e) => e.toString().split('.').last.toLowerCase() == value.toLowerCase(),
      orElse: () => AdvicePriority.low,
    );
  }
  return AdvicePriority.low;
}

/// ---------------------- Smart Spending Pattern ----------------------

class SmartSpendingPattern {
  final String category;
  final double medianAmount;
  final int frequency;
  final List<double> amounts;
  final double trend; // relative trend (percent)
  final double volatility; // robust volatility (MAD/median)
  final List<DateTime> dates;
  final double seasonality; // -1..1
  final double predictedNextAmount;

  SmartSpendingPattern({
    required this.category,
    required this.medianAmount,
    required this.frequency,
    required this.amounts,
    required this.trend,
    required this.volatility,
    required this.dates,
    required this.seasonality,
    required this.predictedNextAmount,
  });
}

/// ---------------------- Financial Health ----------------------

class FinancialHealth {
  final double emergencyFundRatio;
  final double savingsRate;
  final double debtToIncomeRatio;
  final double liquidityRatio;
  final double financialStabilityScore; // 0..100
  final String healthGrade;

  FinancialHealth({
    required this.emergencyFundRatio,
    required this.savingsRate,
    required this.debtToIncomeRatio,
    required this.liquidityRatio,
    required this.financialStabilityScore,
    required this.healthGrade,
  });
}

/// ---------------------- Action Tracker ----------------------

class ActionTracker {
  static final Map<String, DateTime> _completedActions = {};

  static void markActionCompleted(String actionType, String category) {
    final key = '${actionType}_$category';
    _completedActions[key] = DateTime.now();
  }

  static bool wasActionCompleted(String actionType, String category,
      {int withinDays = 30}) {
    final key = '${actionType}_$category';
    final completedDate = _completedActions[key];
    if (completedDate == null) return false;

    final daysSinceCompleted = DateTime.now().difference(completedDate).inDays;
    return daysSinceCompleted <= withinDays;
  }

  static void clearOldActions({int olderThanDays = 90}) {
    final cutoff = DateTime.now().subtract(Duration(days: olderThanDays));
    _completedActions.removeWhere((key, date) => date.isBefore(cutoff));
  }
}
