import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:wallone/pages/Ai%20Control%20Panel/tabs/ai_settings_tab.dart';
import 'package:wallone/pages/Ai%20Control%20Panel/tabs/insights_tabs.dart';
import 'package:wallone/pages/Ai%20Control%20Panel/tabs/quick_action_tab.dart';
import 'package:wallone/state/adviser_provider.dart';
import 'package:wallone/utils/constants.dart';

/// Main AI Advisor Dashboard Widget
class AIAdvisorDashboard extends StatefulWidget {
  const AIAdvisorDashboard({super.key});

  @override
  State<AIAdvisorDashboard> createState() => _AIAdvisorDashboardState();
}

class _AIAdvisorDashboardState extends State<AIAdvisorDashboard>
    with TickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);

    // Listen for tab changes
    _tabController.addListener(() {
      setState(() {}); // Rebuild UI when tab index changes
    });

    // Auto-refresh insights if needed
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = context.read<AIAdvisorProvider>();
      provider.autoRefreshIfNeeded();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          height: 90,
          margin: const EdgeInsets.symmetric(horizontal: 15),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(15),
            color: boxColor(context),
            boxShadow: [
              BoxShadow(
                color: shadowColor(context).withAlpha(30),
                blurRadius: 10,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: TabBar(
            indicatorColor: boxColor(context),
            dividerColor: boxColor(context),
            unselectedLabelColor: primaryColor(context),
            labelStyle: GoogleFonts.outfit(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: cardTextColor(context),
            ),
            controller: _tabController,
            tabs: [
              _buildTab(
                context,
                label: "Insights",
                icon: Icons.insights,
                isSelected: _tabController.index == 0,
              ),
              _buildTab(
                context,
                label: "Actions",
                icon: Icons.takeout_dining_sharp,
                isSelected: _tabController.index == 1,
              ),
              _buildTab(
                context,
                label: "Settings",
                icon: Icons.settings_outlined,
                isSelected: _tabController.index == 2,
              ),
            ],
          ),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 10.0),
            child: TabBarView(
              controller: _tabController,
              children: const [
                InsightsTab(),
                QuickActionsTab(),
                AISettingsTab(),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTab(BuildContext context,
      {required String label,
      required IconData icon,
      required bool isSelected}) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        color: boxColor(context),
        boxShadow: [
          BoxShadow(
            color: isSelected ? shadowColor(context) : Colors.transparent,
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Tab(
        text: label,
        icon: Icon(icon),
      ),
    );
  }
}

Future<void> _runFullAnalysis(BuildContext context) async {
  final provider = context.read<AIAdvisorProvider>();
  await provider.runFullAnalysis();

  if (context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('AI analysis completed! Check your insights.'),
        duration: Duration(seconds: 3),
      ),
    );
  }
}
