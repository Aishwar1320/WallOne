// import 'package:flutter/material.dart';
// import 'package:provider/provider.dart';
// import 'package:wallone/state/balance_provider.dart';
// import 'package:wallone/state/list_provider.dart';
// import 'package:wallone/utils/constants.dart';
// import 'package:wallone/utils/services/openai_service.dart';

// class AdvancedAIDashboard extends StatefulWidget {
//   const AdvancedAIDashboard({super.key});

//   @override
//   State<AdvancedAIDashboard> createState() => _AdvancedAIDashboardState();
// }

// class _AdvancedAIDashboardState extends State<AdvancedAIDashboard>
//     with TickerProviderStateMixin {
//   late AnimationController _scoreAnimationController;
//   late AnimationController _chartAnimationController;
//   late Animation<double> _scoreAnimation;
//   late Animation<double> _chartAnimation;

//   Map<String, dynamic>? _financialScore;
//   Map<String, dynamic>? _marketData;
//   Map<String, dynamic>? _spendingPredictions;
//   Map<String, dynamic>? _categoryAnalysis;
//   bool _isLoading = true;

//   @override
//   void initState() {
//     super.initState();
//     _scoreAnimationController = AnimationController(
//       duration: const Duration(milliseconds: 2000),
//       vsync: this,
//     );
//     _chartAnimationController = AnimationController(
//       duration: const Duration(milliseconds: 1500),
//       vsync: this,
//     );

//     _scoreAnimation = Tween<double>(begin: 0, end: 1).animate(
//       CurvedAnimation(
//           parent: _scoreAnimationController, curve: Curves.easeOutCubic),
//     );
//     _chartAnimation = Tween<double>(begin: 0, end: 1).animate(
//       CurvedAnimation(
//           parent: _chartAnimationController, curve: Curves.elasticOut),
//     );

//     _loadData();
//   }

//   @override
//   void dispose() {
//     _scoreAnimationController.dispose();
//     _chartAnimationController.dispose();
//     super.dispose();
//   }

//   Future<void> _loadData() async {
//     final balProv = Provider.of<BalanceProvider>(context, listen: false);
//     final listProv = Provider.of<ListProvider>(context, listen: false);

//     // Calculate financial score
//     _financialScore = SmartInsightsService.calculateFinancialScore(
//       balProv.totalBalance,
//       _getMonthlyIncome(listProv.transactions),
//       _getMonthlyExpenses(listProv.transactions),
//       listProv.transactions,
//     );

//     // Get market data
//     _marketData = await SmartInsightsService.getMarketInsights();

//     // Generate predictions
//     _spendingPredictions = SmartInsightsService.generateSpendingPredictions(
//       listProv.transactions,
//     );

//     // Analyze categories
//     _categoryAnalysis = SmartInsightsService.analyzeCategorySpending(
//       listProv.transactions,
//     );

//     setState(() {
//       _isLoading = false;
//     });

//     _scoreAnimationController.forward();
//     _chartAnimationController.forward();
//   }

//   double _getMonthlyIncome(List<dynamic> transactions) {
//     final now = DateTime.now();
//     final monthStart = DateTime(now.year, now.month, 1);
//     return transactions
//         .where((t) =>
//             t.isIncome && DateTime.parse(t.createdAt).isAfter(monthStart))
//         .fold<double>(0, (sum, t) => sum + t.amount);
//   }

//   double _getMonthlyExpenses(List<dynamic> transactions) {
//     final now = DateTime.now();
//     final monthStart = DateTime(now.year, now.month, 1);
//     return transactions
//         .where((t) =>
//             !t.isIncome && DateTime.parse(t.createdAt).isAfter(monthStart))
//         .fold<double>(0, (sum, t) => sum + t.amount);
//   }

//   @override
//   Widget build(BuildContext context) {
//     if (_isLoading) {
//       return _buildLoadingState();
//     }

