import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import 'package:wallone/features/investments/providers/investment_provider.dart';
import 'package:wallone/core/utils/constants.dart';

class InvestmentChart extends StatelessWidget {
  final double screenWidth;

  const InvestmentChart({
    super.key,
    required this.screenWidth,
  });

  /// Builds FlSpots from the percentage history list with smooth interpolation.
  /// Adds intermediate points between each entry for elegant curves.
  List<FlSpot> _buildHistorySpots(List<double> history) {
    if (history.isEmpty) return [];
    if (history.length == 1) {
      return [FlSpot(0, history.first), FlSpot(1, history.first)];
    }

    final spots = <FlSpot>[];
    const int stepsPerSegment = 6; // intermediate points between entries

    for (int i = 0; i < history.length - 1; i++) {
      final y1 = history[i];
      final y2 = history[i + 1];

      for (int s = 0; s < stepsPerSegment; s++) {
        final t = s / stepsPerSegment; // 0.0 … <1.0
        // Smooth ease-in-out interpolation
        final eased = t * t * (3.0 - 2.0 * t);
        final y = y1 + (y2 - y1) * eased;
        final x = i.toDouble() + t;
        spots.add(FlSpot(x, y));
      }
    }
    // Add the final point
    spots.add(FlSpot((history.length - 1).toDouble(), history.last));
    return spots;
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<InvestmentProvider>(context);
    final sw = screenWidth;

    final percentageChange = provider.percentageChange;
    final history = provider.percentageHistory;

    // If there are no investments at all, show empty state
    if (provider.investments.isEmpty) {
      return Container(
        height: 160,
        decoration: BoxDecoration(
          color: boxColor(context),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: const Color(0xFF4C1D95).withValues(alpha: 0.12),
            width: 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF4C1D95).withValues(alpha: 0.06),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.show_chart_rounded,
                  size: 38, color: const Color(0xFF7C3AED).withValues(alpha: 0.35)),
              const SizedBox(height: 8),
              Text(
                'No investment data',
                style: GoogleFonts.outfit(
                  fontSize: sw / 34,
                  color: const Color(0xFF4C1D95).withValues(alpha: 0.4),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Prepend 0.0 so the graph always starts from the bottom left
    final displayHistory = [0.0, ...history];

    // Build spots from history
    List<FlSpot> spots;
    if (displayHistory.length >= 2) {
      // Enough data points for a real graph
      spots = _buildHistorySpots(displayHistory);
    } else {
      // Very unlikely edge case since we prepended 0.0, but just in case
      spots = [const FlSpot(0, 0), const FlSpot(1, 0)];
    }

    // Determine colours based on latest percentage
    final bool isHealthy = percentageChange >= 50;
    final Color stroke =
        isHealthy ? const Color(0xFF4C1D95) : const Color(0xFFDC2626);
    final Color glowMid =
        isHealthy ? const Color(0xFF7C3AED) : const Color(0xFFEF4444);
    final Color bgLight =
        isHealthy ? const Color(0xFFEDE9FE) : const Color(0xFFFEE2E2);

    return _buildChartCard(
      context: context,
      spots: spots,
      stroke: stroke,
      glowMid: glowMid,
      bgLight: bgLight,
      screenWidth: sw,
      percentageChange: percentageChange,
    );
  }

  Widget _buildChartCard({
    required BuildContext context,
    required List<FlSpot> spots,
    required Color stroke,
    required Color glowMid,
    required Color bgLight,
    required double screenWidth,
    required double percentageChange,
  }) {
    // Fixed Y range for percentage (0–100%)
    const double minY = 0.0;
    const double maxY = 105.0; // slight buffer above 100

    // ── X range ──────────────────────────────────────────────────────────────
    const double minXWidth = 6.0; // Show at least "6 intervals" of space
    final minX = spots.first.x - 0.1;

    // If we have less than minXWidth intervals, force maxX to maintain the scale
    final actualXRange = spots.last.x - spots.first.x;
    final maxX = actualXRange < minXWidth
        ? spots.first.x + minXWidth
        : spots.last.x + (actualXRange * 0.02);

    const titlesData = FlTitlesData(
      show: true,
      leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
      rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
      topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
      bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
    );

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: bgLight.withValues(alpha: 0.38),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: stroke.withValues(alpha: 0.08),
          width: 1.0,
        ),
      ),
      padding: const EdgeInsets.only(top: 24, bottom: 2, left: 0, right: 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: 188,
            child: LineChart(
              LineChartData(
                lineTouchData: LineTouchData(
                  handleBuiltInTouches: true,
                  touchSpotThreshold: 44,
                  getTouchedSpotIndicator: (barData, idxs) => idxs.map((idx) {
                    return TouchedSpotIndicatorData(
                      FlLine(
                        color: stroke.withValues(alpha: 0.35),
                        strokeWidth: 1.5,
                        dashArray: [5, 5],
                      ),
                      FlDotData(
                        getDotPainter: (_, __, ___, ____) => FlDotCirclePainter(
                          radius: 5,
                          color: stroke,
                          strokeWidth: 2.5,
                          strokeColor: Colors.white,
                        ),
                      ),
                    );
                  }).toList(),
                  touchTooltipData: LineTouchTooltipData(
                    getTooltipColor: (_) =>
                        const Color(0xFF3B0764).withValues(alpha: 0.92),
                    tooltipRoundedRadius: 12,
                    tooltipPadding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    getTooltipItems: (touched) => touched.map((ts) {
                      final val = ts.y;
                      final text =
                          '${val >= 0 ? '+' : ''}${val.toStringAsFixed(1)}%';
                      return LineTooltipItem(
                        text,
                        GoogleFonts.outfit(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: screenWidth / 31,
                        ),
                      );
                    }).toList(),
                  ),
                ),
                minX: minX,
                maxX: maxX,
                minY: minY,
                maxY: maxY,
                gridData: const FlGridData(show: false),
                borderData: FlBorderData(show: false),
                titlesData: titlesData,
                clipData: const FlClipData.all(),
                lineBarsData: [
                  LineChartBarData(
                    spots: spots,
                    isCurved: true,
                    curveSmoothness: 0.45,
                    preventCurveOverShooting: true,
                    preventCurveOvershootingThreshold: 1.5,
                    color: stroke,
                    barWidth: 2.8,
                    isStrokeCapRound: true,
                    isStrokeJoinRound: true,
                    shadow: Shadow(
                      color: stroke.withValues(alpha: 0.5),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                    dotData: const FlDotData(show: false),
                    belowBarData: BarAreaData(
                      show: true,
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        stops: const [0.0, 0.55, 1.0],
                        colors: [
                          glowMid.withValues(alpha: 0.28),
                          glowMid.withValues(alpha: 0.07),
                          bgLight.withValues(alpha: 0.0),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              duration: const Duration(milliseconds: 450),
              curve: Curves.easeOutCubic,
            ),
          ),
        ],
      ),
    );
  }
}

