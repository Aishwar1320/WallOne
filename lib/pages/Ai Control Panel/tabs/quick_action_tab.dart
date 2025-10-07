import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:wallone/state/adviser_provider.dart';
import 'package:wallone/utils/constants.dart';

/// Quick Actions Tab
class QuickActionsTab extends StatelessWidget {
  const QuickActionsTab({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AIAdvisorProvider>(
      builder: (context, provider, child) {
        final quickActions = provider.getQuickActions();

        if (quickActions.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.check_circle, size: 64, color: Colors.green),
                const SizedBox(height: 16),
                Text(
                  'No immediate actions needed!',
                  style: GoogleFonts.outfit(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: cardTextColor(context),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Your finances look good.',
                  style: GoogleFonts.outfit(
                    color: budgetTextLight(context),
                  ),
                ),
              ],
            ),
          );
        }

        return Padding(
          padding: const EdgeInsets.only(bottom: 90.0),
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: quickActions.length,
            itemBuilder: (context, index) {
              final action = quickActions[index];
              return _QuickActionCard(action: action);
            },
          ),
        );
      },
    );
  }
}

/// Quick action card widget
class _QuickActionCard extends StatelessWidget {
  final Map<String, dynamic> action;

  const _QuickActionCard({required this.action});

  @override
  Widget build(BuildContext context) {
    final type = action['type'] as String;
    final icon = _getTypeIcon(type);

    return Card(
      elevation: 10,
      shadowColor: shadowColor(context),
      color: boxColor(context),
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: purpleColors(context).withAlpha(55),
          child: Icon(icon, color: purpleColors(context)),
        ),
        title: Text(
          action['title'] ?? '',
          style: GoogleFonts.outfit(
            fontSize: 15,
            fontWeight: FontWeight.bold,
            color: primaryColor(context),
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(action['description'] ?? ''),
            if (action['amount'] != null)
              Text(
                'Amount: ₹${(action['amount'] as num).toStringAsFixed(2)}',
                style: GoogleFonts.outfit(
                  fontWeight: FontWeight.w500,
                  color: budgetTextLight(context),
                ),
              ),
          ],
        ),
        trailing: SizedBox(
          height: 30,
          child: ElevatedButton(
            onPressed: () => _executeAction(context, action['id']),
            style: ElevatedButton.styleFrom(
              backgroundColor: purpleColors(context),
              foregroundColor: Colors.white,
            ),
            child: Text(
              'Apply',
              style: GoogleFonts.outfit(
                fontWeight: FontWeight.bold,
                color: inversePrimaryColor(context),
              ),
            ),
          ),
        ),
        isThreeLine: true,
      ),
    );
  }

  Future<void> _executeAction(BuildContext context, String actionId) async {
    final provider = context.read<AIAdvisorProvider>();
    final success = await provider.executeInsight(actionId);

    if (context.mounted) {
      showCustomSnackBar(
        context,
        success ? 'Action executed successfully!' : 'Failed to execute action',
      );
    }
  }

  IconData _getTypeIcon(String type) {
    switch (type.toLowerCase()) {
      case 'budget':
        return Icons.pie_chart;
      case 'savings':
        return Icons.savings;
      case 'investment':
        return Icons.trending_up;
      case 'expense':
        return Icons.money_off;
      case 'alert':
        return Icons.warning;
      default:
        return Icons.info;
    }
  }
}