//     return SingleChildScrollView(
//       padding: const EdgeInsets.all(16),
//       child: Column(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           _buildHeader(),
//           const SizedBox(height: 20),
//           _buildFinancialScoreCard(),
//           const SizedBox(height: 20),
//           _buildQuickInsightsRow(),
//           const SizedBox(height: 20),
//           _buildSpendingPredictionCard(),
//           const SizedBox(height: 20),
//           _buildCategoryAnalysisCard(),
//           const SizedBox(height: 20),
//           _buildMarketInsightsCard(),
//           const SizedBox(height: 20),
//           _buildActionRecommendations(),
//         ],
//       ),
//     );
//   }

//   Widget _buildLoadingState() {
//     return Container(
//       height: 300,
//       decoration: BoxDecoration(
//         gradient: LinearGradient(
//           begin: Alignment.topLeft,
//           end: Alignment.bottomRight,
//           colors: [
//             primaryColor(context).withOpacity(0.1),
//             primaryColor(context).withOpacity(0.05),
//           ],
//         ),
//         borderRadius: BorderRadius.circular(20),
//       ),
//       child: const Center(
//         child: Column(
//           mainAxisAlignment: MainAxisAlignment.center,
//           children: [
//             CircularProgressIndicator(),
//             SizedBox(height: 16),
//             Text(
//               "🧠 AI is analyzing your finances...",
//               style: TextStyle(
//                 fontSize: 16,
//                 fontWeight: FontWeight.w500,
//               ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }

//   Widget _buildHeader() {
//     return Container(
//       padding: const EdgeInsets.all(20),
//       decoration: BoxDecoration(
//         gradient: LinearGradient(
//           begin: Alignment.topLeft,
//           end: Alignment.bottomRight,
//           colors: [
//             primaryColor(context),
//             primaryColor(context).withOpacity(0.8),
//           ],
//         ),
//         borderRadius: BorderRadius.circular(20),
//         boxShadow: [
//           BoxShadow(
//             color: primaryColor(context).withOpacity(0.3),
//             blurRadius: 20,
//             offset: const Offset(0, 10),
//           ),
//         ],
//       ),
//       child: Row(
//         children: [
//           Container(
//             padding: const EdgeInsets.all(12),
//             decoration: BoxDecoration(
//               color: Colors.white.withOpacity(0.2),
//               borderRadius: BorderRadius.circular(15),
//             ),
//             child: const Text("🧠", style: TextStyle(fontSize: 24)),
//           ),
//           const SizedBox(width: 16),
//           const Expanded(
//             child: Column(
//               crossAxisAlignment: CrossAxisAlignment.start,
//               children: [
//                 Text(
//                   "Advanced analytics powered by machine learning",
//                   style: TextStyle(
//                     fontSize: 14,
//                     color: Colors.white70,
//                   ),
//                 ),
//               ],
//             ),
//           ),
//           Container(
//             padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
//             decoration: BoxDecoration(
//               color: Colors.white.withOpacity(0.2),
//               borderRadius: BorderRadius.circular(20),
//             ),
//             child: const Text(
//               "PREMIUM",
//               style: TextStyle(
//                 fontSize: 12,
//                 fontWeight: FontWeight.bold,
//                 color: Colors.white,
//               ),
//             ),
//           ),
//         ],
//       ),
//     );
//   }

//   Widget _buildFinancialScoreCard() {
//     final score = _financialScore?['score'] ?? 0;
//     final grade = _financialScore?['grade'] ?? 'N/A';

