import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:wallone/models/ai_adviser_model.dart';
import 'package:wallone/state/balance_provider.dart';
import 'package:wallone/state/budget_provider.dart';
import 'package:wallone/state/investment_provider.dart';
import 'package:wallone/utils/constants.dart';

// Enhanced offline AI advisor service with better error handling
class OfflineAIAdvisorService {
  static const String baseUrl = "http://localhost:8000";
  static const int timeoutSeconds = 5;

  // Cache for offline fallback
  static List<AIInsight> _cachedInsights = [];
  static DateTime? _lastFetchTime;
  static const int cacheValidityHours = 2;

  /// Fetch insights with comprehensive fallback strategy
  static Future<List<AIInsight>> fetchInsights({
    required double balance,
    required Map<String, dynamic> budgets,
    required Map<String, dynamic> investments,
  }) async {
    print('🔍 Fetching insights - Balance: $balance');
    print('🔍 Budgets: $budgets');
    print('🔍 Investments: $investments');

    try {
      // Try to fetch from server first (with shorter timeout)
      final serverInsights =
          await _fetchFromServer(balance, budgets, investments);
      if (serverInsights.isNotEmpty) {
        print('✅ Got ${serverInsights.length} insights from server');
        _cachedInsights = serverInsights;
        _lastFetchTime = DateTime.now();
        return serverInsights;
      }
    } catch (e) {
      print('⚠️ Server unavailable, falling back to offline AI: $e');
    }

    // Use cached insights if available and recent
    if (_cachedInsights.isNotEmpty && _isCacheValid()) {
      print('📋 Using ${_cachedInsights.length} cached insights');
      return _cachedInsights;
    }

    // Generate offline insights as final fallback
    print('🤖 Generating offline insights...');
    final offlineInsights =
        _generateOfflineInsights(balance, budgets, investments);
    print('✅ Generated ${offlineInsights.length} offline insights');
    return offlineInsights;
  }

