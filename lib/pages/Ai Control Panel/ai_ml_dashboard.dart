import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:wallone/pages/Ai%20Control%20Panel/tabs/ai_settings_tab.dart';
import 'package:wallone/pages/Ai%20Control%20Panel/tabs/Insights%20Tab/insights_tabs.dart';
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
    _tabController = TabController(length: 2, vsync: this);

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
          height: 70,
          width: 300,
          margin: const EdgeInsets.only(top: 16, right: 16, left: 16),
          padding: const EdgeInsets.symmetric(vertical: 8),
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
          child: Material(
            color: Colors.transparent,
            child: TabBar(
              overlayColor: WidgetStatePropertyAll(boxColor(context)),
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
                  label: "Settings",
                  icon: Icons.settings_outlined,
                  isSelected: _tabController.index == 1,
                ),
              ],
            ),
          ),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 15.0),
            child: TabBarView(
              controller: _tabController,
              children: const [
                InsightsTab(),
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
