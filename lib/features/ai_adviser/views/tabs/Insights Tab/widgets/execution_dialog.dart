import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:wallone/shared/widgets/custom_text_field.dart';
import 'package:wallone/features/ai_adviser/providers/adviser_provider.dart';
import 'package:wallone/core/utils/constants.dart';
import 'package:wallone/features/ai_adviser/services/rule_based_advisor.dart';

/// Custom execution dialog with your app's theme
class CustomInsightExecutionDialog extends StatefulWidget {
  final FinancialInsight insight;
  final VoidCallback? onExecuted;

  const CustomInsightExecutionDialog({
    super.key,
    required this.insight,
    this.onExecuted,
  });

  @override
  State<CustomInsightExecutionDialog> createState() =>
      _CustomInsightExecutionDialogState();
}

class _CustomInsightExecutionDialogState
    extends State<CustomInsightExecutionDialog> {
  final _nameController = TextEditingController();
  final _amountController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  bool _isExecuting = false;
  Map<String, dynamic> _preview = {};

  @override
  void initState() {
    super.initState();
    _initializePreview();
    _setupControllers();
  }

  void _initializePreview() {
    final aiProvider = Provider.of<AIAdvisorProvider>(context, listen: false);
    _preview = aiProvider.getInsightExecutionPreview(widget.insight.id);
  }

  void _setupControllers() {
    _nameController.text = _preview['recommendedName'] ?? '';
    _amountController.text = _preview['recommendedAmount']?.toString() ?? '';
  }

  @override
  void dispose() {
    _nameController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: boxColor(context),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 400),
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: purpleColors(context).withAlpha(100),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        _getInsightIcon(widget.insight.type),
                        color: purpleColors(context),
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Customize & Execute',
                            style: GoogleFonts.outfit(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: primaryColor(context),
                            ),
                          ),
                          Text(
                            widget.insight.title,
                            style: GoogleFonts.outfit(
                              fontSize: 14,
                              color: budgetTextLight(context),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 20),

                // Description
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: budgetBackgroundLight(context).withAlpha(50),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'What this will do:',
                        style: GoogleFonts.outfit(
                          fontWeight: FontWeight.bold,
                          color: primaryColor(context),
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        widget.insight.description,
                        style: GoogleFonts.outfit(
                          fontSize: 12,
                          color: budgetTextLight(context),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // Form fields
                Text(
                  'Customize Details',
                  style: GoogleFonts.outfit(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: primaryColor(context),
                  ),
                ),

                const SizedBox(height: 16),

                CustomTextField(
                  controller: _nameController,
                  labelText: _getNameFieldLabel(widget.insight.type),
                  prefixIcon: Icons.label_outline,
                ),

                const SizedBox(height: 16),

                CustomTextField(
                  controller: _amountController,
                  labelText: 'Amount (₹)',
                  prefixIcon: Icons.currency_rupee,
                  keyboardType: TextInputType.number,
                ),

                const SizedBox(height: 24),

                // Action buttons
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _isExecuting
                            ? null
                            : () => Navigator.of(context).pop(),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: budgetTextLight(context),
                          side: BorderSide(color: budgetTextLight(context)),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        child: Text(
                          'Cancel',
                          style: GoogleFonts.outfit(
                              fontWeight: FontWeight.bold,
                              color: primaryColor(context)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _isExecuting ? null : _executeInsight,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryColor(context),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        child: _isExecuting
                            ? SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                      primaryColor(context)),
                                ),
                              )
                            : Text(
                                'Execute',
                                style: GoogleFonts.outfit(
                                    fontWeight: FontWeight.bold,
                                    color: inversePrimaryColor(context)),
                              ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _getNameFieldLabel(InsightType type) {
    switch (type) {
      case InsightType.budget:
        return 'Budget Name';
      case InsightType.investment:
        return 'Investment Name';
      case InsightType.savings:
        return 'Savings Goal Name';
      default:
        return 'Name';
    }
  }

  IconData _getInsightIcon(InsightType type) {
    switch (type) {
      case InsightType.budget:
        return Icons.pie_chart;
      case InsightType.investment:
        return Icons.trending_up;
      case InsightType.savings:
        return Icons.savings;
      case InsightType.expense:
        return Icons.money_off;
      case InsightType.alert:
        return Icons.warning;
      default:
        return Icons.info;
    }
  }

  Future<void> _executeInsight() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isExecuting = true;
    });

    try {
      final aiProvider = Provider.of<AIAdvisorProvider>(context, listen: false);

      final success = await aiProvider.executeInsight(
        widget.insight.id,
        customName: _nameController.text.trim().isEmpty
            ? null
            : _nameController.text.trim(),
        customAmount: double.tryParse(_amountController.text.trim()),
      );

      if (success) {
        if (mounted) {
          showCustomSnackBar(
              context, 'Successfully applied: ${widget.insight.title}');
          Navigator.of(context).pop();
          widget.onExecuted?.call();
        }
      } else {
        if (mounted) {
          showCustomSnackBar(
              context, 'Failed to apply changes. Please try again.');
        }
      }
    } catch (e) {
      if (mounted) {
        showCustomSnackBar(context, 'Error: $e');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isExecuting = false;
        });
      }
    }
  }
}
