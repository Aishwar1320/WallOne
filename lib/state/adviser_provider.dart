import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

import 'package:wallone/state/balance_provider.dart';
import 'package:wallone/state/investment_provider.dart';
import 'package:wallone/state/budget_provider.dart';
import 'package:wallone/state/list_provider.dart';
import 'package:wallone/state/category_provider.dart';
import 'package:wallone/utils/services/gemini_service.dart';

/// Provider for managing AI financial advisor functionality
class AIAdvisorProvider with ChangeNotifier {
  final SharedPreferences _prefs;
  GeminiFinancialAdvisor? _advisor;

  List<FinancialInsight> _insights = [];
  bool _isLoading = false;
  bool _isAIEnabled = true;
  String? _error;

  // Auto-pilot settings
  bool _autoBudgetOptimization = false;
  bool _autoInvestmentSuggestions = false;
  bool _autoExpenseCategorization = true;
  bool _smartNotifications = true;

  // Analysis settings
  int _analysisFrequencyHours = 24;
  DateTime? _lastAnalysis;

  static const String _tag = 'AIAdvisorProvider';
  static const String _insightsKey = 'ai_insights';
  static const String _settingsKey = 'ai_settings';

  AIAdvisorProvider(this._prefs) {
    _loadSettings();
    _loadCachedInsights();
  }

  // Getters
  List<FinancialInsight> get insights => _insights;
  bool get isLoading => _isLoading;
  bool get isAIEnabled => _isAIEnabled;
  String? get error => _error;
  bool get autoBudgetOptimization => _autoBudgetOptimization;
  bool get autoInvestmentSuggestions => _autoInvestmentSuggestions;
  bool get autoExpenseCategorization => _autoExpenseCategorization;
  bool get smartNotifications => _smartNotifications;
  int get analysisFrequencyHours => _analysisFrequencyHours;
  bool get hasAdvisor => _advisor != null;

  /// Initialize AI advisor with API key and providers
  Future<void> initializeAdvisor({
    required String apiKey,
    required BalanceProvider balanceProvider,
    required InvestmentProvider investmentProvider,
    required BudgetProvider budgetProvider,
    required ListProvider listProvider,
    required CategoryProvider categoryProvider,
  }) async {
    try {
      _log('Initializing AI advisor...');

      _advisor = GeminiFinancialAdvisor(
        apiKey: apiKey,
        balanceProvider: balanceProvider,
        investmentProvider: investmentProvider,
        budgetProvider: budgetProvider,
        listProvider: listProvider,
        categoryProvider: categoryProvider,
      );

      _error = null;
      _log('AI advisor initialized successfully');
      notifyListeners();

      // Run initial analysis if enabled
      if (_isAIEnabled) {
        await refreshInsights();
      }
    } catch (e, stackTrace) {
      _logError('Failed to initialize AI advisor', e, stackTrace);
      _error = 'Failed to initialize AI advisor: $e';
      notifyListeners();
    }
  }