  static Future<List<AIInsight>> _fetchFromServer(
    double balance,
    Map<String, dynamic> budgets,
    Map<String, dynamic> investments,
  ) async {
    final body = {
      "balance": balance,
      "budgets": budgets,
      "investments": investments,
    };

    final response = await http
        .post(
          Uri.parse("$baseUrl/generate_insights"),
          headers: {"Content-Type": "application/json"},
          body: jsonEncode(body),
        )
        .timeout(const Duration(seconds: timeoutSeconds));

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return (data["insights"] as List)
          .map((e) => AIInsight.fromJson(e))
          .toList();
    } else {
      throw Exception("Server error: ${response.statusCode}");
    }
  }

  static bool _isCacheValid() {
    if (_lastFetchTime == null) return false;
    final now = DateTime.now();
    final difference = now.difference(_lastFetchTime!);
    return difference.inHours < cacheValidityHours;
  }

  /// Enhanced offline AI logic with comprehensive error handling
  static List<AIInsight> _generateOfflineInsights(
    double balance,
    Map<String, dynamic> budgets,
    Map<String, dynamic> investments,
  ) {
    try {
      final insights = <AIInsight>[];

      print('🧮 Calculating metrics...');
      print(
          'Balance: $balance, Budgets keys: ${budgets.keys}, Investments keys: ${investments.keys}');

      // Calculate key metrics with safe extraction
      final monthlyIncome = _safeExtractBudgetTotal(budgets, 'allocated');
      final monthlyExpenses = _safeExtractBudgetTotal(budgets, 'spent');
      final totalInvestments = _safeExtractInvestmentTotal(investments);

      print(
          '📊 Calculated - Income: $monthlyIncome, Expenses: $monthlyExpenses, Investments: $totalInvestments');

      // Generate insights even with minimal data
      if (balance > 0 || monthlyIncome > 0) {
        // 1. Emergency Fund Analysis
        insights.addAll(_analyzeEmergencyFund(balance, monthlyExpenses));

        // 2. Savings Rate Analysis
        if (monthlyIncome > 0) {
          insights.addAll(_analyzeSavingsRate(monthlyIncome, monthlyExpenses));
        }

        // 3. Budget Optimization
        if (budgets.isNotEmpty) {
          insights.addAll(_analyzeBudgets(budgets));
        }

        // 4. Investment Opportunities
        insights.addAll(
            _analyzeInvestments(balance, totalInvestments, monthlyIncome));

        // 5. Behavioral Insights
        insights.addAll(_generateBehavioralInsights(balance, monthlyIncome));

        // 6. Basic financial tips if no specific insights
        if (insights.isEmpty) {
          insights.addAll(_generateBasicInsights(balance, monthlyIncome));
        }
      } else {
        // Generate basic insights for new users
        insights.addAll(_generateNewUserInsights());
      }

      // Sort by priority and return top insights
      insights.sort((a, b) {
        final priorityComparison = _getPriorityValue(b.priority)
            .compareTo(_getPriorityValue(a.priority));
        if (priorityComparison != 0) return priorityComparison;
        return b.confidence.compareTo(a.confidence);
      });

      final finalInsights = insights.take(6).toList();
      print('✅ Returning ${finalInsights.length} insights');
      return finalInsights;
    } catch (e) {
      print('❌ Error generating offline insights: $e');
      // Return basic fallback insights
      return _generateFallbackInsights();
    }
  }

  // Safe data extraction methods
  static double _safeExtractBudgetTotal(
      Map<String, dynamic> budgets, String field) {
    try {
      return budgets.values
          .map((b) => (b is Map && b[field] is num)
              ? (b[field] as num).toDouble()
              : 0.0)
          .fold(0.0, (a, b) => a + b);
    } catch (e) {
      print('⚠️ Error extracting budget $field: $e');
      return 0.0;
    }
  }

  static double _safeExtractInvestmentTotal(Map<String, dynamic> investments) {
    try {
      return investments.values
          .map((i) => (i is Map && i['current_value'] is num)
              ? (i['current_value'] as num).toDouble()
              : (i is Map && i['value'] is num)
                  ? (i['value'] as num).toDouble()
                  : (i is num)
                      ? (i as num).toDouble()
                      : 0.0)
          .fold(0.0, (a, b) => a + b);
    } catch (e) {
      print('⚠️ Error extracting investments: $e');
      return 0.0;
    }
  }

  static int _getPriorityValue(AdvicePriority priority) {
    switch (priority) {
      case AdvicePriority.critical:
        return 4;
      case AdvicePriority.high:
        return 3;
      case AdvicePriority.medium:
        return 2;
      case AdvicePriority.low:
        return 1;
    }
  }

  static List<AIInsight> _analyzeEmergencyFund(
      double balance, double monthlyExpenses) {
    final insights = <AIInsight>[];

    if (balance <= 0) return insights;

    final emergencyMonths = monthlyExpenses > 0
        ? balance / monthlyExpenses
        : balance / 25000; // Assume ₹25k monthly expense

    if (emergencyMonths < 3) {
      insights.add(AIInsight(
        id: 'emergency_critical_${DateTime.now().millisecondsSinceEpoch}',
        title: 'Build Emergency Fund',
        description:
            'You have ${emergencyMonths.toStringAsFixed(1)} months of emergency funds. Aim for 6 months of expenses for financial security.',
        type: AdviceType.saving,
        priority: AdvicePriority.critical,
        confidence: 0.95,
        icon: '🚨',
        actionable: true,
        metadata: {
          'current_months': emergencyMonths,
          'target_months': 6.0,
        },
      ));
    } else if (emergencyMonths < 6) {
      insights.add(AIInsight(
        id: 'emergency_boost_${DateTime.now().millisecondsSinceEpoch}',
        title: 'Boost Emergency Fund',
        description:
            'Good progress! You have ${emergencyMonths.toStringAsFixed(1)} months covered. Continue building to reach 6-month target.',
        type: AdviceType.saving,
        priority: AdvicePriority.high,
        confidence: 0.88,
        icon: '📈',
        actionable: true,
        metadata: {
          'current_months': emergencyMonths,
        },
      ));
    } else {
      insights.add(AIInsight(
        id: 'emergency_good_${DateTime.now().millisecondsSinceEpoch}',
        title: 'Great Emergency Fund!',
        description:
            'Excellent! Your ${emergencyMonths.toStringAsFixed(1)} months emergency fund provides good security. Consider investing surplus funds.',
        type: AdviceType.investment,
        priority: AdvicePriority.medium,
        confidence: 0.85,
        icon: '✅',
        actionable: true,
        metadata: {
          'current_months': emergencyMonths,
        },
      ));
    }

    return insights;
  }

  static List<AIInsight> _analyzeSavingsRate(
      double monthlyIncome, double monthlyExpenses) {
    final insights = <AIInsight>[];
    final savingsRate = monthlyIncome > 0
        ? (monthlyIncome - monthlyExpenses) / monthlyIncome
        : 0;

    if (savingsRate < 0.10) {
      insights.add(AIInsight(
        id: 'savings_low_${DateTime.now().millisecondsSinceEpoch}',
        title: 'Improve Savings Rate',
        description:
            'Your savings rate is ${(savingsRate * 100).toStringAsFixed(1)}%. Try to save at least 20% of your income for better financial health.',
        type: AdviceType.saving,
        priority: AdvicePriority.high,
        confidence: 0.90,
        icon: '📉',
        actionable: true,
        metadata: {
          'current_rate': savingsRate,
          'target_rate': 0.20,
        },
      ));
    } else if (savingsRate > 0.30) {
      insights.add(AIInsight(
        id: 'savings_excellent_${DateTime.now().millisecondsSinceEpoch}',
        title: 'Excellent Savings!',
        description:
            'Amazing! Your ${(savingsRate * 100).toStringAsFixed(1)}% savings rate is outstanding. Consider investing for wealth growth.',
        type: AdviceType.investment,
        priority: AdvicePriority.medium,
        confidence: 0.85,
        icon: '⭐',
        actionable: true,
        metadata: {
          'current_rate': savingsRate,
        },
      ));
    }

    return insights;
  }

  static List<AIInsight> _analyzeBudgets(Map<String, dynamic> budgets) {
    final insights = <AIInsight>[];

    try {
      // Find overspending categories
      String? overspentCategory;
      double maxOverspend = 0;

      budgets.forEach((category, budget) {
        if (budget is Map) {
          final allocated = (budget['allocated'] as num?)?.toDouble() ?? 0;
          final spent = (budget['spent'] as num?)?.toDouble() ?? 0;

          if (allocated > 0) {
            final utilization = spent / allocated;
            if (utilization > 1.0 && utilization > maxOverspend) {
              maxOverspend = utilization;
              overspentCategory = category;
            }
          }
        }
      });

      if (overspentCategory != null) {
        insights.add(AIInsight(
          id: 'overspend_${DateTime.now().millisecondsSinceEpoch}',
          title: 'Budget Alert: ${_formatCategory(overspentCategory!)}',
          description:
              'You\'ve exceeded your ${_formatCategory(overspentCategory!)} budget. Consider reviewing your spending in this category.',
          type: AdviceType.budget,
          priority: AdvicePriority.high,
          confidence: 0.92,
          icon: '⚠️',
          actionable: true,
          metadata: {
            'category': overspentCategory,
            'utilization': maxOverspend,
          },
        ));
      }
    } catch (e) {
      print('⚠️ Error analyzing budgets: $e');
    }

    return insights;
  }

  static List<AIInsight> _analyzeInvestments(
      double balance, double totalInvestments, double monthlyIncome) {
    final insights = <AIInsight>[];
    final totalWealth = balance + totalInvestments;
    final investmentRatio =
        totalWealth > 0 ? totalInvestments / totalWealth : 0;

    if (investmentRatio < 0.10 && balance > 10000) {
      insights.add(AIInsight(
        id: 'invest_start_${DateTime.now().millisecondsSinceEpoch}',
        title: 'Start Investing',
        description:
            'Consider starting investments with SIPs. Even small monthly investments can grow significantly over time through compounding.',
        type: AdviceType.investment,
        priority: AdvicePriority.high,
        confidence: 0.87,
        icon: '🚀',
        actionable: true,
        metadata: {
          'current_investment_ratio': investmentRatio,
          'target_ratio': 0.25,
        },
      ));
    } else if (investmentRatio > 0.10 && investmentRatio < 0.25) {
      insights.add(AIInsight(
        id: 'invest_boost_${DateTime.now().millisecondsSinceEpoch}',
        title: 'Increase Investments',
        description:
            'Great start! Your ${(investmentRatio * 100).toStringAsFixed(1)}% investment ratio can be increased to 25-30% for better wealth building.',
        type: AdviceType.investment,
        priority: AdvicePriority.medium,
        confidence: 0.82,
        icon: '📊',
        actionable: true,
        metadata: {
          'current_ratio': investmentRatio,
          'target_ratio': 0.25,
        },
      ));
    }

    return insights;
  }

  static List<AIInsight> _generateBehavioralInsights(
      double balance, double monthlyIncome) {
    final insights = <AIInsight>[];
    final currentMonth = DateTime.now().month;

    // Seasonal spending insights
    final highSpendingMonths = [11, 12, 6, 7]; // Nov, Dec, Jun, Jul
    if (highSpendingMonths.contains(currentMonth)) {
      final monthName = _getMonthName(currentMonth);

      insights.add(AIInsight(
        id: 'seasonal_${DateTime.now().millisecondsSinceEpoch}',
        title: '$monthName Spending Alert',
        description:
            'Spending typically increases during $monthName due to holidays/vacations. Plan your budget accordingly.',
        type: AdviceType.behavioral,
        priority: AdvicePriority.medium,
        confidence: 0.75,
        icon: '🎯',
        actionable: true,
        metadata: {
          'month': monthName,
        },
      ));
    }

    // Automation suggestion
    if (monthlyIncome > 25000) {
      insights.add(AIInsight(
        id: 'automate_${DateTime.now().millisecondsSinceEpoch}',
        title: 'Automate Your Savings',
        description:
            'Set up automatic transfers to savings and investments on your salary day. Automation helps build wealth consistently.',
        type: AdviceType.behavioral,
        priority: AdvicePriority.medium,
        confidence: 0.85,
        icon: '🤖',
        actionable: true,
        metadata: {
          'monthly_income': monthlyIncome,
        },
      ));
    }

    return insights;
  }

  static List<AIInsight> _generateBasicInsights(
      double balance, double monthlyIncome) {
    final insights = <AIInsight>[];

    insights.add(AIInsight(
      id: 'basic_1_${DateTime.now().millisecondsSinceEpoch}',
      title: 'Track Your Expenses',
      description:
          'Start by tracking all your expenses for a month. This helps identify spending patterns and areas for improvement.',
      type: AdviceType.budget,
      priority: AdvicePriority.medium,
      confidence: 0.80,
      icon: '📝',
      actionable: true,
      metadata: {},
    ));

    insights.add(AIInsight(
      id: 'basic_2_${DateTime.now().millisecondsSinceEpoch}',
      title: 'Follow 50-30-20 Rule',
      description:
          'Allocate 50% for needs, 30% for wants, and 20% for savings. This simple rule helps maintain financial balance.',
      type: AdviceType.behavioral,
      priority: AdvicePriority.medium,
      confidence: 0.75,
      icon: '🎯',
      actionable: true,
      metadata: {},
    ));

    return insights;
  }

  static List<AIInsight> _generateNewUserInsights() {
    return [
      AIInsight(
        id: 'welcome_${DateTime.now().millisecondsSinceEpoch}',
        title: 'Welcome to WallOne!',
        description:
            'Add your income, expenses, and savings data to get personalized financial insights and recommendations.',
        type: AdviceType.budget,
        priority: AdvicePriority.medium,
        confidence: 0.90,
        icon: '👋',
        actionable: true,
        metadata: {},
      ),
      AIInsight(
        id: 'setup_${DateTime.now().millisecondsSinceEpoch}',
        title: 'Set Up Your Budget',
        description:
            'Create budgets for different categories like food, transport, and entertainment to better manage your finances.',
        type: AdviceType.budget,
        priority: AdvicePriority.high,
        confidence: 0.85,
        icon: '🏁',
        actionable: true,
        metadata: {},
      ),
    ];
  }

  static List<AIInsight> _generateFallbackInsights() {
    return [
      AIInsight(
        id: 'fallback_${DateTime.now().millisecondsSinceEpoch}',
        title: 'Financial Health Check',
        description:
            'Regular financial reviews help maintain good money habits. Check your spending patterns monthly.',
        type: AdviceType.budget,
        priority: AdvicePriority.low,
        confidence: 0.70,
        icon: '🔍',
        actionable: false,
        metadata: {},
      ),
    ];
  }

  // Utility methods
  static String _formatCategory(String category) {
    return category
        .replaceAll('_', ' ')
        .split(' ')
        .map((word) =>
            word.isEmpty ? '' : word[0].toUpperCase() + word.substring(1))
        .join(' ');
  }

  static String _getMonthName(int month) {
    const months = [
      '',
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec'
    ];
    return months[month];
  }
}

