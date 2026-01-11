import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:wallone/state/balance_provider.dart';
import 'package:wallone/state/investment_provider.dart';
import 'package:wallone/state/budget_provider.dart';
import 'package:wallone/state/list_provider.dart';
import 'package:wallone/state/category_provider.dart';
import 'package:wallone/utils/services/rule_based_advisor.dart';

/// Enhanced provider for managing AI financial advisor functionality with smart insight management
class AIAdvisorProvider with ChangeNotifier {
  /// Underlying advisor instance (rule-based). Gemini support has been removed
  /// and the app uses the local rule-based advisor implementation.
  FinancialAdvisor? _advisor;

  List<FinancialInsight> _insights = [];
  bool _isLoading = false;
  bool _isAIEnabled = false;
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

  AIAdvisorProvider() {
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
    } catch (e) {
      _logError('Error stopping AIScheduler', e, null);
    }
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

  /// Human-friendly advisor type (always 'rule-based' after Gemini removal)
  String get advisorType {
    if (_advisor == null) return 'none';
    return 'rule-based';
  }

  /// Initialize AI advisor and attach required providers.
  /// This app now uses the local rule-based advisor only.
  Future<void> initializeAdvisor({
    required BalanceProvider balanceProvider,
    required InvestmentProvider investmentProvider,
    required BudgetProvider budgetProvider,
    required ListProvider listProvider,
    required CategoryProvider categoryProvider,
  }) async {
    try {
      _log('Initializing AI advisor...');

      // Use rule-based advisor (Gemini removed)
      _log('Using RuleBasedAdvisor (gemini removed)');
      _advisor = RuleBasedAdvisor(
        balanceProvider: balanceProvider,
        investmentProvider: investmentProvider,
        budgetProvider: budgetProvider,
        listProvider: listProvider,
        categoryProvider: categoryProvider,
      );

      _error = null;
      _log('AI advisor initialized successfully');
      _safeNotify();

      // Run initial analysis if enabled AND user is premium
      if (_isAIEnabled && await _isPremiumUser()) {
        await refreshInsights();
      }
    } catch (e, stackTrace) {
      _logError('Failed to initialize AI advisor', e, stackTrace);
      _error = 'Failed to initialize AI advisor: $e';
      _safeNotify();
    }
  }

  /// Check if current user is premium
  Future<bool> _isPremiumUser() async {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) return false;

