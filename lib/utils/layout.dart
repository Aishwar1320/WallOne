import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:wallone/pages/About%20Us/about_us.dart';
import 'package:wallone/pages/Ai%20Control%20Panel/ai_ml_dashboard.dart';
import 'package:wallone/pages/Analytics%20Page/analytics.dart';
import 'package:wallone/pages/Budget%20Page/budget_page.dart';
import 'package:wallone/pages/Dashboard%20Page/dashboard.dart';
import 'package:wallone/pages/Onboarding/user_setup.dart';
import 'package:wallone/pages/Settings/settings.dart';
import 'package:wallone/pages/Transaction%20Management/add_transactions.dart';
import 'package:wallone/state/adviser_provider.dart';
import 'package:wallone/state/balance_provider.dart';
import 'package:wallone/state/userprofile_provider.dart';
import 'package:wallone/utils/constants.dart';

class DesignLayout extends StatefulWidget {
  const DesignLayout({super.key});

  @override
  _DesignLayoutState createState() => _DesignLayoutState();
}

class _DesignLayoutState extends State<DesignLayout> {
  int _selectedIndex = 0;
  bool _showAppBarBalance = false;
  @override
  void initState() {
    super.initState();
    // No local SharedPreferences reads — user profile data comes from
    // UserProfileProvider via Provider and is accessed in build().
  }

