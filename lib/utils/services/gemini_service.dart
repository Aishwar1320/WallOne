import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:wallone/state/adviser_provider.dart';
import 'package:wallone/state/balance_provider.dart';
import 'package:wallone/state/investment_provider.dart';
import 'package:wallone/state/budget_provider.dart';
import 'package:wallone/state/list_provider.dart';
import 'package:wallone/state/category_provider.dart';

/// Model for AI-generated financial insights
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
    // parse recommendedAmount robustly
    double? parseDouble(dynamic v) {
      if (v == null) return null;
      if (v is num) return v.toDouble();
      if (v is String) return double.tryParse(v);
      return null;
    }

    // parse isActionable robustly (accepts bool or "true"/"false" strings)
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

  // Create a copy of this insight with updated fields
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

    if (t.contains('budget') ||
        t.contains('create_budget') ||
        t.contains('set_limit')) {
      return InsightType.budget;
    }
    if (t.contains('saving')) return InsightType.savings;
    if (t.contains('invest')) return InsightType.investment;
    if (t.contains('expense')) return InsightType.expense;
    if (t.contains('alert') ||
        t.contains('low_balance') ||
        t.contains('warning')) {
      return InsightType.alert;
    }

    // fallback
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

enum InsightType {
  budget,
  savings,
  investment,
  expense,
  alert,
  general,
}

enum InsightPriority {
  high,
  medium,
  low,
}

/// Enhanced AI service with smart duplicate detection and insight management
class GeminiFinancialAdvisor {
  static const String _baseUrl =
      'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent';

  final String _apiKey;
  final BalanceProvider _balanceProvider;
  final InvestmentProvider _investmentProvider;
  final BudgetProvider _budgetProvider;
  final ListProvider _listProvider;
  final CategoryProvider _categoryProvider;

  // Enhanced cache for insights with duplicate tracking
  final List<FinancialInsight> _insights = [];
  final Set<String> _executedInsightIds = {};
  DateTime? _lastAnalysisTime;

  static const String _tag = 'GeminiFinancialAdvisor';

  GeminiFinancialAdvisor({
    required String apiKey,
    required BalanceProvider balanceProvider,
    required InvestmentProvider investmentProvider,
    required BudgetProvider budgetProvider,
    required ListProvider listProvider,
    required CategoryProvider categoryProvider,
  })  : _apiKey = apiKey,
        _balanceProvider = balanceProvider,
        _investmentProvider = investmentProvider,
        _budgetProvider = budgetProvider,
        _listProvider = listProvider,
        _categoryProvider = categoryProvider;

  List<FinancialInsight> get insights => List.unmodifiable(_insights);
  List<FinancialInsight> get activeInsights =>
      _insights.where((insight) => !insight.isExecuted).toList();

  /// Generate comprehensive financial analysis with smart duplicate detection
  Future<List<FinancialInsight>> generateFinancialInsights({
    bool forceRefresh = false,
  }) async {
    try {
      // Check if we need to refresh (every 6 hours or forced)
      if (!forceRefresh &&
          _lastAnalysisTime != null &&
          DateTime.now().difference(_lastAnalysisTime!).inHours < 6 &&
          _insights.isNotEmpty) {
        _log('Using cached insights');
        return activeInsights;
      }

      _log('Generating new financial insights...');

      // Gather financial data
      final financialData = _gatherFinancialData();

      // Check total balance before generating budget/investment/savings insights
      final totalBalance =
          (financialData['balance']?['total'] ?? 0.0) as double;

      if (totalBalance <= 0) {
        _log(
            'No positive balance — skipping investment and budget/savings insights.');
        // You can still generate other insights like expense or alert if needed
        return activeInsights;
      }

      // Generate AI insights with existing data context
      final aiResponse = await _callGeminiAPI(financialData);

      // Parse insights
      final rawInsights = _parseInsights(aiResponse);

      // Filter out duplicates and already handled insights
      final filteredInsights = _filterDuplicateInsights(rawInsights);

      // Update cache, keeping executed insights for history but marking them
      _insights.removeWhere((insight) => !insight.isExecuted);
      _insights.addAll(filteredInsights);
      _lastAnalysisTime = DateTime.now();

      _log('Generated ${filteredInsights.length} new unique insights');
      return activeInsights;
    } catch (e, stackTrace) {
      _logError('Failed to generate insights', e, stackTrace);
      return activeInsights; // Return active cached insights if available
    }
  }