  /// Generate fresh insights from AI
  Future<void> refreshInsights({bool forceRefresh = false}) async {
    if (_advisor == null || !_isAIEnabled) {
      _log('AI advisor not available or disabled');
      return;
    }

    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      _log('Refreshing AI insights...');

      final newInsights = await _advisor!.generateFinancialInsights(
        forceRefresh: forceRefresh,
      );

      _insights = newInsights;
      _lastAnalysis = DateTime.now();

      await _cacheInsights();
      await _saveSettings();

      _log('Refreshed ${_insights.length} insights');
    } catch (e, stackTrace) {
      _logError('Failed to refresh insights', e, stackTrace);
      _error = 'Failed to get AI insights: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Execute an actionable insight
  Future<bool> executeInsight(String insightId) async {
    if (_advisor == null) {
      _log('AI advisor not available');
      return false;
    }

    try {
      _log('Executing insight: $insightId');

      final success = await _advisor!.executeInsightAction(insightId);

      if (success) {
        // Mark insight as executed (you might want to add this field to FinancialInsight)
        _log('Successfully executed insight: $insightId');

        // Refresh insights after execution
        await refreshInsights();
      } else {
        _log('Failed to execute insight: $insightId');
      }

      return success;
    } catch (e, stackTrace) {
      _logError('Failed to execute insight', e, stackTrace);
      return false;
    }
  }

  /// Auto-optimize budgets using AI recommendations
  Future<bool> optimizeBudgetsAutomatically() async {
    if (_advisor == null || !_autoBudgetOptimization) {
      return false;
    }

    try {
      _log('Running automatic budget optimization...');

      final success = await _advisor!.optimizeBudgets();

      if (success) {
        _log('Budget optimization completed successfully');
        await refreshInsights(); // Refresh to show new recommendations
      }

      return success;
    } catch (e, stackTrace) {
      _logError('Failed to auto-optimize budgets', e, stackTrace);
      return false;
    }
  }

  /// Get AI suggestion for expense categorization
  Future<String> suggestCategory(String description, double amount) async {
    if (_advisor == null || !_autoExpenseCategorization) {
      return 'Others';
    }

    try {
      return await _advisor!.suggestCategory(description, amount);
    } catch (e, stackTrace) {
      _logError('Failed to suggest category', e, stackTrace);
      return 'Others';
    }
  }

  /// Get spending recommendations
  Future<Map<String, dynamic>> getSpendingRecommendations() async {
    if (_advisor == null) {
      return {};
    }

    try {
      return await _advisor!.getSpendingRecommendations();
    } catch (e, stackTrace) {
      _logError('Failed to get spending recommendations', e, stackTrace);
      return {};
    }
  }

  /// Check if insights need refresh based on frequency settings
  bool shouldRefreshInsights() {
    if (_lastAnalysis == null) return true;

    final hoursSinceLastAnalysis =
        DateTime.now().difference(_lastAnalysis!).inHours;

    return hoursSinceLastAnalysis >= _analysisFrequencyHours;
  }

  /// Auto-refresh insights if needed
  Future<void> autoRefreshIfNeeded() async {
    if (!_isAIEnabled || !shouldRefreshInsights()) {
      return;
    }

    await refreshInsights();
  }

  // Settings management
  void setAIEnabled(bool enabled) {
    _isAIEnabled = enabled;
    _saveSettings();
    notifyListeners();
  }

  void setAutoBudgetOptimization(bool enabled) {
    _autoBudgetOptimization = enabled;
    _saveSettings();
    notifyListeners();
  }

  void setAutoInvestmentSuggestions(bool enabled) {
    _autoInvestmentSuggestions = enabled;
    _saveSettings();
    notifyListeners();
  }

  void setAutoExpenseCategorization(bool enabled) {
    _autoExpenseCategorization = enabled;
    _saveSettings();
    notifyListeners();
  }

  void setSmartNotifications(bool enabled) {
    _smartNotifications = enabled;
    _saveSettings();
    notifyListeners();
  }

  void setAnalysisFrequency(int hours) {
    _analysisFrequencyHours = hours;
    _saveSettings();
    notifyListeners();
  }

  /// Get insights by priority
  List<FinancialInsight> getInsightsByPriority(InsightPriority priority) {
    return _insights.where((insight) => insight.priority == priority).toList();
  }

  /// Get insights by type
  List<FinancialInsight> getInsightsByType(InsightType type) {
    return _insights.where((insight) => insight.type == type).toList();
  }

  /// Get actionable insights
  List<FinancialInsight> get actionableInsights {
    return _insights.where((insight) => insight.isActionable).toList();
  }

  /// Get high priority insights
  List<FinancialInsight> get highPriorityInsights {
    return getInsightsByPriority(InsightPriority.high);
  }

  /// Load settings from SharedPreferences
  Future<void> _loadSettings() async {
    try {
      final settingsJson = _prefs.getString(_settingsKey);
      if (settingsJson != null) {
        final settings = jsonDecode(settingsJson);

        _isAIEnabled = settings['isAIEnabled'] ?? true;
        _autoBudgetOptimization = settings['autoBudgetOptimization'] ?? false;
        _autoInvestmentSuggestions =
            settings['autoInvestmentSuggestions'] ?? false;
        _autoExpenseCategorization =
            settings['autoExpenseCategorization'] ?? true;
        _smartNotifications = settings['smartNotifications'] ?? true;
        _analysisFrequencyHours = settings['analysisFrequencyHours'] ?? 24;

        if (settings['lastAnalysis'] != null) {
          _lastAnalysis = DateTime.parse(settings['lastAnalysis']);
        }

        _log('Settings loaded');
      }
    } catch (e, stackTrace) {
      _logError('Failed to load settings', e, stackTrace);
    }
  }

  /// Save settings to SharedPreferences
  Future<void> _saveSettings() async {
    try {
      final settings = {
        'isAIEnabled': _isAIEnabled,
        'autoBudgetOptimization': _autoBudgetOptimization,
        'autoInvestmentSuggestions': _autoInvestmentSuggestions,
        'autoExpenseCategorization': _autoExpenseCategorization,
        'smartNotifications': _smartNotifications,
        'analysisFrequencyHours': _analysisFrequencyHours,
        'lastAnalysis': _lastAnalysis?.toIso8601String(),
      };

      await _prefs.setString(_settingsKey, jsonEncode(settings));
      _log('Settings saved');
    } catch (e, stackTrace) {
      _logError('Failed to save settings', e, stackTrace);
    }
  }

  /// Load cached insights from SharedPreferences
  Future<void> _loadCachedInsights() async {
    try {
      final insightsJson = _prefs.getString(_insightsKey);
      if (insightsJson != null) {
        final List<dynamic> insightsData = jsonDecode(insightsJson);
        _insights = insightsData
            .map((data) => FinancialInsight.fromJson(data))
            .toList();

        _log('Loaded ${_insights.length} cached insights');
      }
    } catch (e, stackTrace) {
      _logError('Failed to load cached insights', e, stackTrace);
      _insights = [];
    }
  }

  /// Cache insights to SharedPreferences
  Future<void> _cacheInsights() async {
    try {
      final insightsData = _insights
          .map((insight) => {
                'id': insight.id,
                'title': insight.title,
                'description': insight.description,
                'category': insight.category,
                'type': insight.type.name,
                'priority': insight.priority.name,
                'actionData': insight.actionData,
                'recommendedAmount': insight.recommendedAmount,
                'targetCategory': insight.targetCategory,
                'createdAt': insight.createdAt.toIso8601String(),
                'isActionable': insight.isActionable,
              })
          .toList();

      await _prefs.setString(_insightsKey, jsonEncode(insightsData));
      _log('Cached ${_insights.length} insights');
    } catch (e, stackTrace) {
      _logError('Failed to cache insights', e, stackTrace);
    }
  }

  /// Clear all cached data
  Future<void> clearCache() async {
    try {
      await _prefs.remove(_insightsKey);
      _insights.clear();
      _lastAnalysis = null;
      await _saveSettings();

      notifyListeners();
      _log('Cache cleared');
    } catch (e, stackTrace) {
      _logError('Failed to clear cache', e, stackTrace);
    }
  }

  /// Get insights summary for quick overview
  Map<String, int> get insightsSummary {
    final summary = <String, int>{};

    for (final insight in _insights) {
      final type = insight.type.name;
      summary[type] = (summary[type] ?? 0) + 1;
    }

    return summary;
  }

  /// Get insights count by priority
  Map<String, int> get prioritySummary {
    final summary = <String, int>{};

    for (final insight in _insights) {
      final priority = insight.priority.name;
      summary[priority] = (summary[priority] ?? 0) + 1;
    }

    return summary;
  }

  /// Run comprehensive AI analysis and automation
  Future<void> runFullAnalysis() async {
    if (_advisor == null || !_isAIEnabled) {
      _log('AI advisor not available or disabled');
      return;
    }

    try {
      _log('Running full AI analysis...');

      // 1. Refresh insights
      await refreshInsights(forceRefresh: true);

      // 2. Auto-optimize budgets if enabled
      if (_autoBudgetOptimization) {
        await optimizeBudgetsAutomatically();
      }

      // 3. Process high-priority actionable insights
      final highPriorityActionable = _insights
          .where((i) => i.priority == InsightPriority.high && i.isActionable)
          .take(3) // Limit to 3 to avoid overwhelming changes
          .toList();

      for (final insight in highPriorityActionable) {
        if (_autoInvestmentSuggestions &&
            insight.type == InsightType.investment) {
          await executeInsight(insight.id);
        } else if (_autoBudgetOptimization &&
            insight.type == InsightType.budget) {
          await executeInsight(insight.id);
        }
      }

      _log('Full AI analysis completed');
    } catch (e, stackTrace) {
      _logError('Failed to run full analysis', e, stackTrace);
    }
  }

  /// Get personalized financial health score (0-100)
  int getFinancialHealthScore() {
    if (_insights.isEmpty) return 50; // Neutral score if no data

    int score = 70; // Base score

    // Deduct points for high-priority issues
    final highPriorityCount =
        getInsightsByPriority(InsightPriority.high).length;
    score -= highPriorityCount * 10;

    // Deduct points for medium-priority issues
    final mediumPriorityCount =
        getInsightsByPriority(InsightPriority.medium).length;
    score -= mediumPriorityCount * 5;

    // Add points for positive insights (savings, good budget management)
    final savingsInsights = getInsightsByType(InsightType.savings).length;
    score += savingsInsights * 5;

    // Ensure score is within bounds
    return score.clamp(0, 100);
  }

  /// Get quick actions that user can take
  List<Map<String, dynamic>> getQuickActions() {
    final actions = <Map<String, dynamic>>[];

    final actionableInsights =
        _insights.where((i) => i.isActionable).take(5).toList();

    for (final insight in actionableInsights) {
      actions.add({
        'id': insight.id,
        'title': insight.title,
        'description': insight.description,
        'type': insight.type.name,
        'priority': insight.priority.name,
        'amount': insight.recommendedAmount,
        'category': insight.targetCategory,
      });
    }

    return actions;
  }

  void _log(String message) {
    debugPrint('[$_tag] $message');
  }

  void _logError(String message, dynamic error, StackTrace? stackTrace) {
    debugPrint('[$_tag ERROR] $message');
    debugPrint('Error details: $error');
    if (stackTrace != null) {
      debugPrint('Stack trace: $stackTrace');
    }
  }
}