//     return AnimatedBuilder(
//       animation: _scoreAnimation,
//       builder: (context, child) {
//         return Container(
//           padding: const EdgeInsets.all(24),
//           decoration: BoxDecoration(
//             color: Colors.white,
//             borderRadius: BorderRadius.circular(20),
//             boxShadow: [
//               BoxShadow(
//                 color: Colors.black.withOpacity(0.1),
//                 blurRadius: 20,
//                 offset: const Offset(0, 5),
//               ),
//             ],
//           ),
//           child: Column(
//             children: [
//               Row(
//                 children: [
//                   const Text(
//                     "💯",
//                     style: TextStyle(fontSize: 24),
//                   ),
//                   const SizedBox(width: 12),
//                   const Text(
//                     "Financial Health Score",
//                     style: TextStyle(
//                       fontSize: 18,
//                       fontWeight: FontWeight.bold,
//                     ),
//                   ),
//                   const Spacer(),
//                   Container(
//                     padding:
//                         const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
//                     decoration: BoxDecoration(
//                       color: _getScoreColor(score).withOpacity(0.1),
//                       borderRadius: BorderRadius.circular(15),
//                     ),
//                     child: Text(
//                       grade,
//                       style: TextStyle(
//                         fontSize: 16,
//                         fontWeight: FontWeight.bold,
//                         color: _getScoreColor(score),
//                       ),
//                     ),
//                   ),
//                 ],
//               ),
//               const SizedBox(height: 24),
//               Stack(
//                 alignment: Alignment.center,
//                 children: [
//                   SizedBox(
//                     width: 150,
//                     height: 150,
//                     child: CircularProgressIndicator(
//                       value: (_scoreAnimation.value * score / 1000)
//                           .clamp(0.0, 1.0),
//                       strokeWidth: 12,
//                       backgroundColor: Colors.grey[200],
//                       valueColor:
//                           AlwaysStoppedAnimation<Color>(_getScoreColor(score)),
//                     ),
//                   ),
//                   Column(
//                     children: [
//                       Text(
//                         "${(score * _scoreAnimation.value).toInt()}",
//                         style: TextStyle(
//                           fontSize: 32,
//                           fontWeight: FontWeight.bold,
//                           color: _getScoreColor(score),
//                         ),
//                       ),
//                       const Text(
//                         "/ 1000",
//                         style: TextStyle(
//                           fontSize: 14,
//                           color: Colors.grey,
//                         ),
//                       ),
//                     ],
//                   ),
//                 ],
//               ),
//               const SizedBox(height: 24),
//               Row(
//                 mainAxisAlignment: MainAxisAlignment.spaceAround,
//                 children: [
//                   _buildScoreMetric(
//                     "Savings Rate",
//                     "${_financialScore?['savingsRate']}%",
//                     Icons.savings,
//                   ),
//                   _buildScoreMetric(
//                     "Emergency Fund",
//                     "${_financialScore?['emergencyFundMonths']}M",
//                     Icons.security,
//                   ),
//                   _buildScoreMetric(
//                     "Expense Ratio",
//                     "${_financialScore?['expenseRatio']}%",
//                     Icons.trending_down,
//                   ),
//                 ],
//               ),
//             ],
//           ),
//         );
//       },
//     );
//   }

//   Color _getScoreColor(int score) {
//     if (score >= 800) return Colors.green;
//     if (score >= 600) return Colors.orange;
//     return Colors.red;
//   }

//   Widget _buildScoreMetric(String label, String value, IconData icon) {
//     return Column(
//       children: [
//         Icon(icon, color: primaryColor(context), size: 24),
//         const SizedBox(height: 8),
//         Text(
//           value,
//           style: const TextStyle(
//             fontSize: 16,
//             fontWeight: FontWeight.bold,
//           ),
//         ),
//         Text(
//           label,
//           style: TextStyle(
//             fontSize: 12,
//             color: Colors.grey[600],
//           ),
//           textAlign: TextAlign.center,
//         ),
//       ],
//     );
//   }