  /// Filter duplicate insights based on existing budgets and investments
  List<FinancialInsight> _filterDuplicateInsights(
      List<FinancialInsight> insights) {
    final filteredInsights = <FinancialInsight>[];

    for (final insight in insights) {
      if (_isDuplicateInsight(insight)) {
        _log(
            'Filtered duplicate insight: ${insight.title} (${insight.targetCategory})');
        continue;
      }

      // Check if similar insight was already executed
      if (_isSimilarToExecutedInsight(insight)) {
        _log('Filtered similar executed insight: ${insight.title}');
        continue;
      }

      filteredInsights.add(insight);
    }

    final totalBalance = _balanceProvider.totalBalance;

    // Apply balance-based filters and capping in a deterministic loop
    final List<FinancialInsight> finalFiltered = [];
    for (final insight in filteredInsights) {
      if ((insight.type == InsightType.investment ||
              insight.type == InsightType.savings ||
              insight.type == InsightType.budget) &&
          totalBalance <= 0) {
        _log(
            'Filtered out ${insight.type.name} insight due to zero/negative balance');
        continue;
      }

      // Optionally, cap recommended amounts based on balance
      if (insight.recommendedAmount != null &&
          insight.recommendedAmount! > totalBalance * 0.3) {
        _log(
            'Capping recommended amount for ${insight.title} to 30% of total balance');
        final capped = insight.copyWith(recommendedAmount: totalBalance * 0.3);
        finalFiltered.add(capped);
        continue;
      }

      finalFiltered.add(insight);
    }

    return finalFiltered;
  }

  /// Check if insight is duplicate based on existing data
  bool _isDuplicateInsight(FinancialInsight insight) {
    switch (insight.type) {
      case InsightType.budget:
        return _isDuplicateBudgetInsight(insight);
      case InsightType.investment:
      case InsightType.savings:
        return _isDuplicateInvestmentInsight(insight);
      default:
        return false;
    }
  }

  /// Check for duplicate budget insights
  bool _isDuplicateBudgetInsight(FinancialInsight insight) {
    final targetCategory = insight.targetCategory?.toLowerCase();
    if (targetCategory == null) return false;

    // Check if budget already exists for this category
    final existingBudgets = _budgetProvider.budgets;
    return existingBudgets.any(
      (budget) => budget.category.toLowerCase() == targetCategory,
    );
  }

  /// Check for duplicate investment insights
  bool _isDuplicateInvestmentInsight(FinancialInsight insight) {
    final proposedName = _extractProposedInvestmentName(insight).toLowerCase();
    final proposedCategory = insight.targetCategory?.toLowerCase();

    if (proposedName.isEmpty) return false;

    // Check if investment with similar name or category already exists
    final existingInvestments = _investmentProvider.investments;
    return existingInvestments.any((investment) {
      final existingName = investment.name.toLowerCase();
      final existingCategory = investment.category.toLowerCase();

      // Check for exact name match
      if (existingName == proposedName) return true;

      // Check for similar names (fuzzy matching)
      if (_areSimilarStrings(existingName, proposedName)) return true;

      // Check for same category with similar purpose
      if (proposedCategory != null &&
          existingCategory == proposedCategory &&
          _areSimilarInvestmentPurposes(existingName, proposedName)) {
        return true;
      }

      return false;
    });
  }

  /// Check if insight is similar to already executed insights
  bool _isSimilarToExecutedInsight(FinancialInsight insight) {
    final executedInsights = _insights.where((i) => i.isExecuted);

    for (final executed in executedInsights) {
      if (executed.type == insight.type &&
          executed.targetCategory?.toLowerCase() ==
              insight.targetCategory?.toLowerCase()) {
        // If executed within last 7 days, consider it duplicate
        final daysSinceExecution = DateTime.now()
            .difference(executed.executedAt ?? executed.createdAt)
            .inDays;
        if (daysSinceExecution < 7) {
          return true;
        }
      }
    }

    return false;
  }

  /// Extract proposed investment name from insight
  String _extractProposedInvestmentName(FinancialInsight insight) {
    // Try different sources for the investment name
    final actionData = insight.actionData;

    // Check actionData.parameters.name
    if (actionData['parameters'] is Map) {
      final params = actionData['parameters'] as Map;
      if (params['name'] is String && params['name'].isNotEmpty) {
        return params['name'];
      }
    }

    // Check actionData.name
    if (actionData['name'] is String && actionData['name'].isNotEmpty) {
      return actionData['name'];
    }

    // Fallback to insight title or category
    if (insight.title.isNotEmpty) return insight.title;
    return insight.category;
  }

