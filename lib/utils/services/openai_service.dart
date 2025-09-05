// // lib/services/smart_insights_service.dart
// import 'dart:convert';
// import 'dart:math';
// import 'package:http/http.dart' as http;

// class SmartInsightsService {
//   // Free API endpoints
//   static const String _exchangeRateAPI =
//       'https://api.exchangerate-api.com/v4/latest/USD';
//   static const String _stockAPI =
//       'https://api.polygon.io/v2/aggs/ticker/AAPL/prev';
//   static const String _cryptoAPI =
//       'https://api.coingecko.com/api/v3/simple/price';
//   static const String _newsAPI = 'https://newsapi.org/v2/everything';

//   // Financial calculations and insights
//   static Map<String, dynamic> calculateFinancialScore(
//     double totalBalance,
//     double monthlyIncome,
//     double monthlyExpenses,
//     List<dynamic> transactions,
//   ) {
//     // Calculate various financial metrics
//     final savingsRate = monthlyIncome > 0
//         ? ((monthlyIncome - monthlyExpenses) / monthlyIncome) * 100
//         : 0;

//     final emergencyFundMonths =
//         monthlyExpenses > 0 ? totalBalance / monthlyExpenses : 0;

//     final expenseToIncomeRatio =
//         monthlyIncome > 0 ? (monthlyExpenses / monthlyIncome) * 100 : 0;

//     // Calculate financial health score (0-1000)
//     double score = 0;

//     // Savings rate component (300 points max)
//     if (savingsRate >= 20)
//       score += 300;
//     else if (savingsRate >= 15)
//       score += 250;
//     else if (savingsRate >= 10)
//       score += 200;
//     else if (savingsRate >= 5)
//       score += 150;
//     else
//       score += savingsRate * 30;

//     // Emergency fund component (300 points max)
//     if (emergencyFundMonths >= 6)
//       score += 300;
//     else if (emergencyFundMonths >= 3)
//       score += 200;
//     else if (emergencyFundMonths >= 1)
//       score += 100;
//     else
//       score += emergencyFundMonths * 100;

//     // Expense ratio component (200 points max)
//     if (expenseToIncomeRatio <= 50)
//       score += 200;
//     else if (expenseToIncomeRatio <= 70)
//       score += 150;
//     else if (expenseToIncomeRatio <= 90)
//       score += 100;
//     else
//       score += max(0, 200 - (expenseToIncomeRatio - 90) * 5);

//     // Transaction consistency (200 points max)
//     final transactionScore = _calculateTransactionConsistency(transactions);
//     score += transactionScore * 200;

//     return {
//       'score': score.round(),
//       'grade': _getGrade(score),
//       'savingsRate': savingsRate.toStringAsFixed(1),
//       'emergencyFundMonths': emergencyFundMonths.toStringAsFixed(1),
//       'expenseRatio': expenseToIncomeRatio.toStringAsFixed(1),
//       'recommendations': _generateRecommendations(
//           score, savingsRate.toDouble(), emergencyFundMonths.toDouble()),
//     };
//   }

//   static String _getGrade(double score) {
//     if (score >= 900) return 'A+';
//     if (score >= 800) return 'A';
//     if (score >= 700) return 'B+';
//     if (score >= 600) return 'B';
//     if (score >= 500) return 'C+';
//     if (score >= 400) return 'C';
//     if (score >= 300) return 'D';
//     return 'F';
//   }

//   static double _calculateTransactionConsistency(List<dynamic> transactions) {
//     if (transactions.isEmpty) return 0;

//     // Calculate variance in spending patterns
//     final expenses = transactions.where((t) => !t.isIncome).toList();
//     if (expenses.isEmpty) return 0.5;

//     final amounts = expenses.map<double>((t) => t.amount).toList();
//     final mean = amounts.reduce((a, b) => a + b) / amounts.length;
//     final variance =
//         amounts.map((x) => (x - mean) * (x - mean)).reduce((a, b) => a + b) /
//             amounts.length;
//     final coefficient = mean > 0 ? sqrt(variance) / mean : 1;

//     // Lower coefficient of variation = more consistent = higher score
//     return max(0, 1 - coefficient.toDouble());
//   }

//   static List<String> _generateRecommendations(
//       double score, double savingsRate, double emergencyFund) {
//     final recommendations = <String>[];