// Provider extension methods - Add these to your provider classes or create wrapper methods
extension BudgetProviderExtension on BudgetProvider {
  Map<String, dynamic> toJson() {
    // Replace this with your actual budget data structure
    // This is just an example - adjust based on your provider's actual data
    try {
      return {
        'food': {'allocated': 15000, 'spent': 12000},
        'transport': {'allocated': 8000, 'spent': 7500},
        'entertainment': {'allocated': 5000, 'spent': 6200},
        'utilities': {'allocated': 3000, 'spent': 2800},
        'shopping': {'allocated': 4000, 'spent': 3500},
        // Add more categories based on your actual data structure
      };
    } catch (e) {
      print('⚠️ Error converting budget to JSON: $e');
      return {};
    }
  }
}

extension InvestmentProviderExtension on InvestmentProvider {
  Map<String, dynamic> toJson() {
    // Replace this with your actual investment data structure
    try {
      return {
        'mutual_funds': {'current_value': 250000, 'invested': 200000},
        'stocks': {'current_value': 150000, 'invested': 120000},
        'ppf': {'current_value': 80000, 'invested': 75000},
        'fd': {'current_value': 100000, 'invested': 95000},
        // Add more investment types based on your actual data structure
      };
    } catch (e) {
      print('⚠️ Error converting investments to JSON: $e');
      return {};
    }
  }
}

