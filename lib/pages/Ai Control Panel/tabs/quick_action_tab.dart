import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:wallone/state/adviser_provider.dart';

/// Quick Actions Tab
class QuickActionsTab extends StatelessWidget {
  const QuickActionsTab({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Consumer<AIAdvisorProvider>(
      builder: (context, provider, child) {
        final quickActions = provider.getQuickActions();

        if (quickActions.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.check_circle, size: 64, color: Colors.green),
                SizedBox(height: 16),
                Text(
                  'No immediate actions needed!',
                  style: TextStyle(fontSize: 18),
                ),
                SizedBox(height: 8),
                Text(
                  'Your finances look good.',
                  style: TextStyle(color: Colors.grey),
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
    final priority = action['priority'] as String;
    final type = action['type'] as String;
    final color = _getPriorityColor(priority);
    final icon = _getTypeIcon(type);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: color.withOpacity(0.2),
          child: Icon(icon, color: color),
        ),
        title: Text(
          action['title'] ?? '',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(action['description'] ?? ''),
            if (action['amount'] != null)
              Text(
                'Amount: ₹${(action['amount'] as num).toStringAsFixed(2)}',
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.w500,
                ),
              ),
          ],
        ),
        trailing: ElevatedButton(
          onPressed: () => _executeAction(context, action['id']),
          style: ElevatedButton.styleFrom(
            backgroundColor: color,
            foregroundColor: Colors.white,
          ),
          child: const Text('Apply'),
        ),
        isThreeLine: true,
      ),
    );
  }

  Future<void> _executeAction(BuildContext context, String actionId) async {
    final provider = context.read<AIAdvisorProvider>();
    final success = await provider.executeInsight(actionId);

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(success
              ? 'Action executed successfully!'
              : 'Failed to execute action'),
          backgroundColor: success ? Colors.green : Colors.red,
        ),
      );
    }
  }

  Color _getPriorityColor(String priority) {
    switch (priority.toLowerCase()) {
      case 'high':
        return Colors.red;
      case 'medium':
        return Colors.orange;
      case 'low':
        return Colors.green;
      default:
        return Colors.blue;
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
