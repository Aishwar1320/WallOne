import 'dart:async';
import 'package:flutter/foundation.dart';

import 'package:wallone/state/balance_provider.dart';
import 'package:wallone/state/investment_provider.dart';
import 'package:wallone/state/budget_provider.dart';
import 'package:wallone/state/list_provider.dart';
import 'package:wallone/state/category_provider.dart';

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
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'category': category,
      'type': type.name,
      'priority': priority.name,
      'actionData': actionData,
      'recommendedAmount': recommendedAmount,
      'targetCategory': targetCategory,
      'createdAt': createdAt.toIso8601String(),
      'isActionable': isActionable,
      'isExecuted': isExecuted,
      'executedAt': executedAt?.toIso8601String(),
    };
  }

  static InsightType _parseInsightType(String? type) {
    final t = (type ?? '').toLowerCase();

    if (t.contains('budget') || t.contains('create_budget'))
      return InsightType.budget;
    if (t.contains('saving')) return InsightType.savings;
    if (t.contains('invest')) return InsightType.investment;
    if (t.contains('expense')) return InsightType.expense;
    if (t.contains('alert') ||
        t.contains('low_balance') ||
        t.contains('warning')) return InsightType.alert;

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

enum InsightType { budget, savings, investment, expense, alert, general }

enum InsightPriority { high, medium, low }

/// Common advisor interface so different implementations can be used.
abstract class FinancialAdvisor {
  List<FinancialInsight> get insights;
  List<FinancialInsight> get activeInsights;

  Future<List<FinancialInsight>> generateFinancialInsights(
      {bool forceRefresh = false});

  Future<bool> executeInsightAction(String insightId,
      {String? customName, double? customAmount});

  void dismissInsight(String insightId);

  Future<String> suggestCategory(String description, double amount);

  Future<Map<String, dynamic>> getSpendingRecommendations();

  Future<bool> optimizeBudgets();
}

/// Rule-based advisor implementation.
class RuleBasedAdvisor implements FinancialAdvisor {
  final BalanceProvider _balanceProvider;
  final InvestmentProvider _investmentProvider;
  final BudgetProvider _budgetProvider;
  final ListProvider _listProvider;
  final CategoryProvider _categoryProvider;

  final List<FinancialInsight> _insights = [];
  DateTime? _lastAnalysisTime;

  static const String _tag = 'RuleBasedAdvisor';

  RuleBasedAdvisor({
    required BalanceProvider balanceProvider,
    required InvestmentProvider investmentProvider,
    required BudgetProvider budgetProvider,
    required ListProvider listProvider,
    required CategoryProvider categoryProvider,
  })  : _balanceProvider = balanceProvider,
        _investmentProvider = investmentProvider,
        _budgetProvider = budgetProvider,
        _listProvider = listProvider,
        _categoryProvider = categoryProvider;

  List<FinancialInsight> get insights => List.unmodifiable(_insights);
  List<FinancialInsight> get activeInsights =>
      _insights.where((i) => !i.isExecuted).toList();

  void _log(String message) {
    if (kDebugMode) print('[$_tag] $message');
  }

  void _logError(String message, dynamic e, StackTrace? st) {
    if (kDebugMode) print('[$_tag ERROR] $message\n$e\n$st');
  }

  @override
  Future<List<FinancialInsight>> generateFinancialInsights(
      {bool forceRefresh = false}) async {
    try {
      if (!forceRefresh && _lastAnalysisTime != null) {
        final hours = DateTime.now().difference(_lastAnalysisTime!).inHours;
        if (hours < 6 && _insights.isNotEmpty) return activeInsights;
      }

      _insights.clear();

      final totalBalance = _balanceProvider.totalBalance;
      final recentTransactions = _listProvider.transactions
          .where((t) => t.transactionType != TransactionType.investment)
          .take(30)
          .toList();

      if (totalBalance <= 0) {
        _insights.add(FinancialInsight(
          id: 'rb_low_balance',
          title: 'Low or negative balance',
          description:
              'Your account balance is zero or negative. Review recent expenses and consider reducing non-essential spending.',
          category: 'alert',
          type: InsightType.alert,
          priority: InsightPriority.high,
          actionData: {'action': 'notify'},
          createdAt: DateTime.now(),
        ));
      }

      final counts = <String, int>{};
      for (final t in recentTransactions) {
        final cat = t.category.toString();
        counts[cat] = (counts[cat] ?? 0) + 1;
      }

      for (final e in counts.entries) {
        final cat = e.key;
        final c = e.value;
        final hasBudget = _budgetProvider.budgets
            .any((b) => b.category.toLowerCase() == cat.toLowerCase());
        if (!hasBudget && c >= 3) {
          _insights.add(FinancialInsight(
            id: 'rb_create_budget_$cat',
            title: 'Consider a budget for $cat',
            description:
                'You had $c recent transactions in $cat. Creating a budget may help you control spending.',
            category: cat,
            type: InsightType.budget,
            priority: InsightPriority.medium,
            actionData: {
              'action': 'create_budget',
              'parameters': {'category': cat, 'amount': 100.0}
            },
            recommendedAmount: 100.0,
            targetCategory: cat,
            createdAt: DateTime.now(),
            isActionable: true,
          ));
        }
      }

      if (totalBalance > 1000 && _investmentProvider.investments.length <= 1) {
        _insights.add(FinancialInsight(
          id: 'rb_start_investment',
          title: 'Small recurring investment suggestion',
          description:
              'You have a healthy balance. Consider starting a small recurring investment to grow savings over time.',
          category: 'investments',
          type: InsightType.investment,
          priority: InsightPriority.medium,
          actionData: {
            'action': 'add_investment',
            'parameters': {
              'name': 'Starter Fund',
              'amount': (totalBalance * 0.05)
            }
          },
          recommendedAmount: (totalBalance * 0.05),
          createdAt: DateTime.now(),
          isActionable: true,
        ));
      }

      final savingsCount = _investmentProvider.investments
          .where((i) => i.category.toLowerCase().contains('saving'))
          .length;
      if (totalBalance > 300 && savingsCount == 0) {
        _insights.add(FinancialInsight(
          id: 'rb_create_savings',
          title: 'Start an emergency savings',
          description:
              'A small emergency savings protects you from unexpected costs. Consider setting aside a small fund.',
          category: 'savings',
          type: InsightType.savings,
          priority: InsightPriority.medium,
          actionData: {
            'action': 'create_savings',
            'parameters': {'name': 'Emergency Savings', 'amount': 200.0}
          },
          recommendedAmount: 200.0,
          createdAt: DateTime.now(),
          isActionable: true,
        ));
      }

      _lastAnalysisTime = DateTime.now();
      return activeInsights;
    } catch (e, st) {
      _logError('Rule-based analysis failed', e, st);
      return activeInsights;
    }
  }

  @override
  Future<bool> executeInsightAction(String insightId,
      {String? customName, double? customAmount}) async {
    try {
      final idx = _insights.indexWhere((i) => i.id == insightId);
      if (idx == -1) return false;

      final insight = _insights[idx];
      switch (insight.type) {
        case InsightType.budget:
          final target = insight.targetCategory ?? insight.category;
          final amount = customAmount ?? insight.recommendedAmount ?? 100.0;
          await _budgetProvider.createOrUpdateBudget(target, amount);
          break;
        case InsightType.investment:
          final name = customName ??
              ((insight.actionData['parameters'] ?? {})['name'] ??
                  'Investment');
          final amount = customAmount ?? insight.recommendedAmount ?? 50.0;
          await _investmentProvider.addInvestment(name, amount);
          break;
        case InsightType.savings:
          final name = customName ?? 'Auto-savings';
          final amount = customAmount ?? insight.recommendedAmount ?? 100.0;
          await _investmentProvider.addInvestment(name, amount,
              category: 'Savings');
          break;
        default:
          break;
      }

      _insights[idx] =
          _insights[idx].copyWith(isExecuted: true, executedAt: DateTime.now());
      await generateFinancialInsights(forceRefresh: true);
      return true;
    } catch (e, st) {
      _logError('Failed execute rule-based action', e, st);
      return false;
    }
  }

  @override
  void dismissInsight(String insightId) {
    final idx = _insights.indexWhere((i) => i.id == insightId);
    if (idx != -1) {
      _insights[idx] =
          _insights[idx].copyWith(isExecuted: true, executedAt: DateTime.now());
    }
  }

  @override
  Future<String> suggestCategory(String description, double amount) async {
    try {
      final lower = description.toLowerCase();
      final categories =
          _categoryProvider.categories.map((c) => c.name).toList();

      for (final cat in categories) {
        final cLower = cat.toLowerCase();
        if (lower.contains(cLower) || cLower.contains(lower)) return cat;
      }

      if (lower.contains('coffee') || lower.contains('food')) return 'Food';
      if (lower.contains('rent') || lower.contains('mortgage'))
        return 'Housing';
      if (amount >= 100 && lower.contains('grocery')) return 'Groceries';

      return 'Others';
    } catch (e, st) {
      _logError('Failed to suggest category (rule-based)', e, st);
      return 'Others';
    }
  }

  @override
  Future<Map<String, dynamic>> getSpendingRecommendations() async {
    try {
      final totalBalance = _balanceProvider.totalBalance;
      final daily = (totalBalance / 30).clamp(0, double.infinity);

      return {
        'dailyBudget': daily * 0.5,
        'weeklyBudget': daily * 7 * 0.6,
        'monthlyBudget': totalBalance * 0.2,
        'categoryLimits': {},
        'savingsGoal': (totalBalance * 0.05).clamp(0, 10000),
        'investmentRecommendation': (totalBalance * 0.05).clamp(0, 10000),
      };
    } catch (e, st) {
      _logError('Failed compute spending recs (rule)', e, st);
      return {};
    }
  }

  @override
  Future<bool> optimizeBudgets() async {
    try {
      final recs = await getSpendingRecommendations();
      final monthly = (recs['monthlyBudget'] as num?)?.toDouble() ?? 0.0;
      if (_budgetProvider.budgets.isEmpty) {
        await _budgetProvider.createOrUpdateBudget('General', monthly);
      }
      return true;
    } catch (e, st) {
      _logError('Failed to optimize budgets (rule-based)', e, st);
      return false;
    }
  }
}

class AIScheduler {
  static Timer? _timer;

  static void startPeriodicAnalysis(dynamic provider) {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(hours: 6), (timer) {
      try {
        provider.autoRefreshIfNeeded();
      } catch (_) {}
    });
  }

  static void stop() {
    _timer?.cancel();
  }
}
