import 'dart:io';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wallone/pages/Ai%20Control%20Panel/tabs/ai_settings_tab.dart';
import 'package:wallone/state/adviser_provider.dart';
import 'package:wallone/state/budget_provider.dart';
import 'package:wallone/state/category_provider.dart';
import 'package:wallone/state/investment_provider.dart';
import 'package:wallone/state/theme_provider.dart';
import 'package:wallone/state/balance_provider.dart';
import 'package:wallone/state/userprofile_provider.dart';
import 'package:wallone/utils/constants.dart';
import 'package:wallone/pages/Category%20Management/category_management.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  String? userName;
  String? coverImagePath;
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      userName = prefs.getString('userName');
      coverImagePath = prefs.getString('coverImagePath');
    });
  }

  Future<void> _pickImage() async {
    try {
      final XFile? picked =
          await _picker.pickImage(source: ImageSource.gallery);
      if (picked == null) return;

      // Save via provider so everyone updates instantly
      await context.read<UserProfileProvider>().setImagePath(picked.path);

      if (!mounted) return;
      setState(() {
        coverImagePath = picked.path; // keep local UI in sync
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile image updated')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to pick image: $e')),
      );
    }
  }

  Future<void> _editName() async {
    final controller = TextEditingController(text: userName ?? '');
    final newName = await showDialog<String?>(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadiusGeometry.circular(10),
          ),
          title: Text(
            'Edit Name',
            style: GoogleFonts.outfit(
              color: primaryColor(context),
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: TextField(
            style: GoogleFonts.outfit(
              color: primaryColor(context),
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
            controller: controller,
            decoration: const InputDecoration(
              labelText: 'Name',
              hintText: 'Enter your name',
            ),
            autofocus: true,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, null),
              child: Text(
                'Cancel',
                style: GoogleFonts.outfit(
                  color: primaryColor(context),
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            TextButton(
              onPressed: () {
                final val = controller.text.trim();
                Navigator.pop(context, val.isEmpty ? null : val);
              },
              child: Text(
                'Save',
                style: GoogleFonts.outfit(
                  color: purpleColors(context),
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        );
      },
    );

    if (newName == null) return;
// Save via provider
    await context.read<UserProfileProvider>().setName(newName);

    if (!mounted) return;
    setState(() => userName = newName);

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Name updated')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final screenWidth = MediaQuery.of(context).size.width;

    return Scaffold(
      onDrawerChanged: (isOpened) {
        if (isOpened) {
          _loadUserData();
        }
      },

      //
      backgroundColor: mainColor(context),
      appBar: AppBar(
        title: Text(
          'Settings',
          style: GoogleFonts.outfit(
            color: primaryColor(context),
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        leading: IconButton(
            icon: Icon(Icons.arrow_back_ios_new, color: primaryColor(context)),
            onPressed: () async {
              Navigator.pop(context);

              await _loadUserData();
            }),
        elevation: 0,
        backgroundColor: mainColor(context),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(10.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 20),
              Align(
                alignment: Alignment.center,
                child: Column(
                  children: [
                    // tappable avatar to change image
                    Stack(
                      children: [
                        Container(
                          decoration: BoxDecoration(
                              color: mainColor(context),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: boxColor(context),
                                width: 3,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: shadowColor(context),
                                  blurRadius: 5,
                                )
                              ]),
                          child: ClipOval(
                            child: coverImagePath != null &&
                                    File(coverImagePath!).existsSync()
                                ? Image.file(
                                    File(coverImagePath!),
                                    width: 120,
                                    height: 120,
                                    fit: BoxFit.cover,
                                    errorBuilder: (context, error, stackTrace) {
                                      return CircleAvatar(
                                        radius: 60,
                                        backgroundColor:
                                            purpleColors(context).withAlpha(50),
                                        child: Icon(
                                          Icons.person,
                                          size: 40,
                                          color: purpleColors(context),
                                        ),
                                      );
                                    },
                                  )
                                : CircleAvatar(
                                    radius: 60,
                                    backgroundColor:
                                        purpleColors(context).withAlpha(50),
                                    child: Icon(
                                      Icons.person,
                                      size: 40,
                                      color: purpleColors(context),
                                    ),
                                  ),
                          ),
                        ),

                        //
                        Positioned(
                          bottom: 0,
                          left: 0,
                          right: 0,
                          top: 0,
                          child: IconButton(
                            onPressed: _pickImage,
                            icon: const Icon(
                              Icons.add,
                              color: Colors.white,
                              size: 40,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // tappable name to edit
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      spacing: 5,
                      children: [
                        Text(
                          userName ?? "Guest User",
                          style: GoogleFonts.outfit(
                            color: primaryColor(context),
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        InkWell(
                          onTap: _editName,
                          child: Icon(
                            Icons.edit_outlined,
                            color: purpleColors(context),
                            size: 17,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Appearance Section
              Padding(
                padding: const EdgeInsets.all(5),
                child: Text(
                  'Appearance',
                  style: GoogleFonts.outfit(
                    color: primaryColor(context),
                    fontSize: screenWidth / 25,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Container(
                height: screenWidth / 8,
                decoration: BoxDecoration(
                  color: purpleColors(context),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Dark Mode',
                        style: GoogleFonts.outfit(
                          color: primaryColor(context),
                          fontSize: screenWidth / 25,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      ThemeSwitcher(themeProvider: themeProvider),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 5),

              // ————— Currency Section —————
              Padding(
                padding: const EdgeInsets.all(5),
                child: Text(
                  'Currency',
                  style: GoogleFonts.outfit(
                    color: primaryColor(context),
                    fontSize: screenWidth / 25,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Consumer<BalanceProvider>(
                builder: (ctx, balanceProvider, _) {
                  return Container(
                    height: screenWidth / 8,
                    decoration: BoxDecoration(
                      color: purpleColors(context),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 9),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Select Currency',
                          style: GoogleFonts.outfit(
                            color: primaryColor(context),
                            fontSize: screenWidth / 25,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Container(
                          margin: const EdgeInsets.symmetric(vertical: 8),
                          padding: const EdgeInsets.symmetric(horizontal: 15),
                          decoration: BoxDecoration(
                            color: primaryColor(context),
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: shadowColor(context).withOpacity(0.1),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: DropdownButton<String>(
                            borderRadius: BorderRadius.circular(16),
                            dropdownColor: primaryColor(context),
                            value: balanceProvider.currencyCode,
                            underline: const SizedBox(),
                            icon: Icon(Icons.keyboard_arrow_down,
                                color: inversePrimaryColor(context)),
                            items:
                                balanceProvider.supportedCurrencies.map((code) {
                              return DropdownMenuItem(
                                value: code,
                                child: Text(
                                  code,
                                  style: GoogleFonts.outfit(
                                    color: inversePrimaryColor(context),
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              );
                            }).toList(),
                            onChanged: (newCode) {
                              if (newCode != null) {
                                balanceProvider.setCurrency(newCode);
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),

              const SizedBox(height: 5),

              // Categories Section
              Padding(
                padding: const EdgeInsets.all(5),
                child: Text(
                  'Categories',
                  style: GoogleFonts.outfit(
                    color: primaryColor(context),
                    fontSize: screenWidth / 25,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              InkWell(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const CategoryManagementPage(),
                    ),
                  );
                },
                child: Container(
                  height: screenWidth / 8,
                  decoration: BoxDecoration(
                    color: purpleColors(context),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Manage Categories',
                          style: GoogleFonts.outfit(
                            color: primaryColor(context),
                            fontSize: screenWidth / 25,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Icon(
                          Icons.arrow_forward_ios,
                          color: primaryColor(context),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 5),

              // Categories Section
              Padding(
                padding: const EdgeInsets.all(5),
                child: Text(
                  'AI Advisor',
                  style: GoogleFonts.outfit(
                    color: primaryColor(context),
                    fontSize: screenWidth / 25,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              InkWell(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const AISettingsTab(),
                    ),
                  );
                },
                child: Container(
                  height: screenWidth / 8,
                  decoration: BoxDecoration(
                    color: purpleColors(context),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'AI Advisor Settings',
                          style: GoogleFonts.outfit(
                            color: primaryColor(context),
                            fontSize: screenWidth / 25,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Icon(
                          Icons.arrow_forward_ios,
                          color: primaryColor(context),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 5),

              // Reset App Button
              Padding(
                padding: EdgeInsets.symmetric(
                  vertical: screenWidth / 25,
                ),
                child: InkWell(
                  onTap: () async {
                    _handleReset(context);
                  },
                  child: Container(
                    height: 50,
                    decoration: BoxDecoration(
                      color: Colors.red, // You can adjust this color as needed
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Reset App',
                            style: GoogleFonts.outfit(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const Icon(
                            Icons.restore,
                            color: Colors.white,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _handleReset(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadiusGeometry.circular(10),
        ),
        title: Text(
          'Reset App?',
          style: GoogleFonts.outfit(
            color: primaryColor(context),
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          'This will delete all your data. This action cannot be undone.',
          style: GoogleFonts.outfit(
            color: primaryColor(context),
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'Cancel',
              style: GoogleFonts.outfit(
                color: primaryColor(context),
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: Text(
              'Reset',
              style: GoogleFonts.outfit(
                color: Colors.red,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;

    try {
      final balanceProvider =
          Provider.of<BalanceProvider>(context, listen: false);
      final aiAdvisorProvider =
          Provider.of<AIAdvisorProvider>(context, listen: false);
      final categoryProvider =
          Provider.of<CategoryProvider>(context, listen: false);
      final budgetProvider =
          Provider.of<BudgetProvider>(context, listen: false);
      final investmentProvider =
          Provider.of<InvestmentProvider>(context, listen: false);

      await balanceProvider.resetApp(
        aiAdvisorProvider,
        context,
        categoryProvider: categoryProvider,
        budgetProvider: budgetProvider,
        investmentProvider: investmentProvider,
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Reset failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