  /// Check if two strings are similar (fuzzy matching)
  bool _areSimilarStrings(String str1, String str2) {
    if (str1 == str2) return true;

    // Simple similarity check - contains each other or share significant words
    final words1 = str1.toLowerCase().split(' ');
    final words2 = str2.toLowerCase().split(' ');

    // Check if they share at least 60% of words
    final commonWords = words1
        .where((word) => word.length > 2 && words2.contains(word))
        .toList();

    final similarity =
        commonWords.length / (words1.length.clamp(1, double.infinity));
    return similarity >= 0.6;
  }

  /// Check if investment purposes are similar
  bool _areSimilarInvestmentPurposes(String name1, String name2) {
    final purposeKeywords = {
      'emergency': ['emergency', 'backup', 'reserve'],
      'savings': ['saving', 'save', 'fund'],
      'retirement': ['retirement', 'pension', 'future'],
      'education': ['education', 'study', 'school'],
    };

    final name1Lower = name1.toLowerCase();
    final name2Lower = name2.toLowerCase();

    for (final keywords in purposeKeywords.values) {
      final hasKeyword1 = keywords.any((kw) => name1Lower.contains(kw));
      final hasKeyword2 = keywords.any((kw) => name2Lower.contains(kw));

      if (hasKeyword1 && hasKeyword2) return true;
    }

    return false;
  }

  /// Execute an actionable insight with user customization options
  Future<bool> executeInsightAction(
    String insightId, {
    String? customName,
    double? customAmount,
  }) async {
    void dumpInsightDebug(FinancialInsight insight) {
      _log('Insight details:\n'
          'id: ${insight.id}\n'
          'title: ${insight.title}\n'
          'type: ${insight.type}\n'
          'category: ${insight.category}\n'
          'isActionable: ${insight.isActionable}\n'
          'recommendedAmount: ${insight.recommendedAmount}\n'
          'targetCategory: ${insight.targetCategory}\n'
          'actionData: ${insight.actionData}');
    }

    try {
      final insightIndex = _insights.indexWhere((i) => i.id == insightId);
      if (insightIndex == -1) {
        throw Exception('Insight not found');
      }

      final insight = _insights[insightIndex];

      if (!insight.isActionable) {
        _log('Insight $insightId is not actionable');
        return false;
      }

      _log('Executing action for insight: ${insight.title}');
      dumpInsightDebug(insight);

      bool success = false;

      switch (insight.type) {
        case InsightType.budget:
          success = await _executeBudgetAction(insight,
              customName: customName, customAmount: customAmount);
          break;
        case InsightType.investment:
          success = await _executeInvestmentAction(insight,
              customName: customName, customAmount: customAmount);
          break;
        case InsightType.savings:
          success = await _executeSavingsAction(insight,
              customName: customName, customAmount: customAmount);
          break;
        case InsightType.expense:
          success = await _executeExpenseAction(insight);
          break;
        case InsightType.alert:
        case InsightType.general:
          success = await _executeAlertAction(insight);
          break;
      }

      if (success) {
        // Mark insight as executed and remove from active insights
        _insights[insightIndex] = insight.copyWith(
          isExecuted: true,
          executedAt: DateTime.now(),
        );

        _executedInsightIds.add(insightId);
        _log('Successfully executed and removed insight: ${insight.title}');

        // Generate new insights after successful execution
        await _generateReplacementInsights(insight);
      }

      return success;
    } catch (e, stackTrace) {
      _logError('Failed to execute insight action', e, stackTrace);
      return false;
    }
  }

  /// Generate replacement insights after executing an insight
  Future<void> _generateReplacementInsights(
      FinancialInsight executedInsight) async {
    try {
      _log(
          'Generating replacement insights after executing: ${executedInsight.title}');

      // Wait a moment for the data to be updated in providers
      await Future.delayed(const Duration(milliseconds: 500));

      // Generate new insights to replace the executed one
      await generateFinancialInsights(forceRefresh: true);
    } catch (e, stackTrace) {
      _logError('Failed to generate replacement insights', e, stackTrace);
    }
  }