      final doc =
          await FirebaseFirestore.instance.collection('users').doc(uid).get();
      return doc.data()?['isPremium'] ?? false;
    } catch (e) {
      _logError('Error checking premium status', e, null);
      return false;
    }
  }

  /// Generate fresh insights from AI with smart filtering
  Future<void> refreshInsights({bool forceRefresh = false}) async {
    // Check premium status first
    if (!await _isPremiumUser()) {
      _log('AI insights refresh blocked - user is not premium');
      return;
    }

    if (_advisor == null || !_isAIEnabled) {
      _log('AI advisor not available or disabled');
      return;
    }

    try {
      _isLoading = true;
      _error = null;
      _safeNotify();

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
      _safeNotify();
    }
  }

  /// Execute an actionable insight with customization options
  Future<bool> executeInsight(
    String insightId, {
    String? customName,
    String? customCategory,
    double? customAmount,
  }) async {
    // Check premium status first
    if (!await _isPremiumUser()) {
      _log('Insight execution blocked - user is not premium');
      return false;
    }

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
        _safeNotify();
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
    _safeNotify();
  }

  /// Restore a dismissed insight
  void restoreInsight(String insightId) {
    _dismissedInsightIds.remove(insightId);
    _saveDismissedInsights();

    _log('Restored insight: $insightId');
    _safeNotify();
  }

  void reset() {
    _isAIEnabled = false;
    _autoBudgetOptimization = false;
    _autoInvestmentSuggestions = false;
    notifyListeners();
  }

  Future<void> loadUserSettings(bool isPremium) async {
    if (!isPremium) {
      // Force OFF for free users and disable all AI features
      _isAIEnabled = false;
      _autoBudgetOptimization = false;
      _autoInvestmentSuggestions = false;
      _autoExpenseCategorization = false;
      await _saveSettings();
      notifyListeners();
      return;
    }

    // load settings normally for premium user
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('aiAdvisor')
          .doc('settings')
          .get();

      if (doc.exists) {
        final settings = doc.data();
        _isAIEnabled = settings?['isAIEnabled'] ?? false;
        _autoBudgetOptimization = settings?['autoBudgetOptimization'] ?? false;
        _autoInvestmentSuggestions =
            settings?['autoInvestmentSuggestions'] ?? false;
        _autoExpenseCategorization =
            settings?['autoExpenseCategorization'] ?? true;
      }
      notifyListeners();
    } catch (e, st) {
      _logError('Error loading user settings', e, st);
    }
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
    // Check premium status first
    if (!await _isPremiumUser()) {
      _log('Budget optimization blocked - user is not premium');
      return false;
    }

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

    // Check premium status
    if (!await _isPremiumUser()) {
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
    // Check premium status first
    if (!await _isPremiumUser()) {
      return {};
    }

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

    // Check premium status
    if (!await _isPremiumUser()) {
      return;
    }

    await refreshInsights();
    Future.microtask(() {
      _safeNotify();
    });
  }

  Future<void> setAIEnabled(bool enabled) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    try {
      final doc =
          await FirebaseFirestore.instance.collection('users').doc(uid).get();
      final isPremium = doc.data()?['isPremium'] ?? false;

      if (!isPremium && enabled) {
        // Block non-premium users from enabling AI
        _log('AI enable blocked - user is not premium');
        return;
      }

      _isAIEnabled = enabled;
      await _saveSettings();
      _safeNotify();
    } catch (e, st) {
      _logError('Error setting AI enabled state', e, st);
    }
  }

  Future<void> setAutoBudgetOptimization(bool enabled) async {
    if (!await _isPremiumUser() && enabled) {
      _log('Auto budget optimization blocked - user is not premium');
      return;
    }

    _autoBudgetOptimization = enabled;
    await _saveSettings();
    _safeNotify();
  }

  Future<void> setAutoInvestmentSuggestions(bool enabled) async {
    if (!await _isPremiumUser() && enabled) {
      _log('Auto investment suggestions blocked - user is not premium');
      return;
    }

    _autoInvestmentSuggestions = enabled;
    await _saveSettings();
    _safeNotify();
  }

  Future<void> setAutoExpenseCategorization(bool enabled) async {
    if (!await _isPremiumUser() && enabled) {
      _log('Auto expense categorization blocked - user is not premium');
      return;
    }

    _autoExpenseCategorization = enabled;
    await _saveSettings();
    _safeNotify();
  }

  Future<void> setSmartNotifications(bool enabled) async {
    if (!await _isPremiumUser() && enabled) {
      _log('Smart notifications blocked - user is not premium');
      return;
    }

    _smartNotifications = enabled;
    await _saveSettings();
    _safeNotify();
  }

  Future<void> setAnalysisFrequency(int hours) async {
    _analysisFrequencyHours = hours;
    await _saveSettings();
    _safeNotify();
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
    // Check premium status first
    final isPremium = await _isPremiumUser();
    if (!isPremium) {
      _log('Full analysis blocked — user is not Premium');
      return;
    }

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

  /// Load settings from Firestore
  Future<void> _loadSettings() async {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) {
        _log('No user logged in, skipping settings load');
        return;
      }

      // Check premium status
      final userDoc =
          await FirebaseFirestore.instance.collection('users').doc(uid).get();
      final isPremium = userDoc.data()?['isPremium'] ?? false;

      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('aiAdvisor')
          .doc('settings')
          .get();

      if (doc.exists) {
        final settings = doc.data();

        // Only load AI settings if user is premium
        if (isPremium) {
          _isAIEnabled = settings?['isAIEnabled'] ?? false;
          _autoBudgetOptimization =
              settings?['autoBudgetOptimization'] ?? false;
          _autoInvestmentSuggestions =
              settings?['autoInvestmentSuggestions'] ?? false;
          _autoExpenseCategorization =
              settings?['autoExpenseCategorization'] ?? true;
          _smartNotifications = settings?['smartNotifications'] ?? true;
        } else {
          // Force everything off for non-premium users
          _isAIEnabled = false;
          _autoBudgetOptimization = false;
          _autoInvestmentSuggestions = false;
          _autoExpenseCategorization = false;
          _smartNotifications = false;
        }

        _analysisFrequencyHours = settings?['analysisFrequencyHours'] ?? 24;

        if (settings?['lastAnalysis'] != null) {
          _lastAnalysis = (settings?['lastAnalysis'] as Timestamp?)?.toDate();
        }

        _log('Settings loaded from Firestore (isPremium: $isPremium)');
      }
    } catch (e, stackTrace) {
      _logError('Failed to load settings', e, stackTrace);
    }
  }

  /// Save settings to Firestore
  Future<void> _saveSettings() async {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) {
        _log('No user logged in, skipping settings save');
        return;
      }

      final settings = {
        'isAIEnabled': _isAIEnabled,
        'autoBudgetOptimization': _autoBudgetOptimization,
        'autoInvestmentSuggestions': _autoInvestmentSuggestions,
        'autoExpenseCategorization': _autoExpenseCategorization,
        'smartNotifications': _smartNotifications,
        'analysisFrequencyHours': _analysisFrequencyHours,
        'lastAnalysis': _lastAnalysis,
      };

      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('aiAdvisor')
          .doc('settings')
          .set(settings, SetOptions(merge: true));
      _log('Settings saved to Firestore');
    } catch (e, stackTrace) {
      _logError('Failed to save settings', e, stackTrace);
    }
  }

  /// Load cached insights from Firestore
  Future<void> _loadCachedInsights() async {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) {
        _log('No user logged in, skipping insights load');
        return;
      }

      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('aiAdvisor')
          .doc('insights')
          .get();

      if (doc.exists) {
        final data = doc.data();
        final List<dynamic>? insightsData = data?['insights'];
        if (insightsData != null) {
          _insights = insightsData
              .map((data) => FinancialInsight.fromJson(data))
              .toList();

          _log('Loaded ${_insights.length} insights from Firestore');
        }
      }
    } catch (e, stackTrace) {
      _logError('Failed to load cached insights', e, stackTrace);
      _insights = [];
    }
  }

  /// Cache insights to Firestore
  Future<void> _cacheInsights() async {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) {
        _log('No user logged in, skipping insights cache');
        return;
      }

      final insightsData =
          _insights.map((insight) => insight.toJson()).toList();

      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('aiAdvisor')
          .doc('insights')
          .set({'insights': insightsData}, SetOptions(merge: true));
      _log('Cached ${_insights.length} insights to Firestore');
    } catch (e, stackTrace) {
      _logError('Failed to cache insights', e, stackTrace);
    }
  }

  /// Load execution history from Firestore
  Future<void> _loadExecutionHistory() async {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) {
        _log('No user logged in, skipping execution history load');
        return;
      }

      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('aiAdvisor')
          .doc('executionHistory')
          .get();

      if (doc.exists) {
        final data = doc.data();
        final List<dynamic>? executedIds = data?['executed'];
        if (executedIds != null) {
          _executedInsightIds.addAll(executedIds.cast<String>());
        }

        final List<dynamic>? dismissedIds = data?['dismissed'];
        if (dismissedIds != null) {
          _dismissedInsightIds.addAll(dismissedIds.cast<String>());
        }
      }

      _log(
          'Loaded execution history: ${_executedInsightIds.length} executed, ${_dismissedInsightIds.length} dismissed');
    } catch (e, stackTrace) {
      _logError('Failed to load execution history', e, stackTrace);
    }
  }

  /// Save execution history to Firestore
  Future<void> _saveExecutionHistory() async {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) {
        _log('No user logged in, skipping execution history save');
        return;
      }

      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('aiAdvisor')
          .doc('executionHistory')
          .set({
        'executed': _executedInsightIds.toList(),
        'dismissed': _dismissedInsightIds.toList(),
      }, SetOptions(merge: true));
      _log('Saved execution history to Firestore');
    } catch (e, stackTrace) {
      _logError('Failed to save execution history', e, stackTrace);
    }
  }

  /// Save dismissed insights to Firestore
  Future<void> _saveDismissedInsights() async {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) {
        _log('No user logged in, skipping dismissed insights save');
        return;
      }

      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('aiAdvisor')
          .doc('executionHistory')
          .set({'dismissed': _dismissedInsightIds.toList()},
              SetOptions(merge: true));
      _log('Saved dismissed insights to Firestore');
    } catch (e, stackTrace) {
      _logError('Failed to save dismissed insights', e, stackTrace);
    }
  }

  /// Clear all cached data from Firestore
  Future<void> clearCache() async {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid != null) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .collection('aiAdvisor')
            .doc('insights')
            .delete();
        await FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .collection('aiAdvisor')
            .doc('executionHistory')
            .delete();
      }

      _insights.clear();
      _executedInsightIds.clear();
      _dismissedInsightIds.clear();
      _lastAnalysis = null;

      await _saveSettings();

      _safeNotify();
      _log('Cache cleared from Firestore');
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

  /// Safely notify listeners. If called during the build phase this will
  /// schedule a post-frame callback to avoid calling `notifyListeners()`
  /// synchronously and triggering "setState() or markNeedsBuild() called during build".
  bool _notifyScheduled = false;

  void _safeNotify() {
    // Coalesce repeated notifications into a single post-frame callback.
    if (_notifyScheduled) return;
    _notifyScheduled = true;

    try {
      SchedulerBinding.instance.addPostFrameCallback((_) {
        _notifyScheduled = false;
        try {
          notifyListeners();
        } catch (_) {}
      });
    } catch (_) {
      // Fallback: try notifying synchronously if scheduling fails.
      _notifyScheduled = false;
      try {
        notifyListeners();
      } catch (_) {}
    }
  }
}
