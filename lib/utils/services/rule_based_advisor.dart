import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';

import 'package:wallone/state/balance_provider.dart';
import 'package:wallone/state/investment_provider.dart';
import 'package:wallone/state/budget_provider.dart';
import 'package:wallone/state/list_provider.dart';
import 'package:wallone/state/category_provider.dart';

import 'package:wallone/models/financial_insight.dart';
export 'package:wallone/models/financial_insight.dart';

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

/// Enhanced financial flow analyzer
class FinancialFlow {
  final double totalIncome;
  final double totalExpenses;
  final double totalInvestments;
  final double totalSavings;
  final double netCashFlow;
  final Map<String, double> incomeByCategory;
  final Map<String, double> expensesByCategory;
  final Map<String, double> investmentsByCategory;
  final Map<String, double> savingsByCategory;
  final DateTime periodStart;
  final DateTime periodEnd;

  FinancialFlow({
    required this.totalIncome,
    required this.totalExpenses,
    required this.totalInvestments,
    required this.totalSavings,
    required this.netCashFlow,
    required this.incomeByCategory,
    required this.expensesByCategory,
    required this.investmentsByCategory,
    required this.savingsByCategory,
    required this.periodStart,
    required this.periodEnd,
  });

  double get savingsRate =>
      totalIncome > 0 ? (totalSavings + totalInvestments) / totalIncome : 0.0;

  double get expenseRatio =>
      totalIncome > 0 ? totalExpenses / totalIncome : 1.0;

  double get investmentRate =>
      totalIncome > 0 ? totalInvestments / totalIncome : 0.0;

  bool get isHealthy => netCashFlow > 0 && savingsRate >= 0.10;
}

/// Enhanced spending pattern detector
class SpendingPattern {
  final String category;
  final TransactionType transactionType;
  final double avgAmount;
  final double totalAmount;
  final int transactionCount;
  final DateTime firstSeen;
  final DateTime lastSeen;
  final List<double> amounts;
  final double trend;
  final bool isRecurring;
  final int? dayOfMonth;

  SpendingPattern({
    required this.category,
    required this.transactionType,
    required this.avgAmount,
    required this.totalAmount,
    required this.transactionCount,
    required this.firstSeen,
    required this.lastSeen,
    required this.amounts,
    required this.trend,
    required this.isRecurring,
    this.dayOfMonth,
  });

  double get volatility {
    if (amounts.length < 2) return 0.0;
    final mean = avgAmount;
    final variance =
        amounts.fold<double>(0.0, (sum, amt) => sum + math.pow(amt - mean, 2)) /
            amounts.length;
    return math.sqrt(variance);
  }

  bool get isExpense => transactionType == TransactionType.expense;
  bool get isIncome => transactionType == TransactionType.income;
  bool get isInvestment => transactionType == TransactionType.investment;
  bool get isSavings => category.toLowerCase().contains('saving');
}

/// Enhanced rule-based advisor with comprehensive financial intelligence
///
/// Key Improvements:
/// - Distinguishes between income, expenses, investments, and savings
/// - Tracks cash flow and net worth trends
/// - Provides income-based recommendations
/// - Analyzes financial health holistically
/// - Smart budget optimization based on income vs expenses
/// - Savings and investment recommendations based on income
/// - Predictive analytics with income consideration
class RuleBasedAdvisor implements FinancialAdvisor {
  final BalanceProvider _balanceProvider;
  final InvestmentProvider _investmentProvider;
  final BudgetProvider _budgetProvider;
  final ListProvider _listProvider;
  final CategoryProvider _categoryProvider;

  final List<FinancialInsight> _insights = [];
  DateTime? _lastAnalysisTime;
  Map<String, SpendingPattern> _spendingPatterns = {};
  FinancialFlow? _currentFlow;

  static const String _tag = 'EnhancedRuleBasedAdvisor';
  static const int _maxTotalInsights = 5; // Maximum total insights

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

  @override
  List<FinancialInsight> get insights => List.unmodifiable(_insights);

  @override
  List<FinancialInsight> get activeInsights =>
      _insights.where((i) => !i.isExecuted).toList();

  void _logError(String message, dynamic e, StackTrace? st) {
    if (kDebugMode) print('[$_tag ERROR] $message\n$e\n$st');
  }

  void _log(String message) {
    if (kDebugMode) print('[$_tag] $message');
  }

  // Helper method to get enum name
  String _getTransactionTypeName(TransactionType type) {
    return type.toString().split('.').last;
  }

  /// Analyze complete financial flow (income, expenses, investments, savings)
  FinancialFlow _analyzeFinancialFlow(List<dynamic> transactions) {
    final now = DateTime.now();
    final thirtyDaysAgo = now.subtract(const Duration(days: 30));

    double totalIncome = 0.0;
    double totalExpenses = 0.0;
    double totalInvestments = 0.0;
    double totalSavings = 0.0;

    final incomeByCategory = <String, double>{};
    final expensesByCategory = <String, double>{};
    final investmentsByCategory = <String, double>{};
    final savingsByCategory = <String, double>{};

    for (final t in transactions) {
      final transactionDate = DateTime.tryParse(t.date);
      if (transactionDate == null || transactionDate.isBefore(thirtyDaysAgo)) {
        continue;
      }

      final amount = t.amount.toDouble().abs();
      final category = t.category.toString();

      switch (t.transactionType) {
        case TransactionType.income:
          totalIncome += amount;
          incomeByCategory[category] =
              (incomeByCategory[category] ?? 0.0) + amount;
          break;

        case TransactionType.expense:
          totalExpenses += amount;
          expensesByCategory[category] =
              (expensesByCategory[category] ?? 0.0) + amount;
          break;

        case TransactionType.investment:
          totalInvestments += amount;
          investmentsByCategory[category] =
              (investmentsByCategory[category] ?? 0.0) + amount;
          break;
      }

      // Identify savings (could be in expense or investment categories)
      if (category.toLowerCase().contains('saving') ||
          category.toLowerCase().contains('emergency')) {
        totalSavings += amount;
        savingsByCategory[category] =
            (savingsByCategory[category] ?? 0.0) + amount;
      }
    }

    final netCashFlow = totalIncome - totalExpenses - totalInvestments;

    return FinancialFlow(
      totalIncome: totalIncome,
      totalExpenses: totalExpenses,
      totalInvestments: totalInvestments,
      totalSavings: totalSavings,
      netCashFlow: netCashFlow,
      incomeByCategory: incomeByCategory,
      expensesByCategory: expensesByCategory,
      investmentsByCategory: investmentsByCategory,
      savingsByCategory: savingsByCategory,
      periodStart: thirtyDaysAgo,
      periodEnd: now,
    );
  }