  /// Remove insight from active list (for manual dismissal)
  void dismissInsight(String insightId) {
    final index = _insights.indexWhere((i) => i.id == insightId);
    if (index != -1) {
      _insights[index] = _insights[index].copyWith(
        isExecuted: true,
        executedAt: DateTime.now(),
      );
      _log('Dismissed insight: ${_insights[index].title}');
    }
  }

  /// Enhanced budget action execution with user customization
  Future<bool> _executeBudgetAction(
    FinancialInsight insight, {
    String? customName,
    String? customCategory,
    double? customAmount,
  }) async {
    final action =
        (insight.actionData['action'] as String?) ?? insight.actionData['type'];

    String? resolveCategory() {
      if (customCategory != null && customCategory.isNotEmpty) {
        return customCategory;
      }
      if (insight.targetCategory != null &&
          insight.targetCategory!.isNotEmpty) {
        return insight.targetCategory!;
      }
      final p = insight.actionData['parameters'];
      if (p is Map &&
          p['category'] is String &&
          (p['category'] as String).isNotEmpty) {
        return p['category'];
      }
      if (insight.actionData['category'] is String &&
          (insight.actionData['category'] as String).isNotEmpty) {
        return insight.actionData['category'];
      }
      if (insight.category.isNotEmpty) return insight.category;
      return null;
    }

    double? resolveAmount() {
      if (customAmount != null) return customAmount;
      if (insight.recommendedAmount != null) return insight.recommendedAmount;
      final p = insight.actionData['parameters'];
      if (p is Map && p['amount'] != null) {
        final v = p['amount'];
        if (v is num) return v.toDouble();
        if (v is String) return double.tryParse(v);
      }
      if (insight.actionData['amount'] != null) {
        final v = insight.actionData['amount'];
        if (v is num) return v.toDouble();
        if (v is String) return double.tryParse(v);
      }
      return null;
    }

    final target = resolveCategory();
    final amount = resolveAmount();

    switch (action) {
      case 'create_budget':
      case 'set_limit':
        if (target != null && amount != null) {
          await _budgetProvider.createOrUpdateBudget(target, amount);
          _log('Created/updated budget for $target: $amount');
          return true;
        }
        break;
    }

    if (target != null && amount == null) {
      await _budgetProvider.createOrUpdateBudget(
          target, 100.0); // Default amount
      _log('Created default budget for $target');
      return true;
    }

    _log(
        'Budget action missing required parameters (category: $target, amount: $amount)');
    return false;
  }

  /// Enhanced investment action execution with user customization
  Future<bool> _executeInvestmentAction(
    FinancialInsight insight, {
    String? customName,
    double? customAmount,
  }) async {
    final action = insight.actionData['action'] as String?;

    switch (action) {
      case 'add_investment':
        final amount = customAmount ?? insight.recommendedAmount ?? 0.0;
        if (amount > 0) {
          final actionName =
              (insight.actionData['parameters'] as Map?)?['name'] as String?;
          final name = customName?.trim().isNotEmpty == true
              ? customName!.trim()
              : actionName?.isNotEmpty == true
                  ? actionName
                  : (insight.title.isNotEmpty == true
                      ? insight.title
                      : 'Investment');

          await _investmentProvider.addInvestment(
            name!,
            amount,
          );
          _log('Created investment: $name ($amount)');
          return true;
        }
        break;
    }
    return false;
  }

  /// Enhanced savings action execution with user customization
  Future<bool> _executeSavingsAction(
    FinancialInsight insight, {
    String? customName,
    String? customCategory,
    double? customAmount,
  }) async {
    final action = insight.actionData['action'] as String?;

    switch (action) {
      case 'create_savings':
        final amount = customAmount ?? insight.recommendedAmount;
        if (amount != null && amount > 0) {
          final name = customName ?? 'Auto-Savings';
          final category = customCategory ?? 'Savings';

          await _investmentProvider.addInvestment(
            name,
            amount,
            category: category,
          );
          _log('Created savings: $name ($amount)');
          return true;
        }
        break;
    }
    return false;
  }

  // [Previous methods remain the same: _executeExpenseAction, _executeAlertAction, etc.]

  Future<bool> _executeExpenseAction(FinancialInsight insight) async {
    // Most expense actions are informational
    return false;
  }

