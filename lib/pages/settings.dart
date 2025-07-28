import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:wallone/state/theme_provider.dart';
import 'package:wallone/state/balance_provider.dart';
import 'package:wallone/utils/constants.dart';
import 'package:wallone/pages/category_management.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    return Scaffold(
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
          onPressed: () => Navigator.pop(context),
        ),
        elevation: 0,
        backgroundColor: mainColor(context),
      ),
      body: Padding(
        padding: const EdgeInsets.all(10.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Appearance Section
            Padding(
              padding: const EdgeInsets.all(5),
              child: Text(
                'Appearance',
                style: GoogleFonts.outfit(
                  color: primaryColor(context),
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            Container(
              height: 50,
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
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    ThemeSwitcher(themeProvider: themeProvider),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // ————— Currency Section —————
            Padding(
              padding: const EdgeInsets.all(5),
              child: Text(
                'Currency',
                style: GoogleFonts.outfit(
                  color: primaryColor(context),
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            Consumer<BalanceProvider>(
              builder: (ctx, balanceProvider, _) {
                return Container(
                  height: 50,
                  decoration: BoxDecoration(
                    color: purpleColors(context),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Select Currency',
                        style: GoogleFonts.outfit(
                          color: primaryColor(context),
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      DropdownButton<String>(
                        dropdownColor: inversePrimaryColor(context),
                        value: balanceProvider.currencyCode,
                        underline: const SizedBox(),
                        icon: Icon(Icons.keyboard_arrow_down,
                            color: primaryColor(context)),
                        items: BalanceProvider.supportedCurrencies.map((code) {
                          return DropdownMenuItem(
                            value: code,
                            child: Text(
                              code,
                              style: GoogleFonts.outfit(
                                color: primaryColor(context),
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
                    ],
                  ),
                );
              },
            ),

            const SizedBox(height: 20),

            // Categories Section
            Padding(
              padding: const EdgeInsets.all(5),
              child: Text(
                'Categories',
                style: GoogleFonts.outfit(
                  color: primaryColor(context),
                  fontSize: 20,
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
                height: 50,
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
                          fontSize: 20,
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
            const SizedBox(height: 20),
            // Reset App Button
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 10.0),
              child: InkWell(
                onTap: () async {
                  // Show a confirmation dialog
                  bool? confirmReset = await showDialog<bool>(
                    context: context,
                    builder: (context) {
                      return AlertDialog(
                        title: const Text("Reset App"),
                        content: const Text(
                            "Are you sure you want to reset all app data? This action cannot be undone."),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context, false),
                            child: const Text("Cancel"),
                          ),
                          TextButton(
                            onPressed: () => Navigator.pop(context, true),
                            child: const Text("Reset"),
                          ),
                        ],
                      );
                    },
                  );

                  if (confirmReset == true) {
                    // Call resetApp from BalanceProvider
                    await Provider.of<BalanceProvider>(context, listen: false)
                        .resetApp();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text("App has been reset."),
                      ),
                    );
                  }
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
    );
  }
}
