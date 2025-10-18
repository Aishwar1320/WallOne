import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:wallone/utils/constants.dart';
import 'package:wallone/utils/layout.dart';

class OnboardingPage extends StatefulWidget {
  const OnboardingPage({super.key});

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  // ✅ Onboarding data list
  final List<Map<String, String>> onboardingData = [
    {
      'title': 'Take Control of Your Finances',
      'subtitle':
          'Welcome to WallOne! Your personal financial companion. Take control of your money effortlessly with powerful tools to track and manage your finances.',
    },
    {
      'title': 'Budget Smarter',
      'subtitle':
          'Set your monthly budget, monitor spending habits, and receive smart insights to save more effectively every month.',
    },
    {
      'title': 'Streamline Your Finances',
      'subtitle':
          'Use your personal AI Advisor for efficient savings and budget planning making financial management automated and intelligent!',
    },
  ];

  int currentIndex = 0;

  void nextPage() {
    if (currentIndex < onboardingData.length - 1) {
      setState(() {
        currentIndex++;
      });
    } else {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) {
            return const DesignLayout();
          },
        ),
      );
    }
  }

  void skipOnboarding() {
    setState(() {
      currentIndex = onboardingData.length - 1;
    });
  }

  @override
  Widget build(BuildContext context) {
    final current = onboardingData[currentIndex];

    return Scaffold(
      backgroundColor: mainColor(context),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0),
        child: Column(
          spacing: 20,
          children: [
            const SizedBox(height: 60),

            // App Title
            Text(
              "WallOne",
              style: GoogleFonts.outfit(
                fontSize: 30,
                color: purpleColors(context),
                fontWeight: FontWeight.bold,
              ),
            ),

            const Spacer(),

            // Dynamic Title
            Text(
              current['title']!,
              textAlign: TextAlign.center,
              style: GoogleFonts.outfit(
                fontSize: 22,
                color: purpleColors(context),
                fontWeight: FontWeight.bold,
              ),
            ),

            // Dynamic Subtitle
            Text(
              current['subtitle']!,
              textAlign: TextAlign.center,
              style: GoogleFonts.outfit(
                fontSize: 15,
                color: primaryColor(context),
                fontWeight: FontWeight.w500,
              ),
            ),

            const SizedBox(height: 20),

            // Buttons
            ElevatedButton(
              style: ButtonStyle(
                backgroundColor: WidgetStatePropertyAll(
                  purpleColors(context),
                ),
                padding: const WidgetStatePropertyAll(
                  EdgeInsets.symmetric(horizontal: 40, vertical: 16),
                ),
                shape: WidgetStatePropertyAll(
                  RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              onPressed: nextPage,
              child: Text(
                currentIndex == onboardingData.length - 1
                    ? "Get Started"
                    : "Next",
                style: GoogleFonts.outfit(
                  fontSize: 16,
                  color: primaryColor(context),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),

            TextButton(
              onPressed: skipOnboarding,
              child: Text(
                "Skip",
                style: GoogleFonts.outfit(
                  fontSize: 15,
                  color: primaryColor(context),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),

            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }
}