  Future<bool> _executeAlertAction(FinancialInsight insight) async {
    final action = insight.actionData['action'] as String? ?? '';

    if (action.contains('notify') ||
        action.contains('alert') ||
        insight.type == InsightType.alert) {
      _log('Alert triggered: ${insight.title} — ${insight.description}');
      return true;
    }

    final actionName = (insight.actionData['action'] as String?) ?? '';
    if (actionName == 'create_budget' || actionName == 'set_limit') {
      return await _executeBudgetAction(insight);
    }
    if (actionName == 'add_investment' || actionName == 'create_savings') {
      return await _executeInvestmentAction(insight) ||
          await _executeSavingsAction(insight);
    }

    _log('Unhandled general/alert action: $actionName');
    return false;
  }

  /// Get personalized spending recommendations
  Future<Map<String, dynamic>> getSpendingRecommendations() async {
    try {
      final financialData = _gatherFinancialData();

      const prompt = """
      Based on the financial data, provide spending recommendations in JSON format:
      {
        "dailyBudget": number,
        "weeklyBudget": number,
        "monthlyBudget": number,
        "categoryLimits": {
          "categoryName": amount
        },
        "savingsGoal": number,
        "investmentRecommendation": number
      }
      """;

      final response =
          await _callGeminiAPI(financialData, customPrompt: prompt);
      return _parseJsonResponse(response);
    } catch (e, stackTrace) {
      _logError('Failed to get spending recommendations', e, stackTrace);
      return {};
    }
  }

  /// Automated budget optimization
  Future<bool> optimizeBudgets() async {
    try {
      _log('Starting automated budget optimization...');

      final recommendations = await getSpendingRecommendations();
      final categoryLimits =
          recommendations['categoryLimits'] as Map<String, dynamic>? ?? {};

      // Apply category limits
      for (final entry in categoryLimits.entries) {
        final category = entry.key;
        final limit = (entry.value as num).toDouble();

        await _budgetProvider.setCategoryLimit(category, limit);
        _log('Set budget limit for $category: $limit');
      }

      // Set savings goal as investment
      final savingsGoal = recommendations['savingsGoal'] as num?;
      if (savingsGoal != null && savingsGoal > 0) {
        await _investmentProvider.addInvestment(
          'Auto-Savings',
          savingsGoal.toDouble(),
          category: 'Savings',
        );
        _log('Created auto-savings investment: $savingsGoal');
      }

      return true;
    } catch (e, stackTrace) {
      _logError('Failed to optimize budgets', e, stackTrace);
      return false;
    }
  }

  /// Smart expense categorization
  Future<String> suggestCategory(String description, double amount) async {
    try {
      final categories =
          _categoryProvider.categories.map((c) => c.name).toList();

      final prompt = """
      Given this expense description: "$description" and amount: $amount
      Available categories: ${categories.join(', ')}
      
      Return the most appropriate category name from the available categories.
      Only return the category name, nothing else.
      """;

      final response = await _callGeminiAPI({}, customPrompt: prompt);

      // Extract category name from response
      final suggestedCategory = response.trim();

      // Validate against available categories
      final matchingCategory = categories.firstWhere(
        (cat) => cat.toLowerCase() == suggestedCategory.toLowerCase(),
        orElse: () => 'Others',
      );

      return matchingCategory;
    } catch (e, stackTrace) {
      _logError('Failed to suggest category', e, stackTrace);
      return 'Others';
    }
  }

  /// Gather comprehensive financial data including existing items to avoid duplicates
  Map<String, dynamic> _gatherFinancialData() {
    // Filter out investment-related transactions so they don't count as expenses
    final recentTransactions = _listProvider.transactions
        .where((t) => t.transactionType != TransactionType.investment)
        .take(50)
        .map((t) => {
              'title': t.title,
              'category': t.category,
              'amount': t.amount,
              'isIncome': t.isIncome,
              'date': t.date,
            })
        .toList();

    // Include existing budgets (for avoiding duplicate budget suggestions)
    final existingBudgets = _budgetProvider.budgets
        .map((b) => {
              'category': b.category,
              'amount': b.amount,
              'spent': b.spent,
              'progress': b.progress,
            })
        .toList();

    // Include existing investments (to avoid duplicate investment insights)
    final existingInvestments = _investmentProvider.investments
        .map((i) => {
              'name': i.name,
              'amount': i.amount,
              'category': i.category,
              'isActive': i.isActive,
              'monthlyDeductions': i.monthlyDeductions.length,
            })
        .toList();

    return {
      'balance': {
        'total': _balanceProvider.totalBalance,
        'dailyExpenses': _balanceProvider.dailyExpenses,
        'weeklyExpenses': _balanceProvider.weeklyExpenses,
        'monthlyExpenses': _balanceProvider.monthlyExpenses,
        'dailyIncomes': _balanceProvider.dailyIncomes,
        'weeklyIncomes': _balanceProvider.weeklyIncomes,
        'monthlyIncomes': _balanceProvider.monthlyIncomes,
      },
      'investments': {
        'total': _investmentProvider.totalInvestments,
        'existing': existingInvestments,
      },
      'budgets': {
        'existing': existingBudgets,
      },
      'recentTransactions': recentTransactions,
      'categories': _categoryProvider.categories.map((c) => c.name).toList(),
      'executedInsights': _executedInsightIds.toList(),
      'currency': _balanceProvider.currencyCode,
      'analysisDate': DateTime.now().toIso8601String(),
    };
  }

