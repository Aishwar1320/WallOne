import 'dart:async';
import 'package:device_preview/device_preview.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:wallone/firebase_options.dart';
import 'package:wallone/pages/Onboarding/onboarding_page.dart';
import 'package:wallone/splash_screen.dart';
import 'package:wallone/state/adviser_provider.dart';
import 'package:wallone/state/balance_provider.dart';
import 'package:wallone/state/investment_provider.dart';
import 'package:wallone/state/budget_provider.dart';
import 'package:wallone/state/category_provider.dart';
import 'package:wallone/state/list_provider.dart';
import 'package:wallone/state/theme_provider.dart';
import 'package:wallone/state/transaction_type_provider.dart';
import 'package:wallone/state/userprofile_provider.dart';
import 'package:wallone/utils/layout.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Google Mobile Ads SDK
  try {
    await MobileAds.instance.initialize();
    if (kDebugMode) debugPrint('[main] MobileAds initialized');
  } catch (e) {
    if (kDebugMode) debugPrint('[main] MobileAds initialization error: $e');
  }

  // Initialize Firebase FIRST
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  if (kDebugMode) {
    debugPrint('[main] Firebase initialized successfully');
  }

  // Create providers in the correct order
  // Note: These now use Firestore internally, no BalanceStorage needed!
  if (kDebugMode) debugPrint('[Main] Creating Firestore-based providers...');

  final balanceProvider = BalanceProvider();
  final investmentProvider = InvestmentProvider();
  final listProvider = ListProvider(balanceProvider, investmentProvider);

  // Set up provider relationships BEFORE creating BudgetProvider
  if (kDebugMode) debugPrint('[Main] Setting up provider relationships...');

  // Set balance provider reference in investment provider
  investmentProvider.setBalanceProvider(balanceProvider);

  // Set list provider reference in balance provider
  balanceProvider.setListProvider(listProvider);

  // Set list provider reference in investment provider
  investmentProvider.setListProvider(listProvider);

  if (kDebugMode) {
    debugPrint('[Main] Provider relationships established:');
    debugPrint(
        '  - InvestmentProvider has BalanceProvider: ${investmentProvider.balanceProvider != null}');
    debugPrint(
        '  - InvestmentProvider has ListProvider: ${investmentProvider.listProvider != null}');
    debugPrint(
        '  - BalanceProvider has ListProvider: ${balanceProvider.listProvider != null}');
  }

  // Wait a bit to ensure all async initialization is complete
  await Future.delayed(const Duration(milliseconds: 100));

  // Create BudgetProvider after all relationships are established
  final budgetProvider =
      BudgetProvider(balanceProvider, investmentProvider, listProvider);

  final aiAdvisorProvider = AIAdvisorProvider();

  // Wire up a quick refresh when new transactions are added.
  // Use a short debounce to avoid spamming the AI service when multiple
  // transactions are created in quick succession.
  Timer? _aiRefreshTimer;
  listProvider.onTransactionAdded = (transaction) {
    try {
      _aiRefreshTimer?.cancel();
      _aiRefreshTimer = Timer(const Duration(milliseconds: 800), () async {
        try {
          // If the advisor is not ready this call will be a no-op.
          await aiAdvisorProvider.refreshInsights(forceRefresh: true);
        } catch (e) {
          if (kDebugMode) {
            debugPrint('[Main] Error refreshing AI insights: $e');
          }
        }
      });
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[Main] Error setting up AI refresh timer: $e');
      }
    }
  };

  if (kDebugMode) debugPrint('[Main] All providers initialized and linked');

  runApp(
    DevicePreview(
      enabled: !kReleaseMode,
      builder: (context) => MultiProvider(
        providers: [
          // Use .value for pre-created instances
          ChangeNotifierProvider<BalanceProvider>.value(value: balanceProvider),
          ChangeNotifierProvider<InvestmentProvider>.value(
              value: investmentProvider),
          ChangeNotifierProvider<ListProvider>.value(value: listProvider),
          ChangeNotifierProvider<BudgetProvider>.value(value: budgetProvider),

          // Create new instances for these (now use Firestore)
          ChangeNotifierProvider(create: (_) => TransactionTypeProvider()),
          ChangeNotifierProvider(create: (_) => ThemeProvider()),
          ChangeNotifierProvider(create: (_) => CategoryProvider()),
          ChangeNotifierProvider<AIAdvisorProvider>.value(
              value: aiAdvisorProvider),
          ChangeNotifierProvider(create: (_) => UserProfileProvider()),
        ],
        child: const MyApp(),
      ),
    ),
  );
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  bool? _hasSeenOnboarding;

  @override
  void initState() {
    super.initState();

    if (kDebugMode) {
      debugPrint('[MyApp] initState called');
    }

    // Start with null (loading state), load from Firestore
    _hasSeenOnboarding = null;
    _loadHasSeenOnboarding();

    // Add observer for app lifecycle
    WidgetsBinding.instance.addObserver(this);

    // Defer AI initialization until after the first frame to avoid
    // notifying providers during the widget build phase.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeAI();
    });
  }

  Future<void> _loadHasSeenOnboarding() async {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) {
        if (kDebugMode) {
          debugPrint('[MyApp] No user logged in, hasSeenOnboarding -> false');
        }
        if (mounted) {
          setState(() {
            _hasSeenOnboarding = false;
          });
        }
        return;
      }

      final userDoc =
          await FirebaseFirestore.instance.collection('users').doc(uid).get();

      final value = userDoc.data()?['hasSeenOnboarding'] as bool? ?? false;
      if (kDebugMode) {
        debugPrint('[MyApp] _loadHasSeenOnboarding from Firestore -> $value');
      }
      if (mounted) {
        setState(() {
          _hasSeenOnboarding = value;
        });
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[MyApp] Error loading hasSeenOnboarding: $e');
      }
      // Default to false if there's an error
      if (mounted) {
        setState(() {
          _hasSeenOnboarding = false;
        });
      }
    }
  }

  Future<void> _initializeAI() async {
    try {
      if (kDebugMode) {
        debugPrint('[MyApp] Initializing AI advisor...');
      }

      final aiProvider = context.read<AIAdvisorProvider>();
      final balanceProvider = context.read<BalanceProvider>();
      final investmentProvider = context.read<InvestmentProvider>();
      final budgetProvider = context.read<BudgetProvider>();
      final listProvider = context.read<ListProvider>();
      final categoryProvider = context.read<CategoryProvider>();

      // Initialize the rule-based advisor (no API key required)
      await aiProvider.initializeAdvisor(
        balanceProvider: balanceProvider,
        investmentProvider: investmentProvider,
        budgetProvider: budgetProvider,
        listProvider: listProvider,
        categoryProvider: categoryProvider,
      );

      if (kDebugMode) {
        debugPrint('[MyApp] AI advisor initialized successfully');
      }
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint('[MyApp] Error initializing AI: $e');
        debugPrint('[MyApp] Stack trace: $st');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);

    // While we are still loading, show the custom splash screen
    if (_hasSeenOnboarding == null) {
      return MaterialApp(
        theme: ThemeData.light(),
        darkTheme: ThemeData.dark(),
        themeMode: themeProvider.themeMode,
        debugShowCheckedModeBanner: false,
        home: const SplashScreen(),
      );
    }

    final showOnboarding = !(_hasSeenOnboarding!);

    return MaterialApp(
      theme: ThemeData.light(),
      darkTheme: ThemeData.dark(),
      themeMode: themeProvider.themeMode,
      debugShowCheckedModeBanner: false,
      home: showOnboarding
          ? OnboardingPage(
              onFinish: () async {
                try {
                  // Mark onboarding as complete in Firestore
                  final uid = FirebaseAuth.instance.currentUser?.uid;
                  if (uid != null) {
                    await FirebaseFirestore.instance
                        .collection('users')
                        .doc(uid)
                        .set({'hasSeenOnboarding': true},
                            SetOptions(merge: true));
                    if (kDebugMode) {
                      debugPrint(
                          '[Onboarding] hasSeenOnboarding saved to Firestore');
                    }
                  }

                  if (context.mounted) {
                    // Update local state
                    setState(() {
                      _hasSeenOnboarding = true;
                    });

                    // Navigate to main layout
                    Navigator.of(context).pushReplacement(
                      MaterialPageRoute(builder: (_) => const DesignLayout()),
                    );
                  }
                } catch (e) {
                  if (kDebugMode) {
                    debugPrint(
                        '[Onboarding] Error saving onboarding state: $e');
                  }
                  // Still navigate even if saving failed
                  if (context.mounted) {
                    Navigator.of(context).pushReplacement(
                      MaterialPageRoute(builder: (_) => const DesignLayout()),
                    );
                  }
                }
              },
            )
          : const DesignLayout(),
    );
  }
}