  // List of pages to display based on the selected index
  List<Widget> get _pages => [
        DashboardPage(
          onBalanceVisibilityChanged: (isVisible) {
            setState(() {
              _showAppBarBalance = !isVisible;
            });
          },
        ),
        const BudgetPage(),
        const AddTransactionsPage(),
        AnalyticsPage(
          onSeeAllAIAdvisor: () {
            setState(() {
              _selectedIndex = 4;
            });
          },
        ),
        const AIAdvisorDashboard(),
      ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    final code = context.read<BalanceProvider>().currencyCode;
    final symbol = NumberFormat.simpleCurrency(name: code).currencySymbol;
    final balanceProvider = Provider.of<BalanceProvider>(context);
    final screenWidth = MediaQuery.of(context).size.width;
    final profile = context.watch<UserProfileProvider>();
    final profileName = profile.userName ?? 'Guest User';
    final profileImagePath = profile.coverImagePath;

    return Scaffold(
      // Drawer
      drawer: Drawer(
        backgroundColor: mainColor(context),
        child: Column(
          spacing: 20,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            DrawerHeader(
              child: Column(
                children: [
                  InkWell(
                    onTap: () {
                      Navigator.push(context, MaterialPageRoute(
                        builder: (context) {
                          return const SettingsPage();
                        },
                      ));
                    },
                    child: Container(
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
                        child: profileImagePath != null &&
                                File(profileImagePath).existsSync()
                            ? Image.file(
                                File(profileImagePath),
                                width: 80,
                                height: 80,
                                fit: BoxFit.cover,
                              )
                            : CircleAvatar(
                                radius: 40,
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
                  ),
                  const SizedBox(height: 20),
                  Text(
                    profileName,
                    style: GoogleFonts.outfit(
                      color: purpleColors(context),
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: Text(
                "Home",
                style: GoogleFonts.outfit(
                  fontSize: screenWidth / 20,
                  color: purpleColors(context),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            TextButton(
              onPressed: () {
                Navigator.push(context, MaterialPageRoute(
                  builder: (context) {
                    return const SettingsPage();
                  },
                ));
              },
              child: Text(
                "Settings",
                style: GoogleFonts.outfit(
                  fontSize: screenWidth / 20,
                  color: purpleColors(context),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            TextButton(
              onPressed: () {
                Navigator.push(context, MaterialPageRoute(
                  builder: (context) {
                    return const AboutUsPage();
                  },
                ));
              },
              child: Text(
                "About Us",
                style: GoogleFonts.outfit(
                  fontSize: screenWidth / 20,
                  color: purpleColors(context),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const Spacer(),
            // Logout Button
            TextButton(
              onPressed: () async {
                try {
                  final aiProvider =
                      Provider.of<AIAdvisorProvider>(context, listen: false);
                  aiProvider.reset();
                  // Sign out from Firebase
                  await FirebaseAuth.instance.signOut();

                  // Navigate back to UserSetupPage (or login page)
                  if (context.mounted) {
                    Navigator.pushAndRemoveUntil(
                      context,
                      MaterialPageRoute(builder: (_) => const UserSetupPage()),
                      (route) => false, // remove all previous routes
                    );
                  }
                } catch (e) {
                  // Optional: show error
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text("Failed to logout: $e")),
                  );
                }
              },
              child: Text(
                "Logout",
                style: GoogleFonts.outfit(
                  fontSize: screenWidth / 15,
                  color: purpleColors(context),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),

            const SizedBox(height: 30),
          ],
        ),
      ),

      // App Bar
      appBar: AppBar(
        backgroundColor: mainColor(context),
        centerTitle: true,
        scrolledUnderElevation: 0,
        title: !_showAppBarBalance && _selectedIndex == 0
            ? Text(
                "Wall One",
                style: GoogleFonts.outfit(
                  color: purpleColors(context),
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              )
            : Padding(
                padding: const EdgeInsets.only(right: 8.0),
                child: (_selectedIndex != 0 || _showAppBarBalance)
                    ? Hero(
                        tag: 'balanceHero',
                        child: Material(
                          color: Colors.transparent,
                          child: AnimatedSwitcher(
                            duration: const Duration(milliseconds: 350),
                            transitionBuilder: (child, anim) {
                              final offsetAnim = anim.drive(
                                Tween<Offset>(
                                        begin: const Offset(0, -0.18),
                                        end: Offset.zero)
                                    .chain(CurveTween(curve: Curves.easeOut)),
                              );
                              return SlideTransition(
                                position: offsetAnim,
                                child: FadeTransition(
                                  opacity: anim,
                                  child: child,
                                ),
                              );
                            },
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  symbol +
                                      balanceProvider.totalBalance.toString(),
                                  key: ValueKey(balanceProvider.totalBalance),
                                  style: GoogleFonts.outfit(
                                    fontSize: 20,
                                    color: primaryColor(context),
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Text(
                                  "Total Balance",
                                  style: GoogleFonts.outfit(
                                    fontSize: 13,
                                    color: purpleColors(context),
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      )
                    : const SizedBox.shrink(),
              ),
        actions: [
          if (_selectedIndex == 4)
            Consumer<AIAdvisorProvider>(
              builder: (context, provider, child) {
                return IconButton(
                  icon: provider.isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.refresh),
                  onPressed: provider.isLoading
                      ? null
                      : () => provider.refreshInsights(forceRefresh: true),
                );
              },
            ),
          Padding(
            padding: const EdgeInsets.only(right: 5.0),
            child: IconButton(
              onPressed: () {},
              icon: Icon(
                Icons.notifications_none,
                size: screenWidth / 17,
              ),
            ),
          ),
        ],
        elevation: 0,
      ),

      // Background Color
      backgroundColor: mainColor(context),

      extendBody: false,

      // Body
      body: Stack(
        children: [
          Positioned.fill(
            child: _pages[_selectedIndex],
          ),

          //

          Align(
            alignment: Alignment.bottomCenter,
            child: Padding(
              padding: const EdgeInsets.all(10.0),
              child: Container(
                margin:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: inversePrimaryColor(context),
                  borderRadius: BorderRadius.circular(25),
                  boxShadow: [
                    BoxShadow(
                      blurRadius: 15,
                      color: shadowColor(context),
                    )
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      onPressed: () => _onItemTapped(0),
                      icon: Icon(
                        Icons.home_outlined,
                        size: 30,
                        color:
                            _selectedIndex == 0 ? primaryColor(context) : null,
                      ),
                    ),
                    IconButton(
                      onPressed: () => _onItemTapped(1),
                      icon: Icon(
                        Icons.account_balance_wallet_outlined,
                        size: 27,
                        color:
                            _selectedIndex == 1 ? primaryColor(context) : null,
                      ),
                    ),
                    SizedBox(
                      child: FloatingActionButton(
                        elevation: 10,
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) {
                                return const AddTransactionsPage();
                              },
                            ),
                          );
                        },
                        backgroundColor: primaryColor(context),
                        child: Text(
                          symbol,
                          style: GoogleFonts.outfit(
                            fontSize: 25,
                            fontWeight: FontWeight.bold,
                            color: purpleColors(context),
                          ),
                        ),
                      ),
                    ),
                    IconButton(
                      // onPressed: () => showCustomSnackBar(context),
                      onPressed: () => _onItemTapped(3),
                      icon: Icon(
                        Icons.analytics_outlined,
                        size: 30,
                        color:
                            _selectedIndex == 3 ? primaryColor(context) : null,
                      ),
                    ),
                    IconButton(
                      // onPressed: () => showCustomSnackBar(context),
                      onPressed: () => _onItemTapped(4),
                      icon: Icon(
                        Icons.bolt,
                        size: 30,
                        color:
                            _selectedIndex == 4 ? primaryColor(context) : null,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