  /// Enhanced analysis prompt to avoid duplicates
  String _buildAnalysisPrompt(Map<String, dynamic> financialData) {
    final totalBalance = (financialData['balance']?['total'] ?? 0.0) as double;

    // Adjust guidance based on balance level
    String balanceGuidance;
    if (totalBalance <= 0) {
      balanceGuidance = '''
    The user currently has no balance. Do not suggest any investments, savings, or new budgets.
    Only provide general or expense management insights.
    ''';
    } else if (totalBalance > 0 && totalBalance < 500) {
      balanceGuidance = '''
    The user has a very low balance. Focus on small, low-risk savings or budget control insights.
    Avoid high investment recommendations.
    ''';
    } else if (totalBalance >= 500 && totalBalance < 5000) {
      balanceGuidance = '''
    The user has a moderate balance. You may suggest balanced budgets and moderate savings.
    Investment recommendations should be modest (around 5–15% of total balance).
    ''';
    } else {
      balanceGuidance = '''
    The user has a healthy balance. Suggest realistic investment and savings opportunities
    based on total balance (e.g., 10–30% allocation).
    ''';
    }

    return """
You are a financial advisor AI. Analyze the following financial data and provide insights in JSON format.

$balanceGuidance

IMPORTANT:
- Do NOT suggest creating budgets, savings, or investments that already exist.
- Each insight must include 'type', 'title', 'description', 'recommendedAmount', and 'category'.
- Ensure recommended amounts are proportional to the user's total balance (${totalBalance.toStringAsFixed(2)}).

Financial Data:
${jsonEncode(financialData)}

Existing Budgets: ${jsonEncode(financialData['budgets']['existing'])}
Existing Investments: ${jsonEncode(financialData['investments']['existing'])}
Previously Executed Insights: ${jsonEncode(financialData['executedInsights'])}

Provide your analysis as a JSON array of insights with this structure:
[
  {
    "id": "unique_id",
    "title": "Brief insight title",
    "description": "Detailed explanation",
    "category": "budget|savings|investment|expense|alert|general",
    "type": "budget|savings|investment|expense|alert|general",
    "priority": "high|medium|low",
    "isActionable": true/false,
    "recommendedAmount": number (if applicable),
    "targetCategory": "category name" (if applicable),
    "actionData": {
      "action": "create_budget|add_investment|set_limit|etc",
      "parameters": {
        "name": "suggested name",
        "category": "suggested category",
        "amount": number
      }
    }
  }
]

Rules for avoiding duplicates:
1. Do NOT suggest budgets for categories that already have budgets
2. Do NOT suggest investments with names similar to existing investments
3. Do NOT suggest investments in categories that already have similar investments
4. Focus on NEW opportunities, optimization of existing items, or alerts about spending patterns
5. If suggesting modifications to existing items, make it clear in the description

Focus on:
1. New budget categories that don't exist yet
2. Investment opportunities in unexplored areas
3. Spending pattern analysis and warnings
4. Optimization suggestions for existing budgets
5. Goal achievement progress tracking
6. Cash flow improvements
7. New savings opportunities

Make insights actionable where possible. Return only valid JSON.
""";
  }

