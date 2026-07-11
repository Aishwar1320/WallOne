import 'package:flutter/material.dart';
import 'package:wallone/features/ai_adviser/services/rule_based_advisor.dart';

/// Shared helpers for insight display.
///
/// Previously duplicated verbatim in both [MinimalInsightDisplay] and
/// [EnhancedInsightsTab]. Consolidated here as top-level functions to
/// eliminate the duplication.
Color insightPriorityColor(InsightPriority priority) {
  switch (priority) {
    case InsightPriority.high:
      return Colors.red;
    case InsightPriority.medium:
      return Colors.orange;
    case InsightPriority.low:
      return Colors.green;
  }
}

IconData insightTypeIcon(InsightType type) {
  switch (type) {
    case InsightType.budget:
      return Icons.pie_chart;
    case InsightType.savings:
      return Icons.savings;
    case InsightType.investment:
      return Icons.trending_up;
    case InsightType.expense:
      return Icons.money_off;
    case InsightType.income:
      return Icons.attach_money;
    case InsightType.alert:
      return Icons.warning;
    case InsightType.general:
      return Icons.info;
  }
}

/// Returns a color indicating financial health: green ≥ 80, orange ≥ 60, red otherwise.
Color insightHealthScoreColor(int score) {
  if (score >= 80) return Colors.green;
  if (score >= 60) return Colors.orange;
  return Colors.red;
}

/// Returns a trending icon matching the health score tier.
IconData insightHealthScoreIcon(int score) {
  if (score >= 80) return Icons.trending_up;
  if (score >= 60) return Icons.trending_flat;
  return Icons.trending_down;
}

/// Formats a monetary amount as L (lakh) / K (thousand) shorthand.
String formatInsightAmount(double amount) {
  if (amount >= 100000) {
    return '${(amount / 100000).toStringAsFixed(1)}L';
  } else if (amount >= 1000) {
    return '${(amount / 1000).toStringAsFixed(1)}K';
  }
  return amount.toStringAsFixed(0);
}
