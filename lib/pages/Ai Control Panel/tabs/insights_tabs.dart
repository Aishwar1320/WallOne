import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:wallone/state/adviser_provider.dart';
import 'package:wallone/utils/constants.dart';
import 'package:wallone/utils/services/gemini_service.dart';

/// Individual insight card widget
class InsightCard extends StatelessWidget {
  final FinancialInsight insight;

  const InsightCard({super.key, required this.insight});

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
              ],
            ),
            const SizedBox(height: 8),
            Text(
              insight.description,
              style: GoogleFonts.outfit(
                fontSize: 12,
                color: budgetTextLight(context),
              ),
            ),
            if (insight.recommendedAmount != null) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: purpleColors(context).withAlpha(90),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Recommended: ₹${insight.recommendedAmount!.toStringAsFixed(2)}',
                  style: GoogleFonts.outfit(
                    fontSize: 12,
                    color: purpleColors(context),
                  ),
                ),
              ),
            ],
            if (insight.isActionable) ...[
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  SizedBox(
                    height: 25,
                    child: ElevatedButton.icon(
                      onPressed: () => _executeInsight(context, insight.id),
                      icon: const Icon(Icons.play_arrow, size: 15),
                      label: Text(
                        'Apply',
                        style: GoogleFonts.outfit(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: purpleColors(context),
                        foregroundColor: inversePrimaryColor(context),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildPriorityChip(InsightPriority priority, BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
      decoration: BoxDecoration(
        color: purpleColors(context),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        priority.name,
        style: GoogleFonts.outfit(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: inversePrimaryColor(context),
        ),
      ),
    );
  }

  Future<void> _executeInsight(BuildContext context, String insightId) async {
    final provider = context.read<AIAdvisorProvider>();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(),
      ),
    );

    final success = await provider.executeInsight(insightId);

    if (context.mounted) {
      Navigator.pop(context); // Close loading dialog

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            success
                ? 'Action executed successfully!'
                : 'Failed to execute action',
            style: GoogleFonts.outfit(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: primaryColor(context),
            ),
          ),
          backgroundColor: success ? Colors.green : Colors.red,
        ),
      );
    }
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
      case InsightType.alert:
        return Icons.warning;
      case InsightType.general:
        return Icons.info;
    }
  }
}

/// Insights Tab showing AI-generated financial insights
class InsightsTab extends StatelessWidget {
  const InsightsTab({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AIAdvisorProvider>(
      builder: (context, provider, child) {
        if (!provider.hasAdvisor) {
          return const _SetupRequiredWidget();
        }

        if (!provider.isAIEnabled) {
          return const _AIDisabledWidget();
        }

        if (provider.error != null) {
          return _ErrorWidget(error: provider.error!);
        }

        if (provider.insights.isEmpty && !provider.isLoading) {
          return const _NoInsightsWidget();
        }

        return RefreshIndicator(
          onRefresh: () => provider.refreshInsights(forceRefresh: true),
          child: CustomScrollView(
            slivers: [
              _buildHealthScoreSection(provider, context),
              _buildInsightsList(provider),
              SliverToBoxAdapter(
                child: SizedBox(
                  height: MediaQuery.of(context).padding.bottom +
                      kBottomNavigationBarHeight +
                      10.0,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildHealthScoreSection(
      AIAdvisorProvider provider, BuildContext context) {
    final score = provider.getFinancialHealthScore();
    final color = _getHealthScoreColor(score);

    return SliverToBoxAdapter(
      child: Container(
        margin: const EdgeInsets.only(bottom: 16, right: 16, left: 16),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: boxColor(context),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: shadowColor(context).withAlpha(20),
              blurRadius: 10,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Column(
          children: [
            Text(
              'Financial Health Score',
              style: GoogleFonts.outfit(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: primaryColor(context),
              ),
            ),
            const SizedBox(height: 12),
            Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 120,
                  height: 120,
                  child: CircularProgressIndicator(
                    value: score / 100,
                    strokeWidth: 8,
                    backgroundColor: color.withAlpha(55),
                    valueColor: AlwaysStoppedAnimation<Color>(color),
                  ),
                ),
                Text(
                  '$score',
                  style: GoogleFonts.outfit(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              _getHealthScoreDescription(score),
              textAlign: TextAlign.center,
              style: GoogleFonts.outfit(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: primaryColor(context),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInsightsList(AIAdvisorProvider provider) {
    final insights = provider.insights;

    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          final insight = insights[index];
          return InsightCard(insight: insight);
        },
        childCount: insights.length,
      ),
    );
  }

  Color _getHealthScoreColor(int score) {
    if (score >= 80) return Colors.green;
    if (score >= 60) return Colors.orange;
    return Colors.red;
  }

  String _getHealthScoreDescription(int score) {
    if (score >= 80) return 'Excellent financial health!';
    if (score >= 60) return 'Good, with room for improvement';
    if (score >= 40) return 'Needs attention';
    return 'Requires immediate action';
  }
}

// Setup required widget
class _SetupRequiredWidget extends StatelessWidget {
  const _SetupRequiredWidget();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.settings, size: 64, color: budgetTextLight(context)),
          const SizedBox(height: 16),
          Text(
            'AI Advisor Setup Required',
            style: GoogleFonts.outfit(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: primaryColor(context),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Configure your Gemini API key to get started',
            style: GoogleFonts.outfit(
              fontWeight: FontWeight.bold,
              color: budgetTextLight(context),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

/// AI disabled widget
class _AIDisabledWidget extends StatelessWidget {
  const _AIDisabledWidget();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.smart_toy_outlined,
              size: 64, color: budgetTextLight(context)),
          const SizedBox(height: 16),
          Text(
            'AI Advisor Disabled',
            style: GoogleFonts.outfit(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: primaryColor(context),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Enable AI features in settings to get personalized insights',
            style: GoogleFonts.outfit(
              fontWeight: FontWeight.bold,
              color: budgetTextLight(context),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () {
              final provider = context.read<AIAdvisorProvider>();
              provider.setAIEnabled(true);
            },
            child: Text(
              'Enable AI Advisor',
              style: GoogleFonts.outfit(
                fontWeight: FontWeight.bold,
                color: primaryColor(context),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Error widget
class _ErrorWidget extends StatelessWidget {
  final String error;

  const _ErrorWidget({required this.error});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            Text(
              'Something went wrong',
              style: GoogleFonts.outfit(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: primaryColor(context),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              error,
              style: GoogleFonts.outfit(
                fontWeight: FontWeight.bold,
                color: primaryColor(context),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                final provider = context.read<AIAdvisorProvider>();
                provider.refreshInsights(forceRefresh: true);
              },
              child: Text(
                'Try Again',
                style: GoogleFonts.outfit(
                  fontWeight: FontWeight.bold,
                  color: primaryColor(context),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// No insights widget
class _NoInsightsWidget extends StatelessWidget {
  const _NoInsightsWidget();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.lightbulb_outline,
            size: 64,
            color: budgetTextLight(context),
          ),
          const SizedBox(height: 16),
          Text(
            'No insights yet',
            style: GoogleFonts.outfit(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: primaryColor(context),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Add some transactions and let AI analyze your spending patterns',
            style: GoogleFonts.outfit(
              fontWeight: FontWeight.bold,
              color: primaryColor(context),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () {
              final provider = context.read<AIAdvisorProvider>();
              provider.refreshInsights(forceRefresh: true);
            },
            child: Text(
              'Generate Insights',
              style: GoogleFonts.outfit(
                fontWeight: FontWeight.bold,
                color: primaryColor(context),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