//   Widget _buildQuickInsightsRow() {
//     return Row(
//       children: [
//         Expanded(
//           child: _buildInsightCard(
//             "📈",
//             "Spending Trend",
//             _spendingPredictions?['trendDirection'] == 'increasing'
//                 ? "↗️ Rising"
//                 : "↘️ Stable",
//             _spendingPredictions?['trendDirection'] == 'increasing'
//                 ? Colors.red
//                 : Colors.green,
//           ),
//         ),
//         const SizedBox(width: 12),
//         Expanded(
//           child: _buildInsightCard(
//             "💰",
//             "Monthly Avg",
//             "₹${(_spendingPredictions?['dailyAverageSpending'] ?? 0 * 30).toStringAsFixed(0)}",
//             Colors.blue,
//           ),
//         ),
//         const SizedBox(width: 12),
//         Expanded(
//           child: _buildInsightCard(
//             "🎯",
//             "Budget Left",
//             "₹${(_spendingPredictions?['remainingBudget'] ?? 0).toStringAsFixed(0)}",
//             Colors.purple,
//           ),
//         ),
//       ],
//     );
//   }

//   Widget _buildInsightCard(
//       String emoji, String title, String value, Color color) {
//     return AnimatedBuilder(
//       animation: _chartAnimation,
//       builder: (context, child) {
//         return Transform.scale(
//           scale: _chartAnimation.value,
//           child: Container(
//             padding: const EdgeInsets.all(16),
//             decoration: BoxDecoration(
//               color: color.withOpacity(0.1),
//               borderRadius: BorderRadius.circular(16),
//               border: Border.all(
//                 color: color.withOpacity(0.3),
//                 width: 1,
//               ),
//             ),
//             child: Column(
//               children: [
//                 Text(emoji, style: const TextStyle(fontSize: 24)),
//                 const SizedBox(height: 8),
//                 Text(
//                   title,
//                   style: TextStyle(
//                     fontSize: 12,
//                     color: Colors.grey[600],
//                   ),
//                 ),
//                 const SizedBox(height: 4),
//                 Text(
//                   value,
//                   style: TextStyle(
//                     fontSize: 16,
//                     fontWeight: FontWeight.bold,
//                     color: color,
//                   ),
//                 ),
//               ],
//             ),
//           ),
//         );
//       },
//     );
//   }

//   Widget _buildSpendingPredictionCard() {
//     final currentSpending = _spendingPredictions?['currentMonthSpending'] ?? 0;
//     final predictedEnd = _spendingPredictions?['predictedMonthEnd'] ?? 0;
//     final progress = predictedEnd > 0
//         ? (currentSpending / predictedEnd).clamp(0.0, 1.0)
//         : 0.0;

//     return Container(
//       padding: const EdgeInsets.all(20),
//       decoration: BoxDecoration(
//         color: Colors.white,
//         borderRadius: BorderRadius.circular(20),
//         boxShadow: [
//           BoxShadow(
//             color: Colors.black.withOpacity(0.05),
//             blurRadius: 15,
//             offset: const Offset(0, 5),
//           ),
//         ],
//       ),
//       child: Column(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           Row(
//             children: [
//               const Text("🔮", style: TextStyle(fontSize: 24)),
//               const SizedBox(width: 12),
//               const Text(
//                 "Spending Prediction",
//                 style: TextStyle(
//                   fontSize: 18,
//                   fontWeight: FontWeight.bold,
//                 ),
//               ),
//               const Spacer(),
//               Container(
//                 padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
//                 decoration: BoxDecoration(
//                   color: Colors.blue.withOpacity(0.1),
//                   borderRadius: BorderRadius.circular(8),
//                 ),
//                 child: const Text(
//                   "AI POWERED",
//                   style: TextStyle(
//                     fontSize: 10,
//                     fontWeight: FontWeight.bold,
//                     color: Colors.blue,
//                   ),
//                 ),
//               ),
//             ],
//           ),
//           const SizedBox(height: 20),
//           AnimatedBuilder(
//             animation: _chartAnimation,
//             builder: (context, child) {
//               return Column(
//                 children: [
//                   Row(
//                     mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                     children: [
//                       Text(
//                         "Current: ₹${currentSpending.toStringAsFixed(0)}",
//                         style: const TextStyle(fontSize: 14),
//                       ),
//                       Text(
//                         "Predicted: ₹${predictedEnd.toStringAsFixed(0)}",
//                         style: const TextStyle(
//                           fontSize: 14,
//                           fontWeight: FontWeight.bold,
//                         ),
//                       ),
//                     ],
//                   ),
//                   const SizedBox(height: 12),
//                   LinearProgressIndicator(
//                     value: progress * _chartAnimation.value,
//                     backgroundColor: Colors.grey[200],
//                     valueColor: AlwaysStoppedAnimation<Color>(
//                       progress > 0.8
//                           ? Colors.red
//                           : progress > 0.6
//                               ? Colors.orange
//                               : Colors.green,
//                     ),
//                     minHeight: 8,
//                   ),
//                   const SizedBox(height: 16),
//                   Row(
//                     children: [
//                       Expanded(
//                         child: _buildPredictionMetric(
//                           "Daily Average",
//                           "₹${(_spendingPredictions?['dailyAverageSpending'] ?? 0).toStringAsFixed(0)}",
//                           Icons.calendar_today,
//                         ),
//                       ),
//                       Expanded(
//                         child: _buildPredictionMetric(
//                           "Trend",
//                           "${(_spendingPredictions?['trendPercentage'] ?? 0).toStringAsFixed(1)}%",
//                           _spendingPredictions?['trendDirection'] ==
//                                   'increasing'
//                               ? Icons.trending_up
//                               : Icons.trending_down,
//                         ),
//                       ),
//                     ],
//                   ),
//                 ],
//               );
//             },
//           ),
//         ],
//       ),
//     );
//   }

