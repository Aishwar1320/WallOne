// Placeholder widgets - you'll need to implement these based on your existing code
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:wallone/core/utils/constants.dart';

class SetupRequiredWidget extends StatelessWidget {
  const SetupRequiredWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.settings,
              size: 64,
              color: budgetTextLight(context),
            ),
            const SizedBox(height: 16),
            Text(
              'AI Advisor Setup Required',
              style: GoogleFonts.outfit(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: primaryColor(context),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Please configure your AI advisor in settings to get personalized insights.',
              textAlign: TextAlign.center,
              style: GoogleFonts.outfit(
                fontSize: 14,
                color: budgetTextLight(context),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class AIDisabledWidget extends StatelessWidget {
  const AIDisabledWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.smart_toy_outlined,
              size: 64,
              color: budgetTextLight(context),
            ),
            const SizedBox(height: 16),
            Text(
              'AI Advisor Disabled',
              style: GoogleFonts.outfit(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: primaryColor(context),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Enable AI advisor in settings to get smart financial insights.',
              textAlign: TextAlign.center,
              style: GoogleFonts.outfit(
                fontSize: 14,
                color: budgetTextLight(context),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ErrorCustomWidget extends StatelessWidget {
  final String error;

  const ErrorCustomWidget({super.key, required this.error});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: Colors.red.shade400,
            ),
            const SizedBox(height: 16),
            Text(
              'Error Loading Insights',
              style: GoogleFonts.outfit(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: primaryColor(context),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              error,
              textAlign: TextAlign.center,
              style: GoogleFonts.outfit(
                fontSize: 14,
                color: budgetTextLight(context),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
