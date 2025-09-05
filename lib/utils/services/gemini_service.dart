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
    );
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
      case 'High':
        return InsightPriority.high;
      case 'Medium':
        return InsightPriority.medium;
      case 'Low':
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

/// Main AI service for financial insights and automation
class GeminiFinancialAdvisor {
  static const String _baseUrl =
      'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent';

  final String _apiKey;
  final BalanceProvider _balanceProvider;
  final InvestmentProvider _investmentProvider;
  final BudgetProvider _budgetProvider;
  final ListProvider _listProvider;
  final CategoryProvider _categoryProvider;

  // Cache for insights to avoid excessive API calls
  final List<FinancialInsight> _insights = [];
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

  /// Generate comprehensive financial analysis and insights
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
        return _insights;
      }

      _log('Generating new financial insights...');

      // Gather financial data
      final financialData = _gatherFinancialData();

      // Generate AI insights
      final aiResponse = await _callGeminiAPI(financialData);

      // Parse insights
      final newInsights = _parseInsights(aiResponse);

      // Update cache
      _insights.clear();
      _insights.addAll(newInsights);
      _lastAnalysisTime = DateTime.now();

      _log('Generated ${newInsights.length} insights');
      return newInsights;
    } catch (e, stackTrace) {
      _logError('Failed to generate insights', e, stackTrace);
      return _insights; // Return cached insights if available
    }
  }

  /// Execute an actionable insight automatically
  Future<bool> executeInsightAction(String insightId) async {
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
      final insight = _insights.firstWhere(
        (i) => i.id == insightId,
        orElse: () => throw Exception('Insight not found'),
      );

      if (!insight.isActionable) {
        _log('Insight $insightId is not actionable');
        return false;
      }

      _log('Executing action for insight: ${insight.title}');
      dumpInsightDebug(insight);

      switch (insight.type) {
        case InsightType.budget:
          return await _executeBudgetAction(insight);
        case InsightType.investment:
          return await _executeInvestmentAction(insight);
        case InsightType.savings:
          return await _executeSavingsAction(insight);
        case InsightType.expense:
          return await _executeExpenseAction(insight);
        case InsightType.alert:
          return await _executeAlertAction(insight);
        case InsightType.general:
          return await _executeAlertAction(insight);
      }
    } catch (e, stackTrace) {
      _logError('Failed to execute insight action', e, stackTrace);
      return false;
    }
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

  /// Gather comprehensive financial data
  Map<String, dynamic> _gatherFinancialData() {
    final recentTransactions = _listProvider.transactions
        .take(50)
        .map((t) => {
              'title': t.title,
              'category': t.category,
              'amount': t.amount,
              'isIncome': t.isIncome,
              'date': t.date,
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
        'activeInvestments': _investmentProvider.investments
            .where((i) => i.isActive)
            .map((i) => {
                  'name': i.name,
                  'amount': i.amount,
                  'category': i.category,
                  'monthlyDeductions': i.monthlyDeductions.length,
                })
            .toList(),
      },
      'budgets': _budgetProvider.budgets
          .map((b) => {
                'category': b.category,
                'amount': b.amount,
                'spent': b.spent,
                'progress': b.progress,
              })
          .toList(),
      'recentTransactions': recentTransactions,
      'categories': _categoryProvider.categories.map((c) => c.name).toList(),
      'currency': _balanceProvider.currencyCode,
      'analysisDate': DateTime.now().toIso8601String(),
    };
  }

  /// Call Gemini API with financial data
  Future<String> _callGeminiAPI(
    Map<String, dynamic> financialData, {
    String? customPrompt,
  }) async {
    final prompt = customPrompt ?? _buildAnalysisPrompt(financialData);

    final headers = {
      'Content-Type': 'application/json',
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

    final response = await http.post(
      Uri.parse('$_baseUrl?key=$_apiKey'),
      headers: headers,
      body: body,
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final content = data['candidates'][0]['content']['parts'][0]['text'];
      return content;
    } else {
      throw HttpException(
          'API call failed: ${response.statusCode} - ${response.body}');
    }
  }

  /// Build comprehensive analysis prompt
  String _buildAnalysisPrompt(Map<String, dynamic> financialData) {
    return """
You are a financial advisor AI. Analyze the following financial data and provide insights in JSON format.

Financial Data:
${jsonEncode(financialData)}

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
      "parameters": {}
    }
  }
]

Focus on:
1. Budget overspending and optimization
2. Savings opportunities
3. Investment recommendations
4. Expense pattern analysis
5. Category-specific insights
6. Cash flow warnings
7. Goal achievement progress

Make insights actionable where possible. Return only valid JSON.
""";
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

  Future<bool> _executeAlertAction(FinancialInsight insight) async {
    // Example: low balance alert -> create an app-level notification or set a flag in balanceProvider
    final action = insight.actionData['action'] as String? ?? '';

    if (action.contains('notify') ||
        action.contains('alert') ||
        insight.type == InsightType.alert) {
      // Simple behavior — you can replace with app notifications, analytics, etc.
      _log('Alert triggered: ${insight.title} — ${insight.description}');

      return true;
    }

    // For general actionable items, map actionData.action to an existing executor
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

  /// Execute budget-related actions
  Future<bool> _executeBudgetAction(FinancialInsight insight) async {
    final action =
        (insight.actionData['action'] as String?) ?? insight.actionData['type'];

    // Resolve target category from: insight.targetCategory, actionData.parameters.category, actionData.category, insight.category
    String? resolveCategory() {
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
          return true;
        }
        break;
    }

    // If not handled above, try fallback: if we at least have category, create a zero/placeholder budget
    if (target != null && amount == null) {
      await _budgetProvider.createOrUpdateBudget(target, 0.0);
      _log('Created placeholder budget for $target because amount was missing');
      return true;
    }

    _log(
        'Budget action missing required parameters (category: $target, amount: $amount)');
    return false;
  }

  /// Execute investment-related actions
  Future<bool> _executeInvestmentAction(FinancialInsight insight) async {
    final action = insight.actionData['action'] as String?;

    switch (action) {
      case 'add_investment':
        if (insight.recommendedAmount != null) {
          final name = insight.actionData['name'] ?? 'Emergency Funds';
          final category = insight.actionData['category'] ?? 'Savings';

          await _investmentProvider.addInvestment(
            name,
            insight.recommendedAmount!,
            category: category,
          );
          return true;
        }
        break;
    }
    return false;
  }

  /// Execute savings-related actions
  Future<bool> _executeSavingsAction(FinancialInsight insight) async {
    final action = insight.actionData['action'] as String?;

    switch (action) {
      case 'create_savings':
        if (insight.recommendedAmount != null) {
          await _investmentProvider.addInvestment(
            'Auto-Savings',
            insight.recommendedAmount!,
            category: 'Savings',
          );
          return true;
        }
        break;
    }
    return false;
  }

  /// Execute expense-related actions
  Future<bool> _executeExpenseAction(FinancialInsight insight) async {
    // Most expense actions are informational
    // Could implement automatic categorization or alerts here
    return false;
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
