import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:wallone/state/adviser_provider.dart';
import 'package:wallone/utils/constants.dart';

class HealthScoreSection extends StatelessWidget {
  final AIAdvisorProvider provider;

  const HealthScoreSection({
    super.key,
    required this.provider,
  });

  @override
  Widget build(BuildContext context) {
    final score = provider.getFinancialHealthScore();
    final color = _getHealthScoreColor(score);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
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
      child: Row(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Financial Health Score',
                style: GoogleFonts.outfit(
                  fontSize: MediaQuery.of(context).size.width / 23,
                  fontWeight: FontWeight.bold,
                  color: purpleColors(context),
                ),
              ),
              SizedBox(
                width: MediaQuery.of(context).size.width / 2,
                child: Text(
                  _getHealthScoreDescription(score),
                  style: GoogleFonts.outfit(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: primaryColor(context),
                  ),
                ),
              ),
            ],
          ),
          Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                width: MediaQuery.of(context).size.width / 3.2,
                height: MediaQuery.of(context).size.width / 3.2,
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
        ],
      ),
    );
  }

  Color _getHealthScoreColor(int score) {
    if (score >= 80) return Colors.green;
    if (score >= 60) return Colors.orange;
    return Colors.red;
  }

  String _getHealthScoreDescription(int score) {
    if (score >= 80) return 'Excellent financial health! Keep it up.';
    if (score >= 60) return 'Good financial health with room for improvement.';
    if (score >= 40) return 'Fair financial health. Consider the suggestions.';
    return 'Financial health needs attention. Take action now.';
  }
}
