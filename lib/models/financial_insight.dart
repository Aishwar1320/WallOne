enum InsightType {
  budget,
  savings,
  investment,
  expense,
  income,
  alert,
  general
}

enum InsightPriority { high, medium, low }

/// FinancialInsight model used across the app for AI-driven insights.
class FinancialInsight {
  final String id;
  final String title;
  final String description;
  final String category;
  final InsightType type;
  final InsightPriority priority;
  final Map<String, dynamic> actionData;
  final double? recommendedAmount;
  final String? targetCategory;
  final DateTime createdAt;
  final bool isActionable;
  final bool isExecuted;
  final DateTime? executedAt;
  final double? confidenceScore;
  final List<String>? supportingData;

  FinancialInsight({
    required this.id,
    required this.title,
    required this.description,
    required this.category,
    required this.type,
    required this.priority,
    required this.actionData,
    this.recommendedAmount,
    this.targetCategory,
    required this.createdAt,
    this.isActionable = false,
    this.isExecuted = false,
    this.executedAt,
    this.confidenceScore,
    this.supportingData,
  });

  factory FinancialInsight.fromJson(Map<String, dynamic> json) {
    double? parseDouble(dynamic v) {
      if (v == null) return null;
      if (v is num) return v.toDouble();
      if (v is String) return double.tryParse(v);
      return null;
    }

    bool parseBool(dynamic v) {
      if (v == null) return false;
      if (v is bool) return v;
      if (v is String) {
        final lower = v.toLowerCase();
        return lower == 'true' || lower == '1' || lower == 'yes';
      }
      if (v is num) return v != 0;
      return false;
    }

    final categoryVal = json['category'] as String?;
    final typeVal = json['type'] as String? ?? categoryVal;

    return FinancialInsight(
      id: json['id'] ?? DateTime.now().millisecondsSinceEpoch.toString(),
      title: json['title'] ?? '',
      description: json['description'] ?? '',
      category: categoryVal ?? 'general',
      type: _parseInsightType(typeVal),
      priority: _parsePriority(json['priority']),
      actionData: Map<String, dynamic>.from(json['actionData'] ?? {}),
      recommendedAmount: parseDouble(json['recommendedAmount']),
      targetCategory: json['targetCategory'] ??
          (json['actionData'] is Map
              ? (json['actionData']['parameters']?['category'] ??
                  json['actionData']['category'])
              : null),
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt']) ?? DateTime.now()
          : DateTime.now(),
      isActionable: parseBool(json['isActionable']),
      isExecuted: parseBool(json['isExecuted']),
      executedAt: json['executedAt'] != null
          ? DateTime.tryParse(json['executedAt'])
          : null,
      confidenceScore: parseDouble(json['confidenceScore']),
      supportingData: json['supportingData'] != null
          ? List<String>.from(json['supportingData'])
          : null,
    );
  }

  FinancialInsight copyWith({
    String? id,
    String? title,
    String? description,
    String? category,
    InsightType? type,
    InsightPriority? priority,
    Map<String, dynamic>? actionData,
    double? recommendedAmount,
    String? targetCategory,
    DateTime? createdAt,
    bool? isActionable,
    bool? isExecuted,
    DateTime? executedAt,
    double? confidenceScore,
    List<String>? supportingData,
  }) {
    return FinancialInsight(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      category: category ?? this.category,
      type: type ?? this.type,
      priority: priority ?? this.priority,
      actionData: actionData ?? this.actionData,
      recommendedAmount: recommendedAmount ?? this.recommendedAmount,
      targetCategory: targetCategory ?? this.targetCategory,
      createdAt: createdAt ?? this.createdAt,
      isActionable: isActionable ?? this.isActionable,
      isExecuted: isExecuted ?? this.isExecuted,
      executedAt: executedAt ?? this.executedAt,
      confidenceScore: confidenceScore ?? this.confidenceScore,
      supportingData: supportingData ?? this.supportingData,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'category': category,
      'type': _getInsightTypeName(type),
      'priority': _getPriorityName(priority),
      'actionData': actionData,
      'recommendedAmount': recommendedAmount,
      'targetCategory': targetCategory,
      'createdAt': createdAt.toIso8601String(),
      'isActionable': isActionable,
      'isExecuted': isExecuted,
      'executedAt': executedAt?.toIso8601String(),
      'confidenceScore': confidenceScore,
      'supportingData': supportingData,
    };
  }

  static String _getInsightTypeName(InsightType type) {
    return type.toString().split('.').last;
  }

  static String _getPriorityName(InsightPriority priority) {
    return priority.toString().split('.').last;
  }

  static InsightType _parseInsightType(String? type) {
    final t = (type ?? '').toLowerCase();

    if (t.contains('budget') || t.contains('create_budget')) {
      return InsightType.budget;
    }
    if (t.contains('saving')) return InsightType.savings;
    if (t.contains('invest')) return InsightType.investment;
    if (t.contains('expense')) return InsightType.expense;
    if (t.contains('income')) return InsightType.income;
    if (t.contains('alert') ||
        t.contains('low_balance') ||
        t.contains('warning')) {
      return InsightType.alert;
    }

    return InsightType.general;
  }

  static InsightPriority _parsePriority(String? priority) {
    switch (priority?.toLowerCase()) {
      case 'high':
        return InsightPriority.high;
      case 'medium':
        return InsightPriority.medium;
      case 'low':
        return InsightPriority.low;
      default:
        return InsightPriority.medium;
    }
  }
}