  /// Call Gemini API with financial data
  Future<String> _callGeminiAPI(
    Map<String, dynamic> financialData, {
    String? customPrompt,
  }) async {
    final prompt = customPrompt ?? _buildAnalysisPrompt(financialData);

    final headers = {
      'Content-Type': 'application/json',
      // Gemini expects API key either as query param or header; prefer header for clarity.
      'x-goog-api-key': _apiKey,
    };

    final body = jsonEncode({
      'contents': [
        {
          'parts': [
            {
              'text': prompt,
            }
          ]
        }
      ],
      'generationConfig': {
        'temperature': 0.7,
        'topK': 40,
        'topP': 0.95,
        'maxOutputTokens': 2048,
      },
      'safetySettings': [
        {
          'category': 'HARM_CATEGORY_HARASSMENT',
          'threshold': 'BLOCK_MEDIUM_AND_ABOVE'
        },
        {
          'category': 'HARM_CATEGORY_HATE_SPEECH',
          'threshold': 'BLOCK_MEDIUM_AND_ABOVE'
        },
        {
          'category': 'HARM_CATEGORY_SEXUALLY_EXPLICIT',
          'threshold': 'BLOCK_MEDIUM_AND_ABOVE'
        },
        {
          'category': 'HARM_CATEGORY_DANGEROUS_CONTENT',
          'threshold': 'BLOCK_MEDIUM_AND_ABOVE'
        }
      ]
    });

    // Make the request with a timeout and a small retry strategy for transient failures
    const int maxRetries = 2;
    int attempt = 0;
    while (true) {
      attempt++;
      try {
        final resp = await http
            .post(Uri.parse(_baseUrl), headers: headers, body: body)
            .timeout(const Duration(seconds: 15));

        if (resp.statusCode == 200) {
          final data = jsonDecode(resp.body);
          // attempt different safe paths for content
          String? content;
          try {
            content =
                data['candidates'][0]['content']['parts'][0]['text'] as String?;
          } catch (_) {
            // fallback: try to extract any string within response
            content = resp.body;
          }

          return content ?? '';
        }

        // Non-200: if retryable, try again, else throw
        if (resp.statusCode >= 500 && attempt <= maxRetries) {
          await Future.delayed(Duration(milliseconds: 500 * attempt));
          continue;
        }

        throw HttpException(
            'API call failed: ${resp.statusCode} - ${resp.body}');
      } on TimeoutException {
        if (attempt <= maxRetries) {
          await Future.delayed(Duration(milliseconds: 400 * attempt));
          continue;
        }
        rethrow;
      } catch (e) {
        if (attempt <= maxRetries) {
          await Future.delayed(Duration(milliseconds: 400 * attempt));
          continue;
        }
        rethrow;
      }
    }
  }

  /// Parse insights from AI response
  List<FinancialInsight> _parseInsights(String response) {
    try {
      // Extract JSON from response
      final jsonStart = response.indexOf('[');
      final jsonEnd = response.lastIndexOf(']') + 1;

      if (jsonStart == -1 || jsonEnd == 0) {
        throw Exception('No JSON array found in response');
      }

      final jsonString = response.substring(jsonStart, jsonEnd);
      final List<dynamic> insightsData = jsonDecode(jsonString);

      return insightsData
          .map((data) => FinancialInsight.fromJson(data))
          .toList();
    } catch (e, stackTrace) {
      _logError('Failed to parse insights', e, stackTrace);
      return [];
    }
  }

  /// Parse JSON response safely
  Map<String, dynamic> _parseJsonResponse(String response) {
    try {
      final jsonStart = response.indexOf('{');
      final jsonEnd = response.lastIndexOf('}') + 1;

      if (jsonStart == -1 || jsonEnd == 0) {
        throw Exception('No JSON object found in response');
      }

      final jsonString = response.substring(jsonStart, jsonEnd);
      return jsonDecode(jsonString);
    } catch (e) {
      _logError('Failed to parse JSON response', e, StackTrace.current);
      return {};
    }
  }

  void _log(String message) {
    if (kDebugMode) {
      print('[$_tag] $message');
    }
  }

  void _logError(String message, dynamic error, StackTrace? stackTrace) {
    if (kDebugMode) {
      print('[$_tag ERROR] $message');
      print('Error details: $error');
      if (stackTrace != null) {
        print('Stack trace: $stackTrace');
      }
    }
  }
}

class AIScheduler {
  static Timer? _timer;

  static void startPeriodicAnalysis(AIAdvisorProvider provider) {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(hours: 6), (timer) {
      provider.autoRefreshIfNeeded();
    });
  }

  static void stop() {
    _timer?.cancel();
  }
}