//   Widget _buildPredictionMetric(String label, String value, IconData icon) {
//     return Container(
//       padding: const EdgeInsets.all(12),
//       margin: const EdgeInsets.symmetric(horizontal: 4),
//       decoration: BoxDecoration(
//         color: Colors.grey[50],
//         borderRadius: BorderRadius.circular(12),
//       ),
//       child: Column(
//         children: [
//           Icon(icon, size: 20, color: primaryColor(context)),
//           const SizedBox(height: 4),
//           Text(
//             value,
//             style: const TextStyle(
//               fontSize: 14,
//               fontWeight: FontWeight.bold,
//             ),
//           ),
//           Text(
//             label,
//             style: TextStyle(
//               fontSize: 10,
//               color: Colors.grey[600],
//             ),
//           ),
//         ],
//       ),
//     );
//   }

//   Widget _buildCategoryAnalysisCard() {
//     final topCategories = _categoryAnalysis?['topCategories'] as List? ?? [];

//     return Container(
//       padding: const EdgeInsets.all(20),
//       decoration: BoxDecoration(
//         color: Colors.white,
//         borderRadius: BorderRadius.circular(20),
//         boxShadow: [
//           BoxShadow(
//             color: Colors.black.withOpacity(0.05),
//             blurRadius: 15,
//             offset: const Offset(0, 5),
//           ),
//         ],
//       ),
//       child: Column(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           const Row(
//             children: [
//               Text("📊", style: TextStyle(fontSize: 24)),
//               SizedBox(width: 12),
//               Text(
//                 "Category Breakdown",
//                 style: TextStyle(
//                   fontSize: 18,
//                   fontWeight: FontWeight.bold,
//                 ),
//               ),
//             ],
//           ),
//           const SizedBox(height: 20),
//           ...topCategories.take(5).map((category) {
//             final percentage = category['percentage'] as double;
//             final amount = category['amount'] as double;
//             return Container(
//               margin: const EdgeInsets.only(bottom: 12),
//               child: Column(
//                 children: [
//                   Row(
//                     mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                     children: [
//                       Text(
//                         category['category'],
//                         style: const TextStyle(
//                           fontSize: 14,
//                           fontWeight: FontWeight.w500,
//                         ),
//                       ),
//                       Text(
//                         "₹${amount.toStringAsFixed(0)} (${percentage.toStringAsFixed(1)}%)",
//                         style: const TextStyle(
//                           fontSize: 14,
//                           fontWeight: FontWeight.bold,
//                         ),
//                       ),
//                     ],
//                   ),
//                   const SizedBox(height: 6),
//                   AnimatedBuilder(
//                     animation: _chartAnimation,
//                     builder: (context, child) {
//                       return LinearProgressIndicator(
//                         value: (percentage / 100) * _chartAnimation.value,
//                         backgroundColor: Colors.grey[200],
//                         valueColor: AlwaysStoppedAnimation<Color>(
//                           _getCategoryColor(topCategories.indexOf(category)),
//                         ),
//                         minHeight: 6,
//                       );
//                     },
//                   ),
//                 ],
//               ),
//             );
//           }).toList(),
//         ],
//       ),
//     );
//   }

