import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:wallone/features/ai_adviser/views/tabs/Insights%20Tab/insights_tabs.dart';
import 'package:wallone/features/ai_adviser/providers/adviser_provider.dart';

/// Simplified AI Advisor Dashboard
/// In V1, all users have access to AI insights.
class AIAdvisorDashboard extends StatefulWidget {
  const AIAdvisorDashboard({super.key});

  @override
  State<AIAdvisorDashboard> createState() => _AIAdvisorDashboardState();
}

class _AIAdvisorDashboardState extends State<AIAdvisorDashboard> {
  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await Future.delayed(Duration.zero); // Let the build fully settle
      if (!mounted) return;
      final provider = context.read<AIAdvisorProvider>();
      provider.autoRefreshIfNeeded();
    });
  }

  @override
  Widget build(BuildContext context) {
    return const InsightsTab();
  }
}
