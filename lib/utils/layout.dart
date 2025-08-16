import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:wallone/pages/about_us.dart';
import 'package:wallone/pages/analytics.dart';
import 'package:wallone/pages/budget_page.dart';
import 'package:wallone/pages/dashboard.dart';
import 'package:wallone/pages/settings.dart';
import 'package:wallone/pages/add_transactions.dart';
import 'package:wallone/state/balance_provider.dart';
import 'package:wallone/utils/constants.dart';

class DesignLayout extends StatefulWidget {
  const DesignLayout({super.key});

  @override
  _DesignLayoutState createState() => _DesignLayoutState();
}

class _DesignLayoutState extends State<DesignLayout> {
  int _selectedIndex = 0;

  // List of pages to display based on the selected index
  final List<Widget> _pages = [
    const DashboardPage(),
    const BudgetPage(),
    const AddTransactionsPage(),
    const AnalyticsPage(),
    const Center(child: Text('Profile Page')),
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

    return Scaffold(
      // Drawer
      drawer: Drawer(
        backgroundColor: mainColor(context),
        child: Column(
          spacing: 20,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            DrawerHeader(
              child: Icon(
                Icons.favorite,
                size: 100,
                color: purpleColors(context),
              ),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: Text(
                "Home",
                style: GoogleFonts.outfit(
                  fontSize: 30,
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
                  fontSize: 30,
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
                  fontSize: 30,
                  color: purpleColors(context),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const Spacer(),
            // Logout Button
            // TextButton(
            //   onPressed: () {},
            //   child: Text(
            //     "Logout",
            //     style: GoogleFonts.outfit(
            //       fontSize: 30,
            //       color: primaryColor(context),
            //       fontWeight: FontWeight.bold,
            //     ),
            //   ),
            // ),
            // const SizedBox(height: 30),
          ],
        ),
      ),

      // App Bar
      appBar: AppBar(
        backgroundColor: mainColor(context),
        centerTitle: true,
        title: Padding(
          padding: const EdgeInsets.only(right: 8.0),
          child: Column(
            children: [
              RichText(
                text: TextSpan(
                  children: [
                    TextSpan(
                      text: symbol,
                      style: GoogleFonts.russoOne(
                        fontSize: 20,
                        color: purpleColors(context),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const WidgetSpan(
                      child: SizedBox(width: 1),
                    ),
                    TextSpan(
                      text: balanceProvider.totalBalance.toString(),
                      style: GoogleFonts.russoOne(
                        fontSize: 20,
                        color: primaryColor(context),
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                "Total Balance",
                style: GoogleFonts.outfit(
                  fontSize: 13,
                  color: primaryColor(context),
                ),
              ),
            ],
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 5.0),
            child: IconButton(
              onPressed: () {},
              icon: const Icon(
                Icons.notifications_none,
                size: 30,
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
          _pages[_selectedIndex],

          //

          Align(
            alignment: Alignment.bottomCenter,
            child: Padding(
              padding: const EdgeInsets.all(10.0),
              child: Container(
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
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(25.0),
                  child: BottomAppBar(
                    color: inversePrimaryColor(context),
                    shadowColor: shadowColor(context),
                    elevation: 10,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        IconButton(
                          onPressed: () => _onItemTapped(0),
                          icon: Icon(
                            Icons.home_outlined,
                            size: 30,
                            color: _selectedIndex == 0
                                ? primaryColor(context)
                                : null,
                          ),
                        ),
                        IconButton(
                          onPressed: () => _onItemTapped(1),
                          icon: Icon(
                            Icons.account_balance_wallet_outlined,
                            size: 27,
                            color: _selectedIndex == 1
                                ? primaryColor(context)
                                : null,
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
                            color: _selectedIndex == 3
                                ? primaryColor(context)
                                : null,
                          ),
                        ),
                        IconButton(
                          onPressed: () => showCustomSnackBar(context),
                          // onPressed: () => _onItemTapped(4),
                          icon: Icon(
                            Icons.person_2_outlined,
                            size: 30,
                            color: _selectedIndex == 4
                                ? primaryColor(context)
                                : null,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