//   Color _getCategoryColor(int index) {
//     final colors = [
//       Colors.blue,
//       Colors.green,
//       Colors.orange,
//       Colors.purple,
//       Colors.red,
//     ];
//     return colors[index % colors.length];
//   }

//   Widget _buildMarketInsightsCard() {
//     final cryptoData = _marketData?['crypto'] as Map<String, dynamic>? ?? {};

//     return Container(
//       padding: const EdgeInsets.all(20),
//       decoration: BoxDecoration(
//         gradient: LinearGradient(
//           begin: Alignment.topLeft,
//           end: Alignment.bottomRight,
//           colors: [
//             Colors.indigo.withOpacity(0.1),
//             Colors.purple.withOpacity(0.1),
//           ],
//         ),
//         borderRadius: BorderRadius.circular(20),
//         border: Border.all(
//           color: Colors.indigo.withOpacity(0.2),
//           width: 1,
//         ),
//       ),
//       child: Column(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           const Row(
//             children: [
//               Text("📈", style: TextStyle(fontSize: 24)),
//               SizedBox(width: 12),
//               Text(
//                 "Market Insights",
//                 style: TextStyle(
//                   fontSize: 18,
//                   fontWeight: FontWeight.bold,
//                 ),
//               ),
//             ],
//           ),
//           const SizedBox(height: 16),
//           Row(
//             children: [
//               Expanded(
//                 child: _buildCryptoCard(
//                   "Bitcoin",
//                   "₹${(cryptoData['bitcoin'] ?? 0).toStringAsFixed(0)}",
//                   "🟡",
//                 ),
//               ),
//               const SizedBox(width: 12),
//               Expanded(
//                 child: _buildCryptoCard(
//                   "Ethereum",
//                   "₹${(cryptoData['ethereum'] ?? 0).toStringAsFixed(0)}",
//                   "🔷",
//                 ),
//               ),
//             ],
//           ),
//           const SizedBox(height: 16),
//           Container(
//             padding: const EdgeInsets.all(12),
//             decoration: BoxDecoration(
//               color: Colors.blue.withOpacity(0.1),
//               borderRadius: BorderRadius.circular(8),
//             ),
//             child: const Row(
//               children: [
//                 Icon(Icons.info_outline, size: 16, color: Colors.blue),
//                 SizedBox(width: 8),
//                 Expanded(
//                   child: Text(
//                     "Consider diversifying investments across asset classes",
//                     style: TextStyle(
//                       fontSize: 12,
//                       color: Colors.blue,
//                     ),
//                   ),
//                 ),
//               ],
//             ),
//           ),
//         ],
//       ),
//     );
//   }

//   Widget _buildCryptoCard(String name, String price, String emoji) {
//     return Container(
//       padding: const EdgeInsets.all(16),
//       decoration: BoxDecoration(
//         color: Colors.white.withOpacity(0.8),
//         borderRadius: BorderRadius.circular(12),
//       ),
//       child: Column(
//         children: [
//           Text(emoji, style: const TextStyle(fontSize: 20)),
//           const SizedBox(height: 8),
//           Text(
//             name,
//             style: const TextStyle(
//               fontSize: 12,
//               fontWeight: FontWeight.w500,
//             ),
//           ),
//           const SizedBox(height: 4),
//           Text(
//             price,
//             style: const TextStyle(
//               fontSize: 14,
//               fontWeight: FontWeight.bold,
//             ),
//           ),
//         ],
//       ),
//     );
//   }

