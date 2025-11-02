import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wallone/state/userprofile_provider.dart';
import 'package:wallone/utils/constants.dart';
import 'package:wallone/utils/layout.dart';

class OnboardingPage extends StatefulWidget {
  final VoidCallback? onFinish;
  const OnboardingPage({super.key, this.onFinish});

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
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
          builder: (context) => const UserSetupPage(),
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
                padding: WidgetStatePropertyAll(
                  EdgeInsets.symmetric(
                    horizontal: 40,
                    vertical:
                        currentIndex == onboardingData.length - 1 ? 25 : 16,
                  ),
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

            if (currentIndex != onboardingData.length - 1)
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

//
// ✅ USER SETUP PAGE (after Get Started)
//
class UserSetupPage extends StatefulWidget {
  const UserSetupPage({super.key});

  @override
  State<UserSetupPage> createState() => _UserSetupPageState();
}

class _UserSetupPageState extends State<UserSetupPage> {
  final TextEditingController _nameController = TextEditingController();
  File? _coverImage;
  final ImagePicker _picker = ImagePicker();

  Future<void> pickCoverImage() async {
    try {
      final picked = await _picker.pickImage(source: ImageSource.gallery);
      if (picked != null) {
        setState(() {
          _coverImage = File(picked.path);
        });
        // debug
        // print('Image selected: ${picked.path}');
      }
    } catch (e) {
      // print('Error picking image: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Failed to pick image: $e")),
        );
      }
    }
  }

  Future<void> finishSetup() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Please enter your name")),
        );
      }
      return;
    }

    try {
      // Save via provider so whole app updates immediately
      final profileProvider = context.read<UserProfileProvider>();
      await profileProvider.setName(name);

      if (_coverImage != null) {
        await profileProvider.setImagePath(_coverImage!.path);
      }

      // Still mark onboarding as seen in SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('hasSeenOnboarding', true);

      // Navigate to main layout
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const DesignLayout()),
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Failed to complete setup: $e")),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: mainColor(context),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Spacer(),
            Text(
              "Set Up Profile",
              style: GoogleFonts.outfit(
                color: purpleColors(context),
                fontSize: 30,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 30),

            // Cover Image Picker
            GestureDetector(
              onTap: pickCoverImage,
              child: Container(
                height: 100,
                width: 100,
                decoration: BoxDecoration(
                  color: purpleColors(context).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: purpleColors(context), width: 1),
                ),
                child: _coverImage == null
                    ? Center(
                        child: Icon(
                          Icons.person_2,
                          color: purpleColors(context),
                          size: 30,
                        ),
                      )
                    : ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.file(
                          _coverImage!,
                          fit: BoxFit.cover,
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 50),

            // Name Text Field
            TextField(
              controller: _nameController,
              style: GoogleFonts.outfit(color: primaryColor(context)),
              decoration: InputDecoration(
                labelText: "Enter your name!",
                labelStyle: GoogleFonts.outfit(color: primaryColor(context)),
                enabledBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: purpleColors(context)),
                  borderRadius: BorderRadius.circular(10),
                ),
                focusedBorder: OutlineInputBorder(
                  borderSide:
                      BorderSide(color: purpleColors(context), width: 2),
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),

            const Spacer(),

            ElevatedButton(
              style: ButtonStyle(
                backgroundColor: WidgetStatePropertyAll(
                  purpleColors(context),
                ),
                padding: const WidgetStatePropertyAll(
                  EdgeInsets.symmetric(
                    horizontal: 40,
                    vertical: 16,
                  ),
                ),
                shape: WidgetStatePropertyAll(
                  RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              onPressed: finishSetup,
              child: Text(
                'Continue',
                style: GoogleFonts.outfit(
                  fontSize: 16,
                  color: primaryColor(context),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),

            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}
