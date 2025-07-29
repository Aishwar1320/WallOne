import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:wallone/state/balance_provider.dart';
import 'package:wallone/utils/constants.dart';
import 'dart:math' as math;

class AnalyticsPage extends StatefulWidget {
  const AnalyticsPage({super.key});

  @override
  State<AnalyticsPage> createState() => _AnalyticsPageState();
}

class _AnalyticsPageState extends State<AnalyticsPage>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<BalanceProvider>(
      builder: (context, provider, _) {
        return FadeTransition(
          opacity: _fadeAnimation,
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 40),
                  _buildSectionWithBadge("Monthly Overview"),
                  const SizedBox(height: 16),
                  _buildMonthlyComparisonChart(context, provider),
                  const SizedBox(height: 40),
                  _buildSectionWithInfoButton(
                    "WallOne AI",
                    context,
                    onInfoPressed: () => _showInvestmentInfo(context),
                  ),
                  const SizedBox(height: 16),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildSectionWithBadge(String title) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Container(
              width: 4,
              height: 24,
              decoration: BoxDecoration(
                color: primaryColor(context),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 12),
            Text(
              title,
              style: GoogleFonts.outfit(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: primaryColor(context),
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSectionWithInfoButton(String title, BuildContext context,
      {required VoidCallback onInfoPressed}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Container(
              width: 4,
              height: 24,
              decoration: BoxDecoration(
                color: primaryColor(context),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 12),
            Text(
              title,
              style: GoogleFonts.outfit(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: primaryColor(context),
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
        IconButton(
          onPressed: onInfoPressed,
          icon: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: primaryColor(context).withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: shadowColor(context).withOpacity(0.1),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Icon(
              Icons.info_outline,
              color: primaryColor(context),
              size: 20,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMonthlyComparisonChart(
      BuildContext context, BalanceProvider provider) {
    final textColor =
        Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black;
    final screenWidth = MediaQuery.of(context).size.width;
    final currentMonth = DateTime.now();
    final monthName = _getMonthName(currentMonth.month);
    final year = currentMonth.year;

    // Get income and expense values
    final income = provider.monthlyIncomes;
    final expenses = provider.monthlyExpenses;
    final maxAmount = math.max(income, expenses);

    // Calculate suitable tick increment based on data range
    double majorTick;
    double bottomY = 0;
    double topY;

    // Choose increment size to ensure we have 5-6 ticks
    if (maxAmount <= 5000) {
      // For small values, use 1K increments (0, 1K, 2K, 3K, 4K, 5K)
      majorTick = 1000;
      topY = 5000;
    } else if (maxAmount <= 10000) {
      // For medium values, use 2K increments (0, 2K, 4K, 6K, 8K, 10K)
      majorTick = 2000;
      topY = 10000;
    } else if (maxAmount <= 20000) {
      // For larger values, use 4K increments (0, 4K, 8K, 12K, 16K, 20K)
      majorTick = 4000;
      topY = 20000;
    } else if (maxAmount <= 30000) {
      // For even larger values (0, 5K, 10K, 15K, 20K, 25K, 30K)
      majorTick = 5000;
      topY = 30000;
    } else {
      // For very large values, use 10K increments and calculate appropriate topY
      majorTick = 10000;
      topY = ((maxAmount / majorTick).ceil() + 1) * majorTick;
    }

    // Ensure we have at least one full increment of padding above the maximum value
    if (maxAmount > topY - majorTick) {
      topY += majorTick;
    }

    // Create a list of tick values at our chosen increment
    int numTicks = (topY / majorTick).ceil() + 1;
    final List<double> tickValues =
        List.generate(numTicks, (i) => i * majorTick);

    // Define tolerance for matching values to ticks
    final double tolerance = majorTick / 10;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Theme.of(context).cardColor,
            Theme.of(context).cardColor.withOpacity(0.9),
          ],
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: shadowColor(context).withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header section
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: primaryColor(context).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.bar_chart,
                      color: primaryColor(context),
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Income vs Expenses',
                    style: GoogleFonts.outfit(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: textColor,
                    ),
                  ),
                ],
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: primaryColor(context).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '$monthName $year',
                  style: GoogleFonts.outfit(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: primaryColor(context),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          // Chart section
          SizedBox(
            height: 220,
            width: double.infinity,
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                minY: bottomY,
                maxY: topY,
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: majorTick,
                  getDrawingHorizontalLine: (value) {
                    // Only draw grid lines at our tick values
                    if (tickValues
                        .any((tick) => (value - tick).abs() < tolerance)) {
                      return FlLine(
                        color: Colors.grey.withOpacity(0.1),
                        strokeWidth: 1,
                      );
                    }
                    return FlLine(color: Colors.transparent);
                  },
                ),
                titlesData: FlTitlesData(
                  show: true,
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        String text = value == 0 ? 'Income' : 'Expenses';
                        return Padding(
                          padding: const EdgeInsets.only(
                            top: 6.0,
                          ),
                          child: Text(
                            text,
                            style: GoogleFonts.outfit(
                              color: textColor.withOpacity(0.7),
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 50,
                      interval: majorTick /
                          2, // Show labels at half the major tick interval for more density
                      getTitlesWidget: (value, meta) {
                        // Check if this value is one of our designated tick values
                        bool isRegularTick = tickValues
                            .any((tick) => (value - tick).abs() < tolerance);

                        // Also show income and expense values if they don't match a tick
                        bool isIncomeValue = (value - income).abs() < tolerance;
                        bool isExpenseValue =
                            (value - expenses).abs() < tolerance;

                        if (!isRegularTick &&
                            !isIncomeValue &&
                            !isExpenseValue) {
                          return const SizedBox.shrink();
                        }

                        // Customize label style
                        TextStyle labelStyle = GoogleFonts.outfit(
                          color: textColor.withOpacity(0.7),
                          fontSize: 11,
                        );

                        if (isIncomeValue) {
                          labelStyle = GoogleFonts.outfit(
                            color: const Color(0xFF37B873),
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          );
                        } else if (isExpenseValue) {
                          labelStyle = GoogleFonts.outfit(
                            color: const Color(0xFFFF5252),
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          );
                        }

                        return SideTitleWidget(
                          meta: meta,
                          child: Text(
                            _formatValue(value),
                            style: labelStyle,
                          ),
                        );
                      },
                    ),
                  ),
                ),
                borderData: FlBorderData(show: false),
                barGroups: [
                  BarChartGroupData(
                    x: 0,
                    barRods: [
                      BarChartRodData(
                        toY: income,
                        gradient: const LinearGradient(
                          colors: [Color(0xFF55CE86), Color(0xFF37B873)],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                        ),
                        width: _calculateBarWidth(screenWidth),
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(8),
                          topRight: Radius.circular(8),
                        ),
                        backDrawRodData: BackgroundBarChartRodData(
                          show: true,
                          toY: topY,
                          color: Colors.grey.withOpacity(0.05),
                        ),
                      )
                    ],
                  ),
                  BarChartGroupData(
                    x: 1,
                    barRods: [
                      BarChartRodData(
                        toY: expenses,
                        gradient: const LinearGradient(
                          colors: [Color(0xFFFF7A7A), Color(0xFFFF5252)],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                        ),
                        width: _calculateBarWidth(screenWidth),
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(8),
                          topRight: Radius.circular(8),
                        ),
                        backDrawRodData: BackgroundBarChartRodData(
                          show: true,
                          toY: topY,
                          color: Colors.grey.withOpacity(0.05),
                        ),
                      )
                    ],
                  ),
                ],
                // Draw the dashed (dotted) lines only for income and expense
                extraLinesData: ExtraLinesData(
                  horizontalLines: [
                    if (income > 0)
                      HorizontalLine(
                        y: income,
                        color: const Color(0xFF37B873),
                        strokeWidth: 1,
                        dashArray: [3, 3],
                        label: HorizontalLineLabel(
                          show: true,
                          alignment: Alignment.topRight,
                          padding: const EdgeInsets.only(right: 8, top: 2),
                          style: GoogleFonts.outfit(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF37B873),
                          ),
                          labelResolver: (line) => _formatValue(income),
                        ),
                      ),
                    if (expenses > 0)
                      HorizontalLine(
                        y: expenses,
                        color: const Color(0xFFFF5252),
                        strokeWidth: 1,
                        dashArray: [3, 3],
                        label: HorizontalLineLabel(
                          show: true,
                          alignment: Alignment.topRight,
                          padding: const EdgeInsets.only(right: 8, top: 2),
                          style: GoogleFonts.outfit(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFFFF5252),
                          ),
                          labelResolver: (line) => _formatValue(expenses),
                        ),
                      ),
                  ],
                ),
              ),
              swapAnimationDuration: Duration.zero,
            ),
          ),
          const SizedBox(height: 20),
          // Net balance indicator
          if (income > 0 && expenses > 0)
            Padding(
              padding: const EdgeInsets.only(top: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Net Balance: ',
                    style: GoogleFonts.outfit(
                      fontSize: 14,
                      color: textColor.withOpacity(0.8),
                    ),
                  ),
                  Text(
                    _formatValue(income - expenses),
                    style: GoogleFonts.outfit(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: income > expenses
                          ? const Color(0xFF37B873)
                          : const Color(0xFFFF5252),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  String _getMonthName(int month) {
    return DateFormat('MMMM').format(DateTime(DateTime.now().year, month));
  }

  double _calculateBarWidth(double screenWidth) {
    if (screenWidth > 600) {
      return 80;
    } else if (screenWidth > 400) {
      return 60;
    } else {
      return 40;
    }
  }

  String _formatValue(double value) {
    final code = context.read<BalanceProvider>().currencyCode;
    final symbol = NumberFormat.simpleCurrency(name: code).currencySymbol;

    if (value >= 1000000) {
      return '$symbol${(value / 1000000).toStringAsFixed(1)}M';
    } else if (value >= 1000) {
      return '$symbol${(value / 1000).toStringAsFixed(1)}K';
    } else {
      return '$symbol${value.toStringAsFixed(0)}';
    }
  }

  // Helper widgets

  void _showInvestmentInfo(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.7,
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(32),
              topRight: Radius.circular(32),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 10,
                offset: const Offset(0, -5),
              ),
            ],
          ),
          child: Column(
            children: [
              Container(
                width: 40,
                height: 5,
                margin: const EdgeInsets.only(top: 16, bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.grey.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(5),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: primaryColor(context).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.info_outline,
                        color: primaryColor(context),
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Text(
                      'Investment Tips',
                      style: GoogleFonts.outfit(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: primaryColor(context),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  physics: const BouncingScrollPhysics(),
                  children: [
                    _buildTipCard(
                      context,
                      icon: Icons.bar_chart,
                      title: 'Diversify Your Portfolio',
                      description:
                          'Spread your investments across different asset classes to reduce risk. A balanced portfolio typically includes stocks, bonds, and other investment vehicles.',
                    ),
                    _buildTipCard(
                      context,
                      icon: Icons.schedule,
                      title: 'Invest Regularly',
                      description:
                          'Consider setting up automatic investments on a regular schedule. This strategy, known as dollar-cost averaging, can help reduce the impact of market volatility.',
                    ),
                    _buildTipCard(
                      context,
                      icon: Icons.trending_up,
                      title: 'Long-term Focus',
                      description:
                          'Historically, markets have trended upward over the long term despite short-term fluctuations. Stay focused on your long-term financial goals.',
                    ),
                    _buildTipCard(
                      context,
                      icon: Icons.account_balance,
                      title: 'Emergency Fund First',
                      description:
                          'Before investing heavily, ensure you have an emergency fund covering 3-6 months of expenses in easily accessible accounts.',
                    ),
                    _buildTipCard(
                      context,
                      icon: Icons.school,
                      title: 'Continue Learning',
                      description:
                          'Financial markets evolve continuously. Stay informed about investment strategies and economic trends to make better decisions.',
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () => Navigator.pop(context),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryColor(context),
                          foregroundColor: inversePrimaryColor(context),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: Text(
                          'Got it',
                          style: GoogleFonts.outfit(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTipCard(BuildContext context,
      {required IconData icon,
      required String title,
      required String description}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: shadowColor(context).withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: primaryColor(context).withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              icon,
              color: primaryColor(context),
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.outfit(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).textTheme.bodyLarge?.color,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  description,
                  style: GoogleFonts.outfit(
                    fontSize: 14,
                    color: Theme.of(context)
                        .textTheme
                        .bodyLarge
                        ?.color
                        ?.withOpacity(0.7),
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// Custom painter for dot pattern
class DotPatternPainter extends CustomPainter {
  final int rows;
  final int cols;
  final double spacing;
  final double dotSize;
  final Color color;

  DotPatternPainter({
    required this.rows,
    required this.cols,
    required this.spacing,
    required this.dotSize,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    for (int i = 0; i < rows; i++) {
      for (int j = 0; j < cols; j++) {
        final x = j * (dotSize + spacing);
        final y = i * (dotSize + spacing);
        canvas.drawCircle(Offset(x, y), dotSize / 2, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return false;
  }
}