//   Widget _buildActionRecommendations() {
//     final recommendations = _financialScore?['recommendations'] as List? ?? [];

//     return Container(
//       padding: const EdgeInsets.all(20),
//       decoration: BoxDecoration(
//         color: Colors.white,
//         borderRadius: BorderRadius.circular(20),
//         boxShadow: [
//           BoxShadow(
//             color: Colors.black.withOpacity(0.05),
//             blurRadius: 15,
//             offset: const Offset(0, 5),
//           ),
//         ],
//       ),
//       child: Column(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           const Row(
//             children: [
//               Text("🎯", style: TextStyle(fontSize: 24)),
//               SizedBox(width: 12),
//               Text(
//                 "AI Recommendations",
//                 style: TextStyle(
//                   fontSize: 18,
//                   fontWeight: FontWeight.bold,
//                 ),
//               ),
//             ],
//           ),
//           const SizedBox(height: 16),
//           if (recommendations.isEmpty)
//             Container(
//               padding: const EdgeInsets.all(16),
//               decoration: BoxDecoration(
//                 color: Colors.green.withOpacity(0.1),
//                 borderRadius: BorderRadius.circular(12),
//               ),
//               child: const Row(
//                 children: [
//                   Text("✅", style: TextStyle(fontSize: 20)),
//                   SizedBox(width: 12),
//                   Expanded(
//                     child: Text(
//                       "Excellent! Your financial health is in great shape. Keep up the good work!",
//                       style: TextStyle(
//                         fontSize: 14,
//                         color: Colors.green,
//                         fontWeight: FontWeight.w500,
//                       ),
//                     ),
//                   ),
//                 ],
//               ),
//             )
//           else
//             ...recommendations.map((rec) => Container(
//                   margin: const EdgeInsets.only(bottom: 12),
//                   padding: const EdgeInsets.all(16),
//                   decoration: BoxDecoration(
//                     color: Colors.orange.withOpacity(0.1),
//                     borderRadius: BorderRadius.circular(12),
//                   ),
//                   child: Row(
//                     children: [
//                       const Text("💡", style: TextStyle(fontSize: 20)),
//                       const SizedBox(width: 12),
//                       Expanded(
//                         child: Text(
//                           rec,
//                           style: const TextStyle(
//                             fontSize: 14,
//                             height: 1.4,
//                           ),
//                         ),
//                       ),
//                     ],
//                   ),
//                 )),
//           const SizedBox(height: 16),
//           SizedBox(
//             width: double.infinity,
//             child: ElevatedButton.icon(
//               onPressed: () {
//                 _showDetailedRecommendations();
//               },
//               icon: const Icon(Icons.auto_awesome),
//               label: const Text("Get Personalized Plan"),
//               style: ElevatedButton.styleFrom(
//                 backgroundColor: primaryColor(context),
//                 foregroundColor: Colors.white,
//                 padding: const EdgeInsets.symmetric(vertical: 16),
//                 shape: RoundedRectangleBorder(
//                   borderRadius: BorderRadius.circular(12),
//                 ),
//               ),
//             ),
//           ),
//         ],
//       ),
//     );
//   }

//   void _showDetailedRecommendations() {
//     showModalBottomSheet(
//       context: context,
//       isScrollControlled: true,
//       backgroundColor: Colors.transparent,
//       builder: (context) => const DetailedRecommendationsSheet(),
//     );
//   }
// }

// class DetailedRecommendationsSheet extends StatelessWidget {
//   const DetailedRecommendationsSheet({super.key});