// Enhanced Flutter Widget with better error handling
class EnhancedAutomatedAIAdvisor extends StatefulWidget {
  const EnhancedAutomatedAIAdvisor({super.key});

  @override
  State<EnhancedAutomatedAIAdvisor> createState() =>
      _EnhancedAutomatedAIAdvisorState();
}

class _EnhancedAutomatedAIAdvisorState extends State<EnhancedAutomatedAIAdvisor>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fadeAnimation;
  int _currentInsightIndex = 0;
  bool _busy = false;
  bool _isOffline = false;
  List<AIInsight> _insights = [];
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _fadeAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    );
    _controller.forward();

    // Load insights after a short delay to ensure providers are ready
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadInsights();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _loadInsights() async {
    if (!mounted) return;

    try {
      setState(() {
        _busy = true;
        _errorMessage = null;
      });

      final balProv = context.read<BalanceProvider>();
      final budProv = context.read<BudgetProvider>();
      final invProv = context.read<InvestmentProvider>();

      print('🔄 Loading insights...');
      print('Balance Provider: ${balProv.totalBalance}');

      // Get data with fallbacks
      final balance = balProv.totalBalance ?? 0.0;
      final budgets = budProv.toJson();
      final investments = invProv.toJson();

      final insights = await OfflineAIAdvisorService.fetchInsights(
        balance: balance,
        budgets: budgets,
        investments: investments,
      );

      if (mounted) {
        setState(() {
          _insights = insights;
          _busy = false;
          _isOffline =
              insights.isNotEmpty && insights.first.id.contains('offline');
        });
      }
    } catch (e) {
      print('❌ Error loading insights: $e');
      if (mounted) {
        setState(() {
          _busy = false;
          _isOffline = true;
          _errorMessage = e.toString();
          // Provide fallback insights
          _insights = [
            AIInsight(
              id: 'error_fallback_${DateTime.now().millisecondsSinceEpoch}',
              title: 'Getting Started',
              description:
                  'Add your financial data to receive personalized insights and recommendations.',
              type: AdviceType.budget,
              priority: AdvicePriority.medium,
              confidence: 0.80,
              icon: '🏁',
              actionable: true,
              metadata: {},
            ),
          ];
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_busy) {
      return _buildLoadingState();
    }

    if (_insights.isEmpty) {
      return _buildEmptyState();
    }

    final insight =
        _insights[_currentInsightIndex.clamp(0, _insights.length - 1)];

    return FadeTransition(
      opacity: _fadeAnimation,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: boxColor(context),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: shadowColor(context).withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(context),
            const SizedBox(height: 16),
            _buildCurrentInsight(context, insight),
            if (_insights.length > 1) ...[
              const SizedBox(height: 12),
              _buildInsightNavigation(context),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingState() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: boxColor(context),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          CircularProgressIndicator(color: primaryColor(context)),
          const SizedBox(height: 16),
          Text(
            "Analyzing your finances...",
            style: GoogleFonts.outfit(
              color: cardTextColor(context),
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: boxColor(context),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Icon(
            _errorMessage != null ? Icons.error_outline : Icons.assistant,
            color: _errorMessage != null
                ? Colors.orange
                : primaryColor(context).withOpacity(0.5),
            size: 32,
          ),
          const SizedBox(height: 12),
          Text(
            _errorMessage != null
                ? "Error Loading Insights"
                : "No insights available",
            style: GoogleFonts.outfit(
              color: cardTextColor(context),
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          if (_errorMessage != null) ...[
            Text(
              "Using offline mode",
              style: GoogleFonts.outfit(
                color: cardTextColor(context).withOpacity(0.7),
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 8),
          ],
          GestureDetector(
            onTap: _loadInsights,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: primaryColor(context).withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                "Tap to refresh",
                style: GoogleFonts.outfit(
                  color: primaryColor(context),
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: primaryColor(context).withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            _isOffline ? Icons.offline_bolt : Icons.assistant,
            color: primaryColor(context),
            size: screenWidth / 25,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "WallOne Smart AI",
                style: GoogleFonts.outfit(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: cardTextColor(context),
                ),
              ),
              if (_isOffline || _errorMessage != null)
                Text(
                  _isOffline ? "Offline Mode" : "Error Mode",
                  style: GoogleFonts.outfit(
                    fontSize: 12,
                    color: cardTextColor(context).withOpacity(0.6),
                  ),
                ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: primaryColor(context).withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            "${_insights.length}",
            style: GoogleFonts.outfit(
              color: primaryColor(context),
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        const SizedBox(width: 8),
        GestureDetector(
          onTap: _loadInsights,
          child: Icon(
            Icons.refresh,
            color: primaryColor(context),
            size: 20,
          ),
        ),
      ],
    );
  }

  Widget _buildCurrentInsight(BuildContext context, AIInsight insight) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      child: Container(
        key: ValueKey(_currentInsightIndex),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: _getPriorityColor(insight.priority).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    insight.icon,
                    style: const TextStyle(fontSize: 20),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: _getPriorityColor(insight.priority),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              insight.priority
                                  .toString()
                                  .split('.')
                                  .last
                                  .toUpperCase(),
                              style: GoogleFonts.outfit(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: cardTextColor(context).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              '${(insight.confidence * 100).toInt()}%',
                              style: GoogleFonts.outfit(
                                color: cardTextColor(context).withOpacity(0.7),
                                fontSize: 10,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        insight.title,
                        style: GoogleFonts.outfit(
                          color: primaryColor(context),
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          height: 1.3,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        insight.description,
                        style: GoogleFonts.outfit(
                          color: cardTextColor(context).withOpacity(0.8),
                          fontSize: 14,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (insight.actionable) ...[
              const SizedBox(height: 12),
              _buildActionButton(context, insight),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton(BuildContext context, AIInsight insight) {
    return GestureDetector(
      onTap: _busy ? null : () => _handleAction(context, insight),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              _getPriorityColor(insight.priority).withOpacity(0.8),
              _getPriorityColor(insight.priority),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: _getPriorityColor(insight.priority).withOpacity(0.3),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.auto_fix_high,
              color: Colors.white,
              size: 16,
            ),
            const SizedBox(width: 8),
            Text(
              insight.actionHint ?? "Take Action",
              style: GoogleFonts.outfit(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInsightNavigation(BuildContext context) {
    return Row(
      children: [
        Row(
          children: List.generate(
            _insights.length > 5 ? 5 : _insights.length,
            (index) {
              final isActive = index == (_currentInsightIndex % 5);
              return Container(
                width: isActive ? 20 : 8,
                height: 8,
                margin: const EdgeInsets.only(right: 6),
                decoration: BoxDecoration(
                  color: isActive
                      ? primaryColor(context)
                      : cardTextColor(context).withOpacity(0.3),
                  borderRadius: BorderRadius.circular(4),
                ),
              );
            },
          ),
        ),
        const Spacer(),
        if (_currentInsightIndex > 0)
          _buildNavButton(
            context,
            Icons.chevron_left_rounded,
            () => setState(() => _currentInsightIndex--),
          ),
        const SizedBox(width: 8),
        if (_currentInsightIndex < _insights.length - 1)
          _buildNavButton(
            context,
            Icons.chevron_right_rounded,
            () => setState(() => _currentInsightIndex++),
          ),
      ],
    );
  }

  Widget _buildNavButton(
      BuildContext context, IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: primaryColor(context).withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(
          icon,
          color: primaryColor(context),
          size: 18,
        ),
      ),
    );
  }

  Color _getPriorityColor(AdvicePriority priority) {
    switch (priority) {
      case AdvicePriority.critical:
        return Colors.red;
      case AdvicePriority.high:
        return Colors.orange;
      case AdvicePriority.medium:
        return Colors.blue;
      case AdvicePriority.low:
        return Colors.green;
    }
  }

  Future<void> _handleAction(BuildContext context, AIInsight insight) async {
    setState(() => _busy = true);

    // Simulate action processing
    await Future.delayed(const Duration(seconds: 1));

    // Show success message
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle, color: Colors.white, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  "Action noted: ${insight.title}",
                  style: GoogleFonts.outfit(fontSize: 14),
                ),
              ),
            ],
          ),
          backgroundColor: Colors.green.withOpacity(0.9),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          duration: const Duration(seconds: 2),
        ),
      );
    }

    setState(() => _busy = false);
  }
}

double pow(double base, int exponent) {
  return math.pow(base, exponent).toDouble();
}
