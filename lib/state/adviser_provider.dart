import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

import 'package:wallone/state/balance_provider.dart';
import 'package:wallone/state/investment_provider.dart';
import 'package:wallone/state/budget_provider.dart';
import 'package:wallone/state/list_provider.dart';
import 'package:wallone/state/category_provider.dart';
import 'package:wallone/utils/services/gemini_service.dart';

/// Enhanced provider for managing AI financial advisor functionality with smart insight management
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

  // Insight execution tracking
  final Set<String> _executedInsightIds = {};
  final Set<String> _dismissedInsightIds = {};

  static const String _tag = 'AIAdvisorProvider';
  static const String _insightsKey = 'ai_insights';
  static const String _settingsKey = 'ai_settings';
  static const String _executedInsightsKey = 'executed_insights';
  static const String _dismissedInsightsKey = 'dismissed_insights';

  AIAdvisorProvider(this._prefs) {
    // Run async initialization without blocking the constructor.
    _init();
  }

  Future<void> _init() async {
    try {
      await _loadSettings();
      await _loadCachedInsights();
      await _loadExecutionHistory();
    } catch (e, st) {
      _logError('Initialization failed', e, st);
    }
  }

  @override
  void dispose() {
    // Stop any background AI scheduler when provider is disposed.
    try {
      AIScheduler.stop();
    } catch (_) {}
    super.dispose();
  }

  // Enhanced getters
  List<FinancialInsight> get insights => _insights;
  List<FinancialInsight> get activeInsights => _insights
      .where((insight) =>
          !insight.isExecuted && !_dismissedInsightIds.contains(insight.id))
      .toList();
  List<FinancialInsight> get executedInsights =>
      _insights.where((insight) => insight.isExecuted).toList();
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

  /// Generate fresh insights from AI with smart filtering
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

      _log('Refreshed ${activeInsights.length} active insights');
    } catch (e, stackTrace) {
      _logError('Failed to refresh insights', e, stackTrace);
      _error = 'Failed to get AI insights: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Execute an actionable insight with customization options
  Future<bool> executeInsight(
    String insightId, {
    String? customName,
    String? customCategory,
    double? customAmount,
  }) async {
    if (_advisor == null) {
      _log('AI advisor not available');
      return false;
    }

    try {
      _log('Executing insight: $insightId');

      final success = await _advisor!.executeInsightAction(
        insightId,
        customName: customName,
        customAmount: customAmount,
      );

      if (success) {
        _executedInsightIds.add(insightId);
        await _saveExecutionHistory();

        _log('Successfully executed insight: $insightId');

        // Update insights list
        final insightIndex = _insights.indexWhere((i) => i.id == insightId);
        if (insightIndex != -1) {
          _insights[insightIndex] = _insights[insightIndex].copyWith(
            isExecuted: true,
            executedAt: DateTime.now(),
          );
        }

        // Trigger refresh to get new insights after execution
        await refreshInsights(forceRefresh: true);
        notifyListeners();
      } else {
        _log('Failed to execute insight: $insightId');
      }

      return success;
    } catch (e, stackTrace) {
      _logError('Failed to execute insight', e, stackTrace);
      return false;
    }
  }

  /// Dismiss an insight (remove from active list without executing)
  void dismissInsight(String insightId) {
    if (_advisor != null) {
      _advisor!.dismissInsight(insightId);
    }

    _dismissedInsightIds.add(insightId);
    _saveDismissedInsights();

    _log('Dismissed insight: $insightId');
    notifyListeners();
  }

  /// Restore a dismissed insight
  void restoreInsight(String insightId) {
    _dismissedInsightIds.remove(insightId);
    _saveDismissedInsights();

    _log('Restored insight: $insightId');
    notifyListeners();
  }

  /// Get insight execution preview (what will happen when executed)
  Map<String, dynamic> getInsightExecutionPreview(String insightId) {
    final insight = _insights.firstWhere(
      (i) => i.id == insightId,
      orElse: () => throw Exception('Insight not found'),
    );

    final preview = <String, dynamic>{
      'type': insight.type.name,
      'action': insight.actionData['action'] ?? 'unknown',
      'recommendedName': _getRecommendedName(insight),
      'recommendedCategory': insight.targetCategory ?? insight.category,
      'recommendedAmount': insight.recommendedAmount,
      'description': insight.description,
    };

    return preview;
  }

  /// Get recommended name for insight execution
  String _getRecommendedName(FinancialInsight insight) {
    // Try different sources for the name
    final actionData = insight.actionData;

    if (actionData['parameters'] is Map) {
      final params = actionData['parameters'] as Map;
      if (params['name'] is String && params['name'].isNotEmpty) {
        return params['name'];
      }
    }

    if (actionData['name'] is String && actionData['name'].isNotEmpty) {
      return actionData['name'];
    }

    // Generate name based on type and category
    switch (insight.type) {
      case InsightType.budget:
        return '${insight.targetCategory ?? insight.category} Budget';
      case InsightType.investment:
        return 'Smart Investment';
      case InsightType.savings:
        return 'Emergency Savings';
      default:
        return insight.title.isNotEmpty ? insight.title : 'Financial Goal';
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

  // Enhanced settings management
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
    return activeInsights
        .where((insight) => insight.priority == priority)
        .toList();
  }

  /// Get insights by type
  List<FinancialInsight> getInsightsByType(InsightType type) {
    return activeInsights.where((insight) => insight.type == type).toList();
  }

  /// Get actionable insights
  List<FinancialInsight> get actionableInsights {
    return activeInsights.where((insight) => insight.isActionable).toList();
  }

  /// Get high priority insights
  List<FinancialInsight> get highPriorityInsights {
    return getInsightsByPriority(InsightPriority.high);
  }

  /// Get insights summary for quick overview
  Map<String, int> get insightsSummary {
    final summary = <String, int>{};

    for (final insight in activeInsights) {
      final type = insight.type.name;
      summary[type] = (summary[type] ?? 0) + 1;
    }

    return summary;
  }

  /// Get insights count by priority
  Map<String, int> get prioritySummary {
    final summary = <String, int>{};

    for (final insight in activeInsights) {
      final priority = insight.priority.name;
      summary[priority] = (summary[priority] ?? 0) + 1;
    }

    return summary;
  }

  /// Get personalized financial health score (0-100)
  int getFinancialHealthScore() {
    if (activeInsights.isEmpty) return 0; // Neutral baseline

    double score = 70; // Start with a healthy baseline

    // --- NEGATIVE FACTORS ---

    // High-priority issues should have stronger impact
    final highPriorityCount =
        getInsightsByPriority(InsightPriority.high).length;
    score -= (highPriorityCount * 12).clamp(0, 40); // max 40 pts penalty

    // Medium-priority issues have moderate impact
    final mediumPriorityCount =
        getInsightsByPriority(InsightPriority.medium).length;
    score -= (mediumPriorityCount * 6).clamp(0, 30); // max 30 pts penalty

    // --- POSITIVE FACTORS ---

    // Positive insights like savings, optimized spending, etc.
    final savingsInsights = getInsightsByType(InsightType.savings).length;
    score += (savingsInsights * 5).clamp(0, 25); // cap to prevent overflow

    // Reward for executed insights (user takes actions)
    final executedCount = executedInsights.length;
    score += (executedCount * 3).clamp(0, 15);

    // --- NORMALIZATION ---

    // Smooth final result within bounds
    return score.round().clamp(0, 100);
  }

  /// Get quick actions that user can take
  List<Map<String, dynamic>> getQuickActions() {
    final actions = <Map<String, dynamic>>[];

    final topActionableInsights = actionableInsights
        .where((i) => i.priority == InsightPriority.high)
        .take(3)
        .toList();

    // Add medium priority if we need more actions
    if (topActionableInsights.length < 3) {
      final mediumPriorityInsights = actionableInsights
          .where((i) => i.priority == InsightPriority.medium)
          .take(3 - topActionableInsights.length)
          .toList();
      topActionableInsights.addAll(mediumPriorityInsights);
    }

    for (final insight in topActionableInsights) {
      actions.add({
        'id': insight.id,
        'title': insight.title,
        'description': insight.description,
        'type': insight.type.name,
        'priority': insight.priority.name,
        'amount': insight.recommendedAmount,
        'category': insight.targetCategory,
        'recommendedName': _getRecommendedName(insight),
      });
    }

    return actions;
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

      // 3. Process high-priority actionable insights automatically
      final highPriorityActionable = activeInsights
          .where((i) => i.priority == InsightPriority.high && i.isActionable)
          .take(2) // Limit to 2 to avoid overwhelming changes
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
      final insightsData =
          _insights.map((insight) => insight.toJson()).toList();

      await _prefs.setString(_insightsKey, jsonEncode(insightsData));
      _log('Cached ${_insights.length} insights');
    } catch (e, stackTrace) {
      _logError('Failed to cache insights', e, stackTrace);
    }
  }

  /// Load execution history
  Future<void> _loadExecutionHistory() async {
    try {
      final executedJson = _prefs.getString(_executedInsightsKey);
      if (executedJson != null) {
        final List<dynamic> executedIds = jsonDecode(executedJson);
        _executedInsightIds.addAll(executedIds.cast<String>());
      }

      final dismissedJson = _prefs.getString(_dismissedInsightsKey);
      if (dismissedJson != null) {
        final List<dynamic> dismissedIds = jsonDecode(dismissedJson);
        _dismissedInsightIds.addAll(dismissedIds.cast<String>());
      }

      _log(
          'Loaded execution history: ${_executedInsightIds.length} executed, ${_dismissedInsightIds.length} dismissed');
    } catch (e, stackTrace) {
      _logError('Failed to load execution history', e, stackTrace);
    }
  }

  /// Save execution history
  Future<void> _saveExecutionHistory() async {
    try {
      await _prefs.setString(
          _executedInsightsKey, jsonEncode(_executedInsightIds.toList()));
      _log('Saved execution history');
    } catch (e, stackTrace) {
      _logError('Failed to save execution history', e, stackTrace);
    }
  }

  /// Save dismissed insights
  Future<void> _saveDismissedInsights() async {
    try {
      await _prefs.setString(
          _dismissedInsightsKey, jsonEncode(_dismissedInsightIds.toList()));
      _log('Saved dismissed insights');
    } catch (e, stackTrace) {
      _logError('Failed to save dismissed insights', e, stackTrace);
    }
  }

  /// Clear all cached data
  Future<void> clearCache() async {
    try {
      await _prefs.remove(_insightsKey);
      await _prefs.remove(_executedInsightsKey);
      await _prefs.remove(_dismissedInsightsKey);

      _insights.clear();
      _executedInsightIds.clear();
      _dismissedInsightIds.clear();
      _lastAnalysis = null;

      await _saveSettings();

      notifyListeners();
      _log('Cache cleared');
    } catch (e, stackTrace) {
      _logError('Failed to clear cache', e, stackTrace);
    }
  }

  /// Get insights statistics
  Map<String, dynamic> getInsightsStatistics() {
    return {
      'total': _insights.length,
      'active': activeInsights.length,
      'executed': executedInsights.length,
      'dismissed': _dismissedInsightIds.length,
      'actionable': actionableInsights.length,
      'highPriority': highPriorityInsights.length,
      'financialHealthScore': getFinancialHealthScore(),
      'lastAnalysis': _lastAnalysis?.toIso8601String(),
    };
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
