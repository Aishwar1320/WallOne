import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:wallone/core/utils/constants.dart';

class InvestmentEmptyState extends StatelessWidget {
  final VoidCallback onAddInvestment;

  const InvestmentEmptyState({
    super.key,
    required this.onAddInvestment,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: boxColor(context),
              shape: BoxShape.circle,
              border: Border.all(
                color: shadowColor(context),
              ),
            ),
            child: Icon(
              Icons.trending_up,
              size: 32,
              color: primaryColor(context),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'No Investments Yet',
            style: GoogleFonts.outfit(
              fontSize: 22,
              fontWeight: FontWeight.w600,
              color: primaryColor(context),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Start growing your wealth by adding investments or savings',
            textAlign: TextAlign.center,
            style: GoogleFonts.outfit(
              fontSize: 16,
              color: budgetTextLight(context),
              height: 1.5,
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: onAddInvestment,
            icon: Icon(
              color: primaryColor(context),
              Icons.add_rounded,
            ),
            label: Text(
              'Add Investment',
              style: GoogleFonts.outfit(
                fontWeight: FontWeight.w600,
                color: primaryColor(context),
              ),
            ),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(
                horizontal: 28,
                vertical: 14,
              ),
              backgroundColor: boxColor(context),
              foregroundColor: Colors.white,
              elevation: 4,
              shadowColor: shadowColor(context),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