  /// Analyze spending patterns with transaction type awareness
  Map<String, SpendingPattern> _analyzeSpendingPatterns(
      List<dynamic> transactions) {
    final patterns = <String, SpendingPattern>{};
    final categoryData = <String, List<Map<String, dynamic>>>{};

    for (final t in transactions) {
      final cat = t.category.toString();
      // Extract enum name from toString() output (e.g., "TransactionType.expense" -> "expense")
      final typeName = _getTransactionTypeName(t.transactionType);
      final key = '${typeName}_$cat';

      categoryData[key] ??= [];
      categoryData[key]!.add({
        'amount': t.amount.toDouble().abs(),
        'date': DateTime.tryParse(t.date) ?? DateTime.now(),
        'type': t.transactionType,
        'category': cat,
      });
    }

    for (final entry in categoryData.entries) {
      final data = entry.value;
      if (data.isEmpty) continue;

      data.sort((a, b) => (a['date'] as DateTime).compareTo(b['date']));

      final amounts = data.map((d) => d['amount'] as double).toList();
      final total = amounts.fold<double>(0.0, (sum, amt) => sum + amt);
      final avg = total / amounts.length;

      double trend = 0.0;
      if (amounts.length >= 3) {
        final n = amounts.length;
        final xValues = List.generate(n, (i) => i.toDouble());
        final xMean = xValues.fold<double>(0.0, (sum, x) => sum + x) / n;
        final yMean = avg;

        double numerator = 0.0;
        double denominator = 0.0;

        for (int i = 0; i < n; i++) {
          numerator += (xValues[i] - xMean) * (amounts[i] - yMean);
          denominator += math.pow(xValues[i] - xMean, 2);
        }

        trend = denominator != 0 ? numerator / denominator : 0.0;
      }

      bool isRecurring = false;
      int? dayOfMonth;

      if (data.length >= 2) {
        final dates = data.map((d) => d['date'] as DateTime).toList();
        final days = dates.map((d) => d.day).toSet();

        if (days.length <= 3 && data.length >= 2) {
          isRecurring = true;
          dayOfMonth = days.first;
        }
      }

      final category = data.first['category'] as String;
      final type = data.first['type'] as TransactionType;

      patterns[entry.key] = SpendingPattern(
        category: category,
        transactionType: type,
        avgAmount: avg,
        totalAmount: total,
        transactionCount: amounts.length,
        firstSeen: data.first['date'],
        lastSeen: data.last['date'],
        amounts: amounts,
        trend: trend,
        isRecurring: isRecurring,
        dayOfMonth: dayOfMonth,
      );
    }

    return patterns;
  }

