import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:wallone/pages/Ai%20Control%20Panel/tabs/Insights%20Tab/insights_tabs.dart';
import 'package:wallone/state/adviser_provider.dart';

/// Simplified AI Advisor Dashboard — Only shows InsightsTab
class AIAdvisorDashboard extends StatefulWidget {
  const AIAdvisorDashboard({super.key});

  @override
  State<AIAdvisorDashboard> createState() => _AIAdvisorDashboardState();
}

class _AIAdvisorDashboardState extends State<AIAdvisorDashboard> {
  @override
  void initState() {
    super.initState();

    // Auto-refresh insights if needed
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = context.read<AIAdvisorProvider>();
      provider.autoRefreshIfNeeded();
    });
  }

  @override
  Widget build(BuildContext context) {
    return const InsightsTab();
  }
}
