import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:wallone/state/adviser_provider.dart';
import 'package:wallone/utils/constants.dart';

/// AI Settings Tab
class AISettingsTab extends StatelessWidget {
  const AISettingsTab({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: mainColor(context),
      appBar: AppBar(
        title: Text(
          "AI Advisor Settings",
          style: GoogleFonts.outfit(
            color: primaryColor(context),
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new, color: primaryColor(context)),
          onPressed: () => Navigator.pop(context),
        ),
        backgroundColor: mainColor(context),
        elevation: 0,
      ),
      body: Consumer<AIAdvisorProvider>(
        builder: (context, provider, child) {
          return ListView(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            children: [
              _buildSettingsSection(
                'AI Features',
                [
                  SwitchListTile(
                    title: Text(
                      'Enable AI Advisor',
                      style: GoogleFonts.outfit(
                        fontWeight: FontWeight.bold,
                        color: primaryColor(context),
                      ),
                    ),
                    subtitle: Text(
                      'Get AI-powered financial insights',
                      style: GoogleFonts.outfit(
                        color: budgetTextLight(context),
                      ),
                    ),
                    value: provider.isAIEnabled,
                    onChanged: provider.setAIEnabled,
                  ),
                  // SwitchListTile(
                  //   title: Text(
                  //     'Smart Notifications',
                  //     style: GoogleFonts.outfit(
                  //       fontWeight: FontWeight.bold,
                  //       color: primaryColor(context),
                  //     ),
                  //   ),
                  //   subtitle: Text(
                  //     'Get notified about important insights',
                  //     style: GoogleFonts.outfit(
                  //       color: budgetTextLight(context),
                  //     ),
                  //   ),
                  //   value: provider.smartNotifications,
                  //   onChanged: provider.setSmartNotifications,
                  // ),
                ],
                context,
              ),
              _buildSettingsSection(
                'Automation',
                [
                  SwitchListTile(
                    title: Text(
                      'Auto Budget Optimization',
                      style: GoogleFonts.outfit(
                        fontWeight: FontWeight.bold,
                        color: primaryColor(context),
                      ),
                    ),
                    subtitle: Text(
                      'Automatically optimize your budgets',
                      style: GoogleFonts.outfit(
                        color: budgetTextLight(context),
                      ),
                    ),
                    value: provider.autoBudgetOptimization,
                    onChanged: provider.setAutoBudgetOptimization,
                  ),
                  SwitchListTile(
                    title: Text(
                      'Auto Investment Suggestions',
                      style: GoogleFonts.outfit(
                        fontWeight: FontWeight.bold,
                        color: primaryColor(context),
                      ),
                    ),
                    subtitle: Text(
                      'Automatically apply investment recommendations',
                      style: GoogleFonts.outfit(
                        color: budgetTextLight(context),
                      ),
                    ),
                    value: provider.autoInvestmentSuggestions,
                    onChanged: provider.setAutoInvestmentSuggestions,
                  ),
                  // SwitchListTile(
                  //   title: Text(
                  //     'Auto Expense Categorization',
                  //     style: GoogleFonts.outfit(
                  //       fontWeight: FontWeight.bold,
                  //       color: primaryColor(context),
                  //     ),
                  //   ),
                  //   subtitle: Text(
                  //     'Suggest categories for new expenses',
                  //     style: GoogleFonts.outfit(
                  //       color: budgetTextLight(context),
                  //     ),
                  //   ),
                  //   value: provider.autoExpenseCategorization,
                  //   onChanged: provider.setAutoExpenseCategorization,
                  // ),
                ],
                context,
              ),
              _buildSettingsSection(
                'Analysis Frequency',
                [
                  ListTile(
                    title: Text(
                      'Analysis Frequency',
                      style: GoogleFonts.outfit(
                        fontWeight: FontWeight.bold,
                        color: primaryColor(context),
                      ),
                    ),
                    subtitle: Text(
                      'Every ${provider.analysisFrequencyHours} hours',
                      style: GoogleFonts.outfit(
                        color: budgetTextLight(context),
                      ),
                    ),
                    trailing: DropdownButton<int>(
                      value: provider.analysisFrequencyHours,
                      items: [
                        DropdownMenuItem(
                            value: 6,
                            child: Text(
                              '6 hours',
                              style: GoogleFonts.outfit(
                                color: budgetTextLight(context),
                              ),
                            )),
                        DropdownMenuItem(
                            value: 12,
                            child: Text(
                              '12 hours',
                              style: GoogleFonts.outfit(
                                color: budgetTextLight(context),
                              ),
                            )),
                        DropdownMenuItem(
                            value: 24,
                            child: Text(
                              '24 hours',
                              style: GoogleFonts.outfit(
                                color: budgetTextLight(context),
                              ),
                            )),
                        DropdownMenuItem(
                            value: 48,
                            child: Text(
                              '48 hours',
                              style: GoogleFonts.outfit(
                                color: budgetTextLight(context),
                              ),
                            )),
                        DropdownMenuItem(
                            value: 168,
                            child: Text(
                              'Weekly',
                              style: GoogleFonts.outfit(
                                color: budgetTextLight(context),
                              ),
                            )),
                      ],
                      onChanged: (value) {
                        if (value != null) {
                          provider.setAnalysisFrequency(value);
                        }
                      },
                    ),
                  ),
                ],
                context,
              ),
              _buildSettingsSection(
                'Data Management',
                [
                  ListTile(
                    title: Text(
                      'Clear AI Cache',
                      style: GoogleFonts.outfit(
                        fontWeight: FontWeight.bold,
                        color: primaryColor(context),
                      ),
                    ),
                    subtitle: Text(
                      'Remove cached insights and data',
                      style: GoogleFonts.outfit(
                        color: budgetTextLight(context),
                      ),
                    ),
                    trailing: TextButton(
                      onPressed: () => _clearCache(context, provider),
                      child: Text(
                        'Clear',
                        style: GoogleFonts.outfit(
                          color: budgetTextLight(context),
                        ),
                      ),
                    ),
                  ),
                ],
                context,
              ),
              const SizedBox(
                height: 85,
              )
            ],
          );
        },
      ),
    );
  }

  Widget _buildSettingsSection(
      String title, List<Widget> children, BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
          child: Text(
            title,
            style: GoogleFonts.outfit(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: budgetTextLight(context),
            ),
          ),
        ),
        Card(
          elevation: 10,
          color: boxColor(context),
          shadowColor: shadowColor(context),
          child: Column(children: children),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  Future<void> _clearCache(
      BuildContext context, AIAdvisorProvider provider) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Clear AI Cache',
          style: GoogleFonts.outfit(
            fontWeight: FontWeight.bold,
            color: primaryColor(context),
          ),
        ),
        content: Text(
          'This will remove all cached insights and force a fresh analysis. Continue?',
          style: GoogleFonts.outfit(
            color: budgetTextLight(context),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'Cancel',
              style: GoogleFonts.outfit(
                color: budgetTextLight(context),
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              'Clear',
              style: GoogleFonts.outfit(
                color: primaryColor(context),
              ),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await provider.clearCache();
      if (context.mounted) {
        showCustomSnackBar(context, 'AI cache cleared successfully');
      }
    }
  }
}