//     if (score < 600) {
//       recommendations.add(
//           "Focus on building an emergency fund covering 3-6 months of expenses");
//     }
//     if (savingsRate < 15) {
//       recommendations.add(
//           "Try to save at least 15-20% of your income for long-term financial security");
//     }
//     if (emergencyFund < 3) {
//       recommendations.add(
//           "Build your emergency fund to cover at least 3 months of expenses");
//     }
//     if (score >= 800) {
//       recommendations
//           .add("Excellent financial health! Consider diversifying investments");
//     }

//     return recommendations;
//   }

//   // Market insights using free APIs
//   static Future<Map<String, dynamic>> getMarketInsights() async {
//     try {
//       // Get crypto prices (free API)
//       final cryptoResponse = await http.get(
//         Uri.parse('$_cryptoAPI?ids=bitcoin,ethereum&vs_currencies=inr'),
//       );

//       Map<String, dynamic> insights = {
//         'crypto': {},
//         'lastUpdated': DateTime.now().toIso8601String(),
//       };

//       if (cryptoResponse.statusCode == 200) {
//         final cryptoData = json.decode(cryptoResponse.body);
//         insights['crypto'] = {
//           'bitcoin': cryptoData['bitcoin']?['inr'] ?? 0,
//           'ethereum': cryptoData['ethereum']?['inr'] ?? 0,
//         };
//       }

//       return insights;
//     } catch (e) {
//       return {
//         'error': 'Failed to fetch market data',
//         'crypto': {'bitcoin': 0, 'ethereum': 0},
//         'lastUpdated': DateTime.now().toIso8601String(),
//       };
//     }
//   }

//   // Spending insights and predictions
//   static Map<String, dynamic> generateSpendingPredictions(
//       List<dynamic> transactions) {
//     final now = DateTime.now();
//     final currentMonth = DateTime(now.year, now.month);
//     final lastMonth = DateTime(now.year, now.month - 1);

//     // Current month spending
//     final currentMonthExpenses = transactions.where((t) {
//       final date = DateTime.parse(t.createdAt);
//       return !t.isIncome && date.isAfter(currentMonth);
//     }).fold<double>(0, (sum, t) => sum + t.amount);

//     // Last month spending
//     final lastMonthExpenses = transactions.where((t) {
//       final date = DateTime.parse(t.createdAt);
//       return !t.isIncome &&
//           date.isAfter(lastMonth) &&
//           date.isBefore(currentMonth);
//     }).fold<double>(0, (sum, t) => sum + t.amount);

//     // Calculate daily rate and predict month-end
//     final daysInMonth = DateTime(now.year, now.month + 1, 0).day;
//     final daysPassed = now.day;
//     final dailyRate = daysPassed > 0 ? currentMonthExpenses / daysPassed : 0;
//     final predictedMonthEnd = dailyRate * daysInMonth;

//     // Trend analysis
//     final trend = lastMonthExpenses > 0
//         ? ((currentMonthExpenses - lastMonthExpenses) / lastMonthExpenses) * 100
//         : 0;

//     return {
//       'currentMonthSpending': currentMonthExpenses,
//       'lastMonthSpending': lastMonthExpenses,
//       'predictedMonthEnd': predictedMonthEnd,
//       'dailyAverageSpending': dailyRate,
//       'trendPercentage': trend,
//       'trendDirection': trend > 5
//           ? 'increasing'
//           : trend < -5
//               ? 'decreasing'
//               : 'stable',
//       'remainingBudget': predictedMonthEnd - currentMonthExpenses,
//     };
//   }

//   // Category-wise spending analysis
//   static Map<String, dynamic> analyzeCategorySpending(
//       List<dynamic> transactions) {
//     final categorySpending = <String, double>{};
//     final categoryCount = <String, int>{};

//     // Group by category
//     for (var transaction in transactions) {
//       if (!transaction.isIncome) {
//         final category = transaction.category.toString();
//         categorySpending[category] =
//             (categorySpending[category] ?? 0) + transaction.amount;
//         categoryCount[category] = (categoryCount[category] ?? 0) + 1;
//       }
//     }

//     // Calculate percentages
//     final totalSpending =
//         categorySpending.values.fold<double>(0, (sum, amount) => sum + amount);
//     final categoryPercentages = <String, double>{};

//     for (var entry in categorySpending.entries) {
//       categoryPercentages[entry.key] =
//           totalSpending > 0 ? (entry.value / totalSpending) * 100 : 0;
//     }

//     // Find top categories
//     final sortedCategories = categorySpending.entries.toList()
//       ..sort((a, b) => b.value.compareTo(a.value));