  /// Calculate comprehensive financial health metrics
  Map<String, double> _calculateHealthMetrics(FinancialFlow flow) {
    final totalBalance = _balanceProvider.totalBalance;
    final totalInvestments = _investmentProvider.investments
        .fold<double>(0.0, (sum, inv) => sum + inv.amount);

    final netWorth = totalBalance + totalInvestments;
    final liquidityRatio =
        flow.totalIncome > 0 ? totalBalance / flow.totalIncome : 0.0;

    final budgetUtilization = _budgetProvider.budgets.isEmpty
        ? 0.0
        : _budgetProvider.budgets.fold<double>(0.0, (sum, b) {
              final spent = flow.expensesByCategory[b.category] ?? 0.0;
              return sum + (b.amount > 0 ? spent / b.amount : 0.0);
            }) /
            _budgetProvider.budgets.length;

    return {
      'totalBalance': totalBalance,
      'netWorth': netWorth,
      'monthlyIncome': flow.totalIncome,
      'monthlyExpenses': flow.totalExpenses,
      'monthlyInvestments': flow.totalInvestments,
      'monthlySavings': flow.totalSavings,
      'netCashFlow': flow.netCashFlow,
      'savingsRate': flow.savingsRate,
      'expenseRatio': flow.expenseRatio,
      'investmentRate': flow.investmentRate,
      'budgetUtilization': budgetUtilization,
      'liquidityRatio': liquidityRatio,
      'debtToIncomeRatio': 0.0, // Could be enhanced with debt tracking
    };
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

      final allTransactions = _listProvider.transactions.take(100).toList();

      // Analyze financial flow and patterns
      _currentFlow = _analyzeFinancialFlow(allTransactions);
      _spendingPatterns = _analyzeSpendingPatterns(allTransactions);
      final healthMetrics = _calculateHealthMetrics(_currentFlow!);

      _log('Financial Flow Analysis:');
      _log('  Income: \$${_currentFlow!.totalIncome.toStringAsFixed(2)}');
      _log('  Expenses: \$${_currentFlow!.totalExpenses.toStringAsFixed(2)}');
      _log(
          '  Investments: \$${_currentFlow!.totalInvestments.toStringAsFixed(2)}');
      _log('  Savings: \$${_currentFlow!.totalSavings.toStringAsFixed(2)}');
      _log(
          '  Net Cash Flow: \$${_currentFlow!.netCashFlow.toStringAsFixed(2)}');

      // 1. Income analysis insights
      await _generateIncomeInsights(_currentFlow!, healthMetrics);

      // 2. Critical balance and cash flow alerts
      await _generateCashFlowAlerts(_currentFlow!, healthMetrics);

      // 3. Expense pattern insights
      await _generateExpenseInsights(
          _spendingPatterns, _currentFlow!, healthMetrics);

      // 4. Budget optimization insights
      await _generateBudgetInsights(
          _spendingPatterns, _currentFlow!, healthMetrics);

      // 5. Savings and investment insights
      await _generateSavingsInsights(_currentFlow!, healthMetrics);

      // 6. Investment-specific insights
      await _generateInvestmentInsights(_currentFlow!, healthMetrics);

      // 7. Predictive insights with income consideration
      await _generatePredictiveInsights(
          _spendingPatterns, _currentFlow!, healthMetrics);

      // 8. Financial health score
      await _generateHealthScoreInsight(healthMetrics);

      _insights.sort((a, b) {
        final priorityOrder = {
          InsightPriority.high: 0,
          InsightPriority.medium: 1,
          InsightPriority.low: 2,
        };
        return priorityOrder[a.priority]!.compareTo(priorityOrder[b.priority]!);
      });

      if (_insights.length > _maxTotalInsights) {
        _insights.removeRange(_maxTotalInsights, _insights.length);
      }

      _lastAnalysisTime = DateTime.now();
      _log(
          'Generated ${_insights.length} insights (${activeInsights.length} active)');
      return activeInsights;
    } catch (e, st) {
      _logError('Enhanced analysis failed', e, st);
      return activeInsights;
    }
  }

  Future<void> _generateIncomeInsights(
      FinancialFlow flow, Map<String, double> metrics) async {
    // No income detected
    if (flow.totalIncome == 0) {
      _insights.add(FinancialInsight(
        id: 'income_none_detected',
        title: 'No Income Tracked',
        description:
            'You haven\'t recorded any income this month. Start tracking your income sources '
            'to get better financial insights and budgeting recommendations.',
        category: 'income',
        type: InsightType.income,
        priority: InsightPriority.high,
        actionData: {'action': 'add_income'},
        createdAt: DateTime.now(),
        isActionable: true,
        confidenceScore: 1.0,
        supportingData: ['No income transactions in the last 30 days'],
      ));
      return;
    }

    // Low income warning
    if (flow.totalIncome < flow.totalExpenses) {
      final deficit = flow.totalExpenses - flow.totalIncome;
      _insights.add(FinancialInsight(
        id: 'income_below_expenses',
        title: 'Income Below Expenses',
        description:
            'Your expenses (\$${flow.totalExpenses.toStringAsFixed(2)}) exceed your income '
            '(\$${flow.totalIncome.toStringAsFixed(2)}) by \$${deficit.toStringAsFixed(2)}. '
            'This is unsustainable. Consider increasing income or reducing expenses.',
        category: 'income',
        type: InsightType.alert,
        priority: InsightPriority.high,
        actionData: {'action': 'review_budget'},
        createdAt: DateTime.now(),
        confidenceScore: 1.0,
        supportingData: [
          'Monthly income: \$${flow.totalIncome.toStringAsFixed(2)}',
          'Monthly expenses: \$${flow.totalExpenses.toStringAsFixed(2)}',
          'Deficit: \$${deficit.toStringAsFixed(2)}'
        ],
      ));
    }

    // Analyze income sources
    if (flow.incomeByCategory.length == 1) {
      _insights.add(FinancialInsight(
        id: 'income_single_source',
        title: 'Single Income Source Detected',
        description:
            'All your income comes from ${flow.incomeByCategory.keys.first}. '
            'Consider diversifying your income sources for better financial security.',
        category: 'income',
        type: InsightType.income,
        priority: InsightPriority.medium,
        actionData: {'action': 'diversify_income'},
        createdAt: DateTime.now(),
        confidenceScore: 0.80,
        supportingData: [
          'Primary income: ${flow.incomeByCategory.keys.first}',
          'Amount: \$${flow.incomeByCategory.values.first.toStringAsFixed(2)}'
        ],
      ));
    }

    // Income stability check
    final incomePattern = _spendingPatterns.values.firstWhere((p) => p.isIncome,
        orElse: () => _spendingPatterns.values.first);

    if (incomePattern.isIncome &&
        incomePattern.volatility > incomePattern.avgAmount * 0.3) {
      _insights.add(FinancialInsight(
        id: 'income_unstable',
        title: 'Irregular Income Detected',
        description:
            'Your income varies significantly month-to-month. Consider building a larger '
            'emergency fund (6 months of expenses vs 3 months for stable income).',
        category: 'income',
        type: InsightType.income,
        priority: InsightPriority.medium,
        actionData: {'action': 'increase_emergency_fund'},
        recommendedAmount: flow.totalExpenses * 6,
        createdAt: DateTime.now(),
        confidenceScore: 0.75,
        supportingData: [
          'Average income: \$${incomePattern.avgAmount.toStringAsFixed(2)}',
          'Income volatility: \$${incomePattern.volatility.toStringAsFixed(2)}'
        ],
      ));
    }
  }

  Future<void> _generateCashFlowAlerts(
      FinancialFlow flow, Map<String, double> metrics) async {
    final balance = metrics['totalBalance'] ?? 0.0;

    // Negative cash flow
    if (flow.netCashFlow < 0) {
      _insights.add(FinancialInsight(
        id: 'alert_negative_cashflow',
        title: 'Negative Cash Flow',
        description:
            'You spent \$${flow.netCashFlow.abs().toStringAsFixed(2)} more than you earned this month. '
            'This is eating into your savings. ${flow.totalIncome > 0 ? "Reduce expenses to below \$${flow.totalIncome.toStringAsFixed(2)}" : "Start tracking income"}.',
        category: 'alert',
        type: InsightType.alert,
        priority: InsightPriority.high,
        actionData: {'action': 'urgent_review'},
        createdAt: DateTime.now(),
        confidenceScore: 1.0,
        supportingData: [
          'Income: \$${flow.totalIncome.toStringAsFixed(2)}',
          'Total outflow: \$${(flow.totalExpenses + flow.totalInvestments).toStringAsFixed(2)}',
          'Net: \$${flow.netCashFlow.toStringAsFixed(2)}'
        ],
      ));
    }

    // Critical balance with negative cash flow
    if (balance <= 0) {
      _insights.add(FinancialInsight(
        id: 'alert_critical_balance',
        title: 'Critical: Account Overdrawn',
        description:
            'Your account is overdrawn. ${flow.totalIncome > 0 ? "Immediate action needed to reduce expenses below your \$${flow.totalIncome.toStringAsFixed(2)} monthly income" : "Consider increasing income or drastically cutting expenses"}.',
        category: 'alert',
        type: InsightType.alert,
        priority: InsightPriority.high,
        actionData: {'action': 'urgent_review'},
        createdAt: DateTime.now(),
        confidenceScore: 1.0,
        supportingData: ['Balance: \$${balance.toStringAsFixed(2)}'],
      ));
    } else if (balance < flow.totalExpenses * 0.5) {
      _insights.add(FinancialInsight(
        id: 'alert_low_balance',
        title: 'Low Balance Warning',
        description:
            'Your balance (\$${balance.toStringAsFixed(2)}) is less than half your monthly expenses. '
            'Build it up to at least \$${(flow.totalExpenses * 1.5).toStringAsFixed(2)} for better security.',
        category: 'alert',
        type: InsightType.alert,
        priority: InsightPriority.high,
        actionData: {'action': 'build_emergency_fund'},
        recommendedAmount: flow.totalExpenses * 1.5,
        createdAt: DateTime.now(),
        confidenceScore: 0.90,
        supportingData: [
          'Current balance: \$${balance.toStringAsFixed(2)}',
          'Monthly expenses: \$${flow.totalExpenses.toStringAsFixed(2)}'
        ],
      ));
    }

    // Expense to income ratio warning
    if (flow.expenseRatio > 0.80 && flow.totalIncome > 0) {
      _insights.add(FinancialInsight(
        id: 'alert_high_expense_ratio',
        title: 'High Expense-to-Income Ratio',
        description:
            'You\'re spending ${(flow.expenseRatio * 100).toStringAsFixed(0)}% of your income on expenses. '
            'Financial experts recommend keeping this below 70%. Reduce expenses by \$${((flow.expenseRatio - 0.70) * flow.totalIncome).toStringAsFixed(2)}.',
        category: 'alert',
        type: InsightType.expense,
        priority: InsightPriority.high,
        actionData: {'action': 'reduce_spending'},
        recommendedAmount: (flow.expenseRatio - 0.70) * flow.totalIncome,
        createdAt: DateTime.now(),
        confidenceScore: 0.85,
        supportingData: [
          'Income: \$${flow.totalIncome.toStringAsFixed(2)}',
          'Expenses: \$${flow.totalExpenses.toStringAsFixed(2)}',
          'Ratio: ${(flow.expenseRatio * 100).toStringAsFixed(1)}%'
        ],
      ));
    }
  }

  Future<void> _generateExpenseInsights(Map<String, SpendingPattern> patterns,
      FinancialFlow flow, Map<String, double> metrics) async {
    final expensePatterns = patterns.values.where((p) => p.isExpense).toList();

    for (final pattern in expensePatterns) {
      // Detect increasing expense trends
      if (pattern.trend > 5 && pattern.transactionCount >= 5) {
        final percentOfIncome = flow.totalIncome > 0
            ? (pattern.totalAmount / flow.totalIncome * 100)
            : 0.0;

        _insights.add(FinancialInsight(
          id: 'expense_trend_increasing_${pattern.category}',
          title: '${pattern.category} Expenses Increasing',
          description:
              'Your ${pattern.category} expenses are trending upward (+\$${pattern.trend.toStringAsFixed(2)} per transaction). '
              'This category is ${percentOfIncome.toStringAsFixed(1)}% of your income. '
              'Average: \$${pattern.avgAmount.toStringAsFixed(2)}. Consider setting a budget.',
          category: pattern.category,
          type: InsightType.expense,
          priority: percentOfIncome > 20
              ? InsightPriority.high
              : InsightPriority.medium,
          actionData: {
            'action': 'create_budget',
            'parameters': {
              'category': pattern.category,
              'amount': pattern.avgAmount * 1.2,
            }
          },
          recommendedAmount: pattern.avgAmount * 1.2,
          targetCategory: pattern.category,
          createdAt: DateTime.now(),
          isActionable: true,
          confidenceScore: 0.75,
          supportingData: [
            '${pattern.transactionCount} transactions',
            'Trend: +\$${pattern.trend.toStringAsFixed(2)}/transaction',
            'Total: \$${pattern.totalAmount.toStringAsFixed(2)}',
            '${percentOfIncome.toStringAsFixed(1)}% of income'
          ],
        ));
      }

      // High-cost categories
      if (flow.totalIncome > 0 &&
          pattern.totalAmount > flow.totalIncome * 0.25) {
        _insights.add(FinancialInsight(
          id: 'expense_high_category_${pattern.category}',
          title: '${pattern.category} is a Major Expense',
          description:
              '${pattern.category} accounts for \$${pattern.totalAmount.toStringAsFixed(2)} '
              '(${(pattern.totalAmount / flow.totalIncome * 100).toStringAsFixed(1)}% of income). '
              'Look for ways to optimize this category.',
          category: pattern.category,
          type: InsightType.expense,
          priority: InsightPriority.high,
          actionData: {'action': 'review_category'},
          createdAt: DateTime.now(),
          confidenceScore: 1.0,
          supportingData: [
            'Total spent: \$${pattern.totalAmount.toStringAsFixed(2)}',
            'Percentage of income: ${(pattern.totalAmount / flow.totalIncome * 100).toStringAsFixed(1)}%',
            '${pattern.transactionCount} transactions'
          ],
        ));
      }
    }

    // Check for missing expense categories (common ones that aren't tracked)
    final trackedCategories =
        expensePatterns.map((p) => p.category.toLowerCase()).toSet();
    final commonCategories = [
      'housing',
      'food',
      'transportation',
      'utilities',
      'insurance'
    ];

    for (final category in commonCategories) {
      if (!trackedCategories.any((c) => c.contains(category))) {
        _insights.add(FinancialInsight(
          id: 'expense_missing_category_$category',
          title: 'Missing ${category.capitalize()} Expenses?',
          description:
              'You haven\'t tracked any $category expenses. If you have these costs, '
              'make sure to categorize them properly for accurate budgeting.',
          category: category,
          type: InsightType.expense,
          priority: InsightPriority.low,
          actionData: {'action': 'verify_categories'},
          createdAt: DateTime.now(),
          confidenceScore: 0.60,
          supportingData: ['Common expense category not found in records'],
        ));
      }
    }
  }

  Future<void> _generateBudgetInsights(Map<String, SpendingPattern> patterns,
      FinancialFlow flow, Map<String, double> metrics) async {
    final expensePatterns = patterns.values.where((p) => p.isExpense).toList();

    // Suggest budgets for categories without them
    for (final pattern in expensePatterns) {
      final hasBudget = _budgetProvider.budgets.any(
          (b) => b.category.toLowerCase() == pattern.category.toLowerCase());

      if (!hasBudget && pattern.transactionCount >= 5) {
        // Base budget on income percentage rather than just average
        final recommendedBudget = flow.totalIncome > 0
            ? math.min(pattern.avgAmount * 1.15, flow.totalIncome * 0.30)
            : pattern.avgAmount * 1.15;

        _insights.add(FinancialInsight(
          id: 'budget_create_${pattern.category}',
          title: 'Create Budget for ${pattern.category}',
          description:
              'You have ${pattern.transactionCount} ${pattern.category} expenses '
              '(avg: \$${pattern.avgAmount.toStringAsFixed(2)}). '
              'A budget of \$${recommendedBudget.toStringAsFixed(2)} would help control spending.',
          category: pattern.category,
          type: InsightType.budget,
          priority: pattern.totalAmount > flow.totalIncome * 0.15
              ? InsightPriority.high
              : InsightPriority.medium,
          actionData: {
            'action': 'create_budget',
            'parameters': {
              'category': pattern.category,
              'amount': recommendedBudget,
            }
          },
          recommendedAmount: recommendedBudget,
          targetCategory: pattern.category,
          createdAt: DateTime.now(),
          isActionable: true,
          confidenceScore: 0.80,
          supportingData: [
            '${pattern.transactionCount} recent transactions',
            'Total: \$${pattern.totalAmount.toStringAsFixed(2)}',
            pattern.isRecurring ? 'Recurring expense' : 'Variable expense',
          ],
        ));
      }
    }

    // 50/30/20 rule recommendations
    if (flow.totalIncome > 0 && _budgetProvider.budgets.isEmpty) {
      final needs = flow.totalIncome * 0.50;
      final wants = flow.totalIncome * 0.30;
      final savings = flow.totalIncome * 0.20;

      _insights.add(FinancialInsight(
        id: 'budget_50_30_20_rule',
        title: 'Try the 50/30/20 Budgeting Rule',
        description:
            'Based on your \$${flow.totalIncome.toStringAsFixed(2)} income, allocate: '
            '\$${needs.toStringAsFixed(2)} (50%) for needs, '
            '\$${wants.toStringAsFixed(2)} (30%) for wants, '
            '\$${savings.toStringAsFixed(2)} (20%) for savings.',
        category: 'budget',
        type: InsightType.budget,
        priority: InsightPriority.high,
        actionData: {
          'action': 'apply_50_30_20',
          'parameters': {
            'needs': needs,
            'wants': wants,
            'savings': savings,
          }
        },
        createdAt: DateTime.now(),
        isActionable: true,
        confidenceScore: 0.90,
        supportingData: [
          'Monthly income: \$${flow.totalIncome.toStringAsFixed(2)}',
          'Needs budget: \$${needs.toStringAsFixed(2)}',
          'Wants budget: \$${wants.toStringAsFixed(2)}',
          'Savings goal: \$${savings.toStringAsFixed(2)}'
        ],
      ));
    }

    // Check existing budgets against income
    for (final budget in _budgetProvider.budgets) {
      if (flow.totalIncome > 0 && budget.amount > flow.totalIncome * 0.40) {
        _insights.add(FinancialInsight(
          id: 'budget_too_high_${budget.category}',
          title: '${budget.category} Budget Too High',
          description:
              'Your ${budget.category} budget (\$${budget.amount.toStringAsFixed(2)}) '
              'is ${(budget.amount / flow.totalIncome * 100).toStringAsFixed(0)}% of your income. '
              'Consider reducing to 30-35% max.',
          category: budget.category,
          type: InsightType.budget,
          priority: InsightPriority.medium,
          actionData: {
            'action': 'adjust_budget',
            'parameters': {
              'category': budget.category,
              'amount': flow.totalIncome * 0.35,
            }
          },
          recommendedAmount: flow.totalIncome * 0.35,
          targetCategory: budget.category,
          createdAt: DateTime.now(),
          isActionable: true,
          confidenceScore: 0.75,
          supportingData: [
            'Current budget: \$${budget.amount.toStringAsFixed(2)}',
            'Monthly income: \$${flow.totalIncome.toStringAsFixed(2)}',
            'Percentage: ${(budget.amount / flow.totalIncome * 100).toStringAsFixed(0)}%'
          ],
        ));
      }
    }
  }

  Future<void> _generateSavingsInsights(
      FinancialFlow flow, Map<String, double> metrics) async {
    final totalSavings = flow.totalSavings;

    // No savings
    if (totalSavings == 0 && flow.netCashFlow > 0) {
      final recommendedSavings = flow.totalIncome > 0
          ? flow.totalIncome * 0.20
          : flow.netCashFlow * 0.50;

      _insights.add(FinancialInsight(
        id: 'savings_start_emergency',
        title: 'Start Building Emergency Savings',
        description:
            'You have positive cash flow but no savings. Start saving \$${recommendedSavings.toStringAsFixed(2)} '
            '(20% of income) monthly to build a 3-6 month emergency fund.',
        category: 'savings',
        type: InsightType.savings,
        priority: InsightPriority.high,
        actionData: {
          'action': 'create_savings',
          'parameters': {
            'name': 'Emergency Fund',
            'amount': recommendedSavings,
          }
        },
        recommendedAmount: recommendedSavings,
        createdAt: DateTime.now(),
        isActionable: true,
        confidenceScore: 0.90,
        supportingData: [
          'Monthly income: \$${flow.totalIncome.toStringAsFixed(2)}',
          'Net cash flow: \$${flow.netCashFlow.toStringAsFixed(2)}',
          'Recommended monthly savings: \$${recommendedSavings.toStringAsFixed(2)}'
        ],
      ));
    }

    // Low savings rate
    if (flow.savingsRate < 0.15 &&
        flow.totalIncome > 0 &&
        flow.netCashFlow > 0) {
      final targetSavings = flow.totalIncome * 0.20;
      final additionalSavings = targetSavings - totalSavings;

      _insights.add(FinancialInsight(
        id: 'savings_increase_rate',
        title: 'Increase Savings Rate',
        description:
            'Your savings rate is ${(flow.savingsRate * 100).toStringAsFixed(1)}%. '
            'Aim for 20% (\$${targetSavings.toStringAsFixed(2)}/month). '
            'Save an additional \$${additionalSavings.toStringAsFixed(2)}.',
        category: 'savings',
        type: InsightType.savings,
        priority: InsightPriority.medium,
        actionData: {
          'action': 'increase_savings',
          'parameters': {
            'amount': additionalSavings,
          }
        },
        recommendedAmount: additionalSavings,
        createdAt: DateTime.now(),
        isActionable: true,
        confidenceScore: 0.80,
        supportingData: [
          'Current savings rate: ${(flow.savingsRate * 100).toStringAsFixed(1)}%',
          'Target rate: 20%',
          'Current savings: \$${totalSavings.toStringAsFixed(2)}',
          'Target savings: \$${targetSavings.toStringAsFixed(2)}'
        ],
      ));
    }

    // Emergency fund adequacy
    if (totalSavings < flow.totalExpenses * 3 && flow.totalExpenses > 0) {
      final targetEmergency = flow.totalExpenses * 3;
      final needed = targetEmergency - totalSavings;

      _insights.add(FinancialInsight(
        id: 'savings_emergency_inadequate',
        title: 'Build Larger Emergency Fund',
        description: 'Your emergency fund should cover 3-6 months of expenses. '
            'Current savings: \$${totalSavings.toStringAsFixed(2)}. '
            'Target: \$${targetEmergency.toStringAsFixed(2)}. '
            'You need \$${needed.toStringAsFixed(2)} more.',
        category: 'savings',
        type: InsightType.savings,
        priority: InsightPriority.high,
        actionData: {
          'action': 'build_emergency_fund',
          'parameters': {
            'target': targetEmergency,
          }
        },
        recommendedAmount: needed,
        createdAt: DateTime.now(),
        isActionable: true,
        confidenceScore: 0.85,
        supportingData: [
          'Current savings: \$${totalSavings.toStringAsFixed(2)}',
          'Monthly expenses: \$${flow.totalExpenses.toStringAsFixed(2)}',
          '3-month target: \$${targetEmergency.toStringAsFixed(2)}',
          'Shortfall: \$${needed.toStringAsFixed(2)}'
        ],
      ));
    }
  }

  Future<void> _generateInvestmentInsights(
      FinancialFlow flow, Map<String, double> metrics) async {
    final totalInvestments = flow.totalInvestments;

    // No investments but good income
    if (totalInvestments == 0 &&
        flow.totalIncome > 2000 &&
        flow.netCashFlow > 500 &&
        flow.totalSavings >= flow.totalExpenses * 3) {
      final investmentAmount = flow.netCashFlow * 0.30;

      _insights.add(FinancialInsight(
        id: 'investment_start',
        title: 'Consider Starting Investments',
        description:
            'You have a healthy emergency fund and positive cash flow. '
            'Consider investing \$${investmentAmount.toStringAsFixed(2)} (30% of surplus) '
            'for long-term wealth building.',
        category: 'investments',
        type: InsightType.investment,
        priority: InsightPriority.medium,
        actionData: {
          'action': 'add_investment',
          'parameters': {
            'name': 'Growth Fund',
            'amount': investmentAmount,
          }
        },
        recommendedAmount: investmentAmount,
        createdAt: DateTime.now(),
        isActionable: true,
        confidenceScore: 0.75,
        supportingData: [
          'Monthly income: \$${flow.totalIncome.toStringAsFixed(2)}',
          'Net cash flow: \$${flow.netCashFlow.toStringAsFixed(2)}',
          'Emergency fund: \$${flow.totalSavings.toStringAsFixed(2)}',
          'Recommended investment: \$${investmentAmount.toStringAsFixed(2)}'
        ],
      ));
    }

    // Low investment rate
    if (flow.investmentRate < 0.10 &&
        flow.totalIncome > 0 &&
        flow.netCashFlow > 0 &&
        flow.totalSavings >= flow.totalExpenses * 2) {
      final targetInvestment = flow.totalIncome * 0.15;
      final additionalInvestment = targetInvestment - totalInvestments;

      _insights.add(FinancialInsight(
        id: 'investment_increase_rate',
        title: 'Increase Investment Rate',
        description:
            'Your investment rate is ${(flow.investmentRate * 100).toStringAsFixed(1)}%. '
            'With stable savings, aim for 10-15% of income. '
            'Consider investing an additional \$${additionalInvestment.toStringAsFixed(2)}.',
        category: 'investments',
        type: InsightType.investment,
        priority: InsightPriority.medium,
        actionData: {
          'action': 'increase_investments',
          'parameters': {
            'amount': additionalInvestment,
          }
        },
        recommendedAmount: additionalInvestment,
        createdAt: DateTime.now(),
        isActionable: true,
        confidenceScore: 0.70,
        supportingData: [
          'Current investment rate: ${(flow.investmentRate * 100).toStringAsFixed(1)}%',
          'Target rate: 15%',
          'Monthly income: \$${flow.totalIncome.toStringAsFixed(2)}',
          'Additional investment: \$${additionalInvestment.toStringAsFixed(2)}'
        ],
      ));
    }

    // Warning: Investing without emergency fund
    if (totalInvestments > 0 &&
        flow.totalSavings < flow.totalExpenses * 2 &&
        flow.totalExpenses > 0) {
      _insights.add(FinancialInsight(
        id: 'investment_before_emergency',
        title: 'Prioritize Emergency Fund First',
        description: 'You\'re investing but your emergency fund is inadequate. '
            'Consider redirecting some investments to savings until you have '
            '3-6 months of expenses saved (\$${(flow.totalExpenses * 3).toStringAsFixed(2)}).',
        category: 'investments',
        type: InsightType.alert,
        priority: InsightPriority.high,
        actionData: {
          'action': 'rebalance_priorities',
        },
        createdAt: DateTime.now(),
        confidenceScore: 0.85,
        supportingData: [
          'Current savings: \$${flow.totalSavings.toStringAsFixed(2)}',
          'Current investments: \$${totalInvestments.toStringAsFixed(2)}',
          'Target emergency fund: \$${(flow.totalExpenses * 3).toStringAsFixed(2)}'
        ],
      ));
    }
  }

  Future<void> _generatePredictiveInsights(
      Map<String, SpendingPattern> patterns,
      FinancialFlow flow,
      Map<String, double> metrics) async {
    final balance = metrics['totalBalance'] ?? 0.0;

    // Predict next month's cash flow
    double projectedIncome = 0.0;
    double projectedExpenses = 0.0;
    double projectedInvestments = 0.0;

    for (final pattern in patterns.values) {
      if (pattern.isIncome) {
        projectedIncome += pattern.avgAmount + (pattern.trend * 0.5);
      } else if (pattern.isExpense) {
        if (pattern.isRecurring) {
          projectedExpenses += pattern.avgAmount;
        } else {
          final avgMonthlyTxns = pattern.transactionCount /
              math.max(1,
                  pattern.lastSeen.difference(pattern.firstSeen).inDays / 30);
          projectedExpenses +=
              (pattern.avgAmount + pattern.trend) * avgMonthlyTxns;
        }
      } else if (pattern.isInvestment) {
        if (pattern.isRecurring) {
          projectedInvestments += pattern.avgAmount;
        }
      }
    }

    final projectedCashFlow =
        projectedIncome - projectedExpenses - projectedInvestments;
    final projectedBalance = balance + projectedCashFlow;

    if (projectedBalance < 0 && balance > 0) {
      _insights.add(FinancialInsight(
        id: 'predict_negative_balance',
        title: 'Warning: Projected Negative Balance',
        description:
            'Based on current trends, your balance may go negative next month. '
            'Projected income: \$${projectedIncome.toStringAsFixed(2)}, '
            'expenses: \$${projectedExpenses.toStringAsFixed(2)}. '
            'Reduce expenses by \$${(projectedExpenses * 0.15).toStringAsFixed(2)} or increase income.',
        category: 'alert',
        type: InsightType.alert,
        priority: InsightPriority.high,
        actionData: {'action': 'urgent_budget_review'},
        recommendedAmount: projectedExpenses * 0.15,
        createdAt: DateTime.now(),
        confidenceScore: 0.70,
        supportingData: [
          'Current balance: \$${balance.toStringAsFixed(2)}',
          'Projected income: \$${projectedIncome.toStringAsFixed(2)}',
          'Projected expenses: \$${projectedExpenses.toStringAsFixed(2)}',
          'Projected balance: \$${projectedBalance.toStringAsFixed(2)}'
        ],
      ));
    } else if (projectedCashFlow > 0 && flow.netCashFlow > 0) {
      _insights.add(FinancialInsight(
        id: 'predict_positive_surplus',
        title: 'Projected Surplus Next Month',
        description:
            'Great news! You\'re on track for a \$${projectedCashFlow.toStringAsFixed(2)} surplus next month. '
            'Consider allocating ${projectedCashFlow > 200 ? "50%" : "it"} to savings or investments.',
        category: 'savings',
        type: InsightType.savings,
        priority: InsightPriority.low,
        actionData: {'action': 'plan_surplus'},
        recommendedAmount: projectedCashFlow * 0.50,
        createdAt: DateTime.now(),
        confidenceScore: 0.65,
        supportingData: [
          'Projected surplus: \$${projectedCashFlow.toStringAsFixed(2)}',
          'Suggested savings: \$${(projectedCashFlow * 0.50).toStringAsFixed(2)}'
        ],
      ));
    }

    // Predict year-end net worth
    if (flow.netCashFlow != 0) {
      const monthsRemaining = 12;
      final projectedYearEndBalance =
          balance + (flow.netCashFlow * monthsRemaining);
      final currentInvestments = _investmentProvider.investments
          .fold<double>(0.0, (sum, inv) => sum + inv.amount);
      final projectedNetWorth = projectedYearEndBalance + currentInvestments;

      if (projectedNetWorth > balance + currentInvestments) {
        _insights.add(FinancialInsight(
          id: 'predict_net_worth_growth',
          title: 'Positive Net Worth Trajectory',
          description: 'At current rates, your net worth could grow from '
              '\$${(balance + currentInvestments).toStringAsFixed(2)} to '
              '\$${projectedNetWorth.toStringAsFixed(2)} by year end. '
              'Keep up the good work!',
          category: 'general',
          type: InsightType.general,
          priority: InsightPriority.low,
          actionData: {'action': 'continue_plan'},
          createdAt: DateTime.now(),
          confidenceScore: 0.60,
          supportingData: [
            'Current net worth: \$${(balance + currentInvestments).toStringAsFixed(2)}',
            'Monthly cash flow: \$${flow.netCashFlow.toStringAsFixed(2)}',
            'Projected year-end: \$${projectedNetWorth.toStringAsFixed(2)}'
          ],
        ));
      }
    }
  }

  Future<void> _generateHealthScoreInsight(Map<String, double> metrics) async {
    // Calculate overall financial health score (0-100)
    double score = 50.0; // Start at neutral

    final balance = metrics['totalBalance'] ?? 0.0;
    final income = metrics['monthlyIncome'] ?? 0.0;
    final expenses = metrics['monthlyExpenses'] ?? 0.0;
    final savingsRate = metrics['savingsRate'] ?? 0.0;
    final netCashFlow = metrics['netCashFlow'] ?? 0.0;

    // Positive indicators
    if (balance > 0) score += 10;
    if (balance > expenses * 3) score += 10;
    if (netCashFlow > 0) score += 15;
    if (savingsRate >= 0.20) {
      score += 15;
    } else if (savingsRate >= 0.10) {
      score += 10;
    }
    if (income > expenses) score += 10;

    // Negative indicators
    if (balance < 0) score -= 30;
    if (netCashFlow < 0) score -= 20;
    if (savingsRate == 0) score -= 10;
    if (expenses > income) score -= 15;

    score = score.clamp(0.0, 100.0);

    String healthLevel;
    InsightPriority priority;
    String description;

    if (score >= 80) {
      healthLevel = 'Excellent';
      priority = InsightPriority.low;
      description =
          'Your financial health is excellent! You have positive cash flow, '
          'good savings, and controlled expenses. Consider optimizing investments for growth.';
    } else if (score >= 60) {
      healthLevel = 'Good';
      priority = InsightPriority.low;
      description =
          'Your financial health is good. Focus on increasing your savings rate '
          'to 20% and building a 6-month emergency fund.';
    } else if (score >= 40) {
      healthLevel = 'Fair';
      priority = InsightPriority.medium;
      description =
          'Your financial health needs improvement. Focus on creating budgets, '
          'reducing expenses, and building emergency savings.';
    } else {
      healthLevel = 'Needs Attention';
      priority = InsightPriority.high;
      description =
          'Your financial health requires immediate attention. Prioritize: '
          '1) Increase income or reduce expenses to positive cash flow, '
          '2) Build emergency savings, 3) Create and stick to budgets.';
    }

    _insights.add(FinancialInsight(
      id: 'health_score',
      title: 'Financial Health: $healthLevel (${score.toStringAsFixed(0)}/100)',
      description: description,
      category: 'general',
      type: InsightType.general,
      priority: priority,
      actionData: {
        'action': 'view_health_details',
        'score': score,
      },
      createdAt: DateTime.now(),
      confidenceScore: 0.85,
      supportingData: [
        'Balance: ${balance >= 0 ? "✓" : "✗"} \$${balance.toStringAsFixed(2)}',
        'Cash Flow: ${netCashFlow >= 0 ? "✓" : "✗"} \$${netCashFlow.toStringAsFixed(2)}',
        'Savings Rate: ${savingsRate >= 0.15 ? "✓" : "✗"} ${(savingsRate * 100).toStringAsFixed(1)}%',
        'Income vs Expenses: ${income >= expenses ? "✓" : "✗"}',
      ],
    ));
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
          final name = customName ?? 'Savings';
          final amount = customAmount ?? insight.recommendedAmount ?? 100.0;
          await _investmentProvider.addInvestment(name, amount,
              category: 'Savings');
          break;

        default:
          break;
      }

      _insights[idx] =
          _insights[idx].copyWith(isExecuted: true, executedAt: DateTime.now());
      return true;
    } catch (e, st) {
      _logError('Failed to execute action', e, st);
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

      // Enhanced category keywords with income/expense classification
      final categoryScores = <String, double>{};

      // Income categories
      final incomeKeywords = {
        'Salary': ['salary', 'paycheck', 'wage', 'pay', 'income', 'earnings'],
        'Freelance': ['freelance', 'contract', 'gig', 'consulting', 'client'],
        'Business': ['business', 'revenue', 'sales', 'profit'],
        'Investment Returns': [
          'dividend',
          'interest',
          'capital gain',
          'return'
        ],
        'Other Income': ['bonus', 'gift', 'refund', 'reimbursement'],
      };

      // Expense categories
      final expenseKeywords = {
        'Food': [
          'food',
          'restaurant',
          'meal',
          'lunch',
          'dinner',
          'breakfast',
          'cafe',
          'pizza',
          'burger',
          'eat'
        ],
        'Groceries': [
          'grocery',
          'supermarket',
          'walmart',
          'target',
          'store',
          'market'
        ],
        'Transportation': [
          'uber',
          'lyft',
          'taxi',
          'gas',
          'fuel',
          'parking',
          'metro',
          'bus',
          'train',
          'car'
        ],
        'Housing': [
          'rent',
          'mortgage',
          'utilities',
          'electricity',
          'water',
          'internet',
          'cable',
          'home'
        ],
        'Entertainment': [
          'movie',
          'netflix',
          'spotify',
          'game',
          'concert',
          'show',
          'theater',
          'entertainment'
        ],
        'Shopping': [
          'amazon',
          'clothing',
          'clothes',
          'shoes',
          'mall',
          'online',
          'shop'
        ],
        'Health': [
          'doctor',
          'hospital',
          'pharmacy',
          'medicine',
          'gym',
          'fitness',
          'health',
          'medical'
        ],
        'Bills': ['bill', 'insurance', 'phone', 'subscription'],
        'Education': [
          'tuition',
          'course',
          'book',
          'school',
          'college',
          'education'
        ],
      };

      // Check income keywords first
      for (final entry in incomeKeywords.entries) {
        double score = 0.0;
        for (final keyword in entry.value) {
          if (lower.contains(keyword)) {
            score += 1.0;
            if (lower == keyword) score += 2.0;
          }
        }
        if (score > 0) categoryScores[entry.key] = score;
      }

      // If no income match, check expense keywords
      if (categoryScores.isEmpty) {
        for (final entry in expenseKeywords.entries) {
          double score = 0.0;
          for (final keyword in entry.value) {
            if (lower.contains(keyword)) {
              score += 1.0;
              if (lower == keyword) score += 2.0;
            }
          }
          if (score > 0) categoryScores[entry.key] = score;
        }
      }

      // Return category with highest score
      if (categoryScores.isNotEmpty) {
        final sortedCategories = categoryScores.entries.toList()
          ..sort((a, b) => b.value.compareTo(a.value));
        return sortedCategories.first.key;
      }

      // Fallback to user's custom categories
      final categories =
          _categoryProvider.categories.map((c) => c.name).toList();
      for (final cat in categories) {
        final cLower = cat.toLowerCase();
        if (lower.contains(cLower) || cLower.contains(lower)) return cat;
      }

      // Amount-based heuristics
      if (amount > 1000) return 'Salary'; // Likely income
      if (amount > 500) return 'Housing';
      if (amount > 100) return 'Shopping';
      if (amount < 20) return 'Food';

      return 'Others';
    } catch (e, st) {
      _logError('Failed to suggest category', e, st);
      return 'Others';
    }
  }

  @override
  Future<Map<String, dynamic>> getSpendingRecommendations() async {
    try {
      final flow = _currentFlow ??
          _analyzeFinancialFlow(_listProvider.transactions.toList());
      final patterns = _spendingPatterns;

      // Calculate recommended budgets based on income
      final categoryLimits = <String, double>{};

      if (flow.totalIncome > 0) {
        // 50/30/20 rule allocation
        final needs = flow.totalIncome * 0.50;
        final wants = flow.totalIncome * 0.30;
        final savingsTarget = flow.totalIncome * 0.20;

        // Distribute needs budget
        final essentialCategories = [
          'Housing',
          'Groceries',
          'Transportation',
          'Utilities',
          'Health'
        ];
        final needsPerCategory = needs / essentialCategories.length;
        for (final cat in essentialCategories) {
          categoryLimits[cat] = needsPerCategory;
        }

        // Distribute wants budget
        final wantsCategories = ['Entertainment', 'Shopping', 'Food'];
        final wantsPerCategory = wants / wantsCategories.length;
        for (final cat in wantsCategories) {
          categoryLimits[cat] = wantsPerCategory;
        }

        return {
          'dailyBudget': flow.totalIncome / 30,
          'weeklyBudget': flow.totalIncome / 4,
          'monthlyBudget': flow.totalIncome * 0.80, // 80% for expenses
          'categoryLimits': categoryLimits,
          'savingsGoal': savingsTarget,
          'investmentRecommendation': savingsTarget * 0.50,
          'needsBudget': needs,
          'wantsBudget': wants,
          'recommendedSavingsRate': 0.20,
          'incomeBasedPlanning': true,
        };
      } else {
        // Fallback for users without income tracking
        double totalRecommendedBudget = 0.0;
        for (final pattern in patterns.values.where((p) => p.isExpense)) {
          final recommendedLimit = pattern.avgAmount * 1.1;
          categoryLimits[pattern.category] = recommendedLimit;
          totalRecommendedBudget += recommendedLimit;
        }

        return {
          'dailyBudget': totalRecommendedBudget / 30,
          'weeklyBudget': totalRecommendedBudget / 4,
          'monthlyBudget': totalRecommendedBudget,
          'categoryLimits': categoryLimits,
          'savingsGoal': totalRecommendedBudget * 0.25,
          'investmentRecommendation': 0.0,
          'needsBudget': totalRecommendedBudget * 0.65,
          'wantsBudget': totalRecommendedBudget * 0.35,
          'recommendedSavingsRate': 0.20,
          'incomeBasedPlanning': false,
        };
      }
    } catch (e, st) {
      _logError('Failed to compute spending recommendations', e, st);
      return {};
    }
  }

  @override
  Future<bool> optimizeBudgets() async {
    try {
      final flow = _currentFlow ??
          _analyzeFinancialFlow(_listProvider.transactions.toList());
      final patterns = _spendingPatterns;

      if (flow.totalIncome > 0) {
        // Income-based budget optimization
        final essentialCategories = [
          'Housing',
          'Groceries',
          'Transportation',
          'Utilities',
          'Health'
        ];
        final needs = flow.totalIncome * 0.50;

        for (final category in essentialCategories) {
          final pattern = patterns.values.firstWhere(
              (p) => p.category == category && p.isExpense,
              orElse: () => patterns.values.first);

          if (pattern.category == category) {
            final optimized = math.min(
                pattern.avgAmount * 1.15, needs / essentialCategories.length);
            await _budgetProvider.createOrUpdateBudget(category, optimized);
          }
        }
      } else {
        // Pattern-based optimization (original approach)
        for (final pattern in patterns.values.where((p) => p.isExpense)) {
          final optimizedAmount =
              (pattern.avgAmount + pattern.trend.abs()) * 1.1;
          await _budgetProvider.createOrUpdateBudget(
            pattern.category,
            optimizedAmount.clamp(10.0, pattern.avgAmount * 2),
          );
        }
      }

      return true;
    } catch (e, st) {
      _logError('Failed to optimize budgets', e, st);
      return false;
    }
  }
}

// Extension for string capitalization
extension StringExtension on String {
  String capitalize() {
    if (isEmpty) return this;
    return '${this[0].toUpperCase()}${substring(1)}';
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