//   @override
//   Widget build(BuildContext context) {
//     return Container(
//       height: MediaQuery.of(context).size.height * 0.8,
//       decoration: const BoxDecoration(
//         color: Colors.white,
//         borderRadius: BorderRadius.only(
//           topLeft: Radius.circular(20),
//           topRight: Radius.circular(20),
//         ),
//       ),
//       child: Column(
//         children: [
//           Container(
//             padding: const EdgeInsets.all(20),
//             decoration: BoxDecoration(
//               gradient: LinearGradient(
//                 colors: [
//                   primaryColor(context),
//                   primaryColor(context).withOpacity(0.8),
//                 ],
//               ),
//               borderRadius: const BorderRadius.only(
//                 topLeft: Radius.circular(20),
//                 topRight: Radius.circular(20),
//               ),
//             ),
//             child: Column(
//               children: [
//                 Container(
//                   width: 40,
//                   height: 4,
//                   decoration: BoxDecoration(
//                     color: Colors.white.withOpacity(0.5),
//                     borderRadius: BorderRadius.circular(2),
//                   ),
//                 ),
//                 const SizedBox(height: 20),
//                 const Row(
//                   children: [
//                     Text("🎯", style: TextStyle(fontSize: 24)),
//                     SizedBox(width: 12),
//                     Text(
//                       "Your Personalized Financial Plan",
//                       style: TextStyle(
//                         fontSize: 20,
//                         fontWeight: FontWeight.bold,
//                         color: Colors.white,
//                       ),
//                     ),
//                   ],
//                 ),
//               ],
//             ),
//           ),
//           Expanded(
//             child: SingleChildScrollView(
//               padding: const EdgeInsets.all(20),
//               child: Column(
//                 crossAxisAlignment: CrossAxisAlignment.start,
//                 children: [
//                   _buildPlanCard(
//                     "🚀 Short Term (1-3 months)",
//                     [
//                       "Build emergency fund to cover 1 month expenses",
//                       "Track daily expenses using the app",
//                       "Set up automated savings of ₹5,000/month",
//                     ],
//                     Colors.green,
//                   ),
//                   const SizedBox(height: 16),
//                   _buildPlanCard(
//                     "📈 Medium Term (3-12 months)",
//                     [
//                       "Increase emergency fund to 6 months",
//                       "Start SIP investment of ₹10,000/month",
//                       "Optimize tax savings through ELSS funds",
//                     ],
//                     Colors.blue,
//                   ),
//                   const SizedBox(height: 16),
//                   _buildPlanCard(
//                     "🎯 Long Term (1+ years)",
//                     [
//                       "Diversify portfolio across asset classes",
//                       "Consider real estate investment",
//                       "Plan for retirement with PPF/NPS",
//                     ],
//                     Colors.purple,
//                   ),
//                 ],
//               ),
//             ),
//           ),
//         ],
//       ),
//     );
//   }

//   Widget _buildPlanCard(String title, List<String> items, Color color) {
//     return Container(
//       padding: const EdgeInsets.all(16),
//       decoration: BoxDecoration(
//         color: color.withOpacity(0.1),
//         borderRadius: BorderRadius.circular(12),
//         border: Border.all(
//           color: color.withOpacity(0.3),
//           width: 1,
//         ),
//       ),
//       child: Column(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           Text(
//             title,
//             style: TextStyle(
//               fontSize: 16,
//               fontWeight: FontWeight.bold,
//               color: color,
//             ),
//           ),
//           const SizedBox(height: 12),
//           ...items.map((item) => Padding(
//                 padding: const EdgeInsets.only(bottom: 8),
//                 child: Row(
//                   crossAxisAlignment: CrossAxisAlignment.start,
//                   children: [
//                     Container(
//                       width: 6,
//                       height: 6,
//                       margin: const EdgeInsets.only(top: 6, right: 12),
//                       decoration: BoxDecoration(
//                         color: color,
//                         shape: BoxShape.circle,
//                       ),
//                     ),
//                     Expanded(
//                       child: Text(
//                         item,
//                         style: const TextStyle(fontSize: 14, height: 1.4),
//                       ),
//                     ),
//                   ],
//                 ),
//               )),
//         ],
//       ),
//     );
//   }
// }