//     return {
//       'categorySpending': categorySpending,
//       'categoryPercentages': categoryPercentages,
//       'categoryCount': categoryCount,
//       'topCategories': sortedCategories
//           .take(5)
//           .map((e) => {
//                 'category': e.key,
//                 'amount': e.value,
//                 'percentage': categoryPercentages[e.key],
//                 'transactions': categoryCount[e.key],
//               })
//           .toList(),
//       'totalSpending': totalSpending,
//     };
//   }

//   // Smart budgeting suggestions
//   static List<Map<String, dynamic>> generateBudgetSuggestions(
//     Map<String, dynamic> categoryAnalysis,
//     double monthlyIncome,
//   ) {
//     final suggestions = <Map<String, dynamic>>[];
//     final topCategories = categoryAnalysis['topCategories'] as List;

//     // 50/30/20 rule suggestions
//     final needs = monthlyIncome * 0.5;
//     final wants = monthlyIncome * 0.3;
//     final savings = monthlyIncome * 0.2;

//     suggestions.add({
//       'type': 'budget_allocation',
//       'title': '50/30/20 Budget Rule',
//       'description':
//           'Allocate 50% for needs (₹${needs.toStringAsFixed(0)}), 30% for wants (₹${wants.toStringAsFixed(0)}), 20% for savings (₹${savings.toStringAsFixed(0)})',
//       'priority': 'high',
//     });

//     // Category-specific suggestions
//     for (var category in topCategories) {
//       final percentage = category['percentage'] as double;
//       if (percentage > 30) {
//         suggestions.add({
//           'type': 'category_optimization',
//           'title': 'High ${category['category']} Spending',
//           'description':
//               '${category['category']} takes ${percentage.toStringAsFixed(1)}% of your budget. Consider reducing by 10-15%',
//           'priority': 'medium',
//         });
//       }
//     }

//     return suggestions;
//   }

//   // Investment recommendations based on risk profile
//   static List<Map<String, dynamic>> getInvestmentRecommendations(
//     double monthlyIncome,
//     double currentSavings,
//     int age,
//   ) {
//     final recommendations = <Map<String, dynamic>>[];
//     final riskCapacity =
//         _calculateRiskCapacity(age, monthlyIncome, currentSavings);

//     if (riskCapacity == 'high') {
//       recommendations.addAll([
//         {
//           'type': 'equity',
//           'title': 'Large Cap Mutual Funds',
//           'description':
//               'Invest 40-60% in large cap equity funds for steady growth',
//           'expectedReturn': '10-12%',
//           'riskLevel': 'Medium-High',
//         },
//         {
//           'type': 'equity',
//           'title': 'Mid & Small Cap Funds',
//           'description': 'Allocate 20-30% for higher growth potential',
//           'expectedReturn': '12-15%',
//           'riskLevel': 'High',
//         },
//       ]);
//     } else if (riskCapacity == 'medium') {
//       recommendations.addAll([
//         {
//           'type': 'hybrid',
//           'title': 'Balanced Mutual Funds',
//           'description': 'Mix of equity and debt for balanced growth',
//           'expectedReturn': '8-10%',
//           'riskLevel': 'Medium',
//         },
//         {
//           'type': 'debt',
//           'title': 'Corporate Bond Funds',
//           'description': 'Stable returns with moderate risk',
//           'expectedReturn': '6-8%',
//           'riskLevel': 'Low-Medium',
//         },
//       ]);
//     } else {
//       recommendations.addAll([
//         {
//           'type': 'debt',
//           'title': 'Liquid Funds',
//           'description': 'Park emergency funds with easy liquidity',
//           'expectedReturn': '4-6%',
//           'riskLevel': 'Low',
//         },
//         {
//           'type': 'debt',
//           'title': 'Fixed Deposits',
//           'description': 'Guaranteed returns for conservative investors',
//           'expectedReturn': '5-7%',
//           'riskLevel': 'Very Low',
//         },
//       ]);
//     }

//     return recommendations;
//   }

//   static String _calculateRiskCapacity(int age, double income, double savings) {
//     int score = 0;

//     // Age factor
//     if (age <= 30)
//       score += 3;
//     else if (age <= 40)
//       score += 2;
//     else if (age <= 50) score += 1;

//     // Income factor
//     if (income > 100000)
//       score += 2;
//     else if (income > 50000) score += 1;

//     // Savings factor
//     if (savings > income * 6)
//       score += 2;
//     else if (savings > income * 3) score += 1;

//     if (score >= 5) return 'high';
//     if (score >= 3) return 'medium';
//     return 'low';
//   }
// }
