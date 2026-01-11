import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:wallone/pages/Ai%20Control%20Panel/tabs/Insights%20Tab/widgets/execution_dialog.dart';
import 'package:wallone/state/adviser_provider.dart';
import 'package:wallone/utils/constants.dart';
import 'package:wallone/utils/services/rule_based_advisor.dart';

/// Enhanced InsightCard with dismissal and custom execution features
class InsightCard extends StatelessWidget {
  final FinancialInsight insight;
  final VoidCallback? onRefresh;

  const InsightCard({
    super.key,
    required this.insight,
    this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    final typeIcon = _getTypeIcon(insight.type);

    return Card(
      color: boxColor(context),
      elevation: 10,
      shadowColor: shadowColor(context),
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with dismiss button
            Row(
              children: [
                Icon(typeIcon, size: 20, color: cardTextColor(context)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    insight.title,
                    style: GoogleFonts.outfit(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: cardTextColor(context),
                    ),
                  ),
                ),
                _buildPriorityChip(insight.priority, context),
                const SizedBox(width: 8),
                // Dismiss button
                InkWell(
                  onTap: () => _dismissInsight(context),
                  borderRadius: BorderRadius.circular(16),
                  child: Padding(
                    padding: const EdgeInsets.all(4),
                    child: Icon(
                      Icons.close,
                      size: 18,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 8),

            // Description
            Text(
              insight.description,
              style: GoogleFonts.outfit(
                fontSize: 12,
                color: budgetTextLight(context),
              ),
            ),

            const SizedBox(height: 12),

            // Bottom section with amount and actions
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Recommended amount
                if (insight.recommendedAmount != null)
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: purpleColors(context).withAlpha(90),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'Recommended: ₹${insight.recommendedAmount!.toStringAsFixed(2)}',
                        style: GoogleFonts.outfit(
                          fontSize: 12,
                          color: primaryColor(context),
                        ),
                      ),
                    ),
                  ),

                if (insight.recommendedAmount != null && insight.isActionable)
                  const SizedBox(width: 15),

                // Action buttons
                if (insight.isActionable)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Quick apply button
                      SizedBox(
                        height: 28,
                        child: ElevatedButton.icon(
                          onPressed: () => _quickExecuteInsight(context),
                          icon: const Icon(Icons.flash_on, size: 13),
                          label: Text(
                            'Quick Apply',
                            style: GoogleFonts.outfit(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: purpleColors(context),
                            foregroundColor: primaryColor(context),
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                          ),
                        ),
                      ),

                      const SizedBox(width: 6),

                      // Custom apply button
                      SizedBox(
                        height: 28,
                        child: OutlinedButton.icon(
                          onPressed: () => _showCustomExecutionDialog(context),
                          icon: const Icon(Icons.tune, size: 13),
                          label: Text(
                            'Custom',
                            style: GoogleFonts.outfit(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: primaryColor(context),
                            side: BorderSide(color: purpleColors(context)),
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                          ),
                        ),
                      ),
                    ],
                  ),
              ],
            ),

            // Insight metadata
            const SizedBox(height: 8),
            Row(
              children: [
                Text(
                  insight.type.name.toUpperCase(),
                  style: GoogleFonts.outfit(
                    fontSize: 10,
                    color: Colors.grey.shade600,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (insight.targetCategory != null) ...[
                  Text(
                    ' • ${insight.targetCategory}',
                    style: GoogleFonts.outfit(
                      fontSize: 10,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
                const Spacer(),
                Text(
                  _formatDateTime(insight.createdAt),
                  style: GoogleFonts.outfit(
                    fontSize: 10,
                    color: Colors.grey.shade500,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPriorityChip(InsightPriority priority, BuildContext context) {
    Color chipColor;
    switch (priority) {
      case InsightPriority.high:
        chipColor = Colors.red;
        break;
      case InsightPriority.medium:
        chipColor = Colors.orange;
        break;
      case InsightPriority.low:
        chipColor = Colors.green;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: chipColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        priority.name.toUpperCase(),
        style: GoogleFonts.outfit(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      ),
    );
  }

  String _formatDateTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inHours < 1) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inDays < 1) {
      return '${difference.inHours}h ago';
    } else {
      return '${difference.inDays}d ago';
    }
  }

  void _dismissInsight(BuildContext context) {
    final provider = context.read<AIAdvisorProvider>();
    provider.dismissInsight(insight.id);

    showCustomSnackBar(
      context,
      'Dismissed: ${insight.title}',
      actionLabel: "Undo",
      onAction: () {
        provider.restoreInsight(insight.id);
      },
    );

    onRefresh?.call();
  }

  Future<void> _quickExecuteInsight(BuildContext context) async {
    final provider = context.read<AIAdvisorProvider>();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(),
      ),
    );

    final success = await provider.executeInsight(insight.id);

    if (context.mounted) {
      Navigator.pop(context); // Close loading dialog

      showCustomSnackBar(
        context,
        success ? 'Applied successfully!' : 'Failed to apply changes',
      );

      onRefresh?.call();
    }
  }

  void _showCustomExecutionDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => CustomInsightExecutionDialog(
        insight: insight,
        onExecuted: onRefresh,
      ),
    );
  }

  IconData _getTypeIcon(InsightType type) {
    switch (type) {
      case InsightType.budget:
        return Icons.pie_chart;
      case InsightType.savings:
        return Icons.savings;
      case InsightType.investment:
        return Icons.trending_up;
      case InsightType.expense:
        return Icons.money_off;
      case InsightType.income:
        return Icons.attach_money;
      case InsightType.alert:
        return Icons.warning;
      case InsightType.general:
        return Icons.info;
    }
  }
}
