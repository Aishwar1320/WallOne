import 'dart:async';
import 'package:device_preview/device_preview.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wallone/pages/onboarding_page.dart';
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
import 'package:wallone/utils/services/reset_timer.dart';
import 'package:wallone/utils/services/shared_pref.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await dotenv.load(fileName: ".env");

  // Initialize SharedPreferences
  final prefs = await SharedPreferences.getInstance();

  // Debug output
  final hasSeenOnboarding = prefs.getBool('hasSeenOnboarding') ?? false;
  if (kDebugMode) {
    debugPrint('[main] hasSeenOnboarding from prefs: $hasSeenOnboarding');
  }

  // Retrieve the API key from the .env file
  final apiKeyFromEnv = dotenv.env['GEMINI_API_KEY']?.trim();

  // Check if a key is present in the .env file
  if (apiKeyFromEnv != null && apiKeyFromEnv.isNotEmpty) {
    // Save the API key to SharedPreferences for later use
    // You might want to do this only once or on app start.
    await prefs.setString('GEMINI_API_KEY', apiKeyFromEnv);
    if (kDebugMode) {
      debugPrint(
          '[Main] API Key successfully loaded from .env and saved to SharedPreferences.');
    }
  } else {
    if (kDebugMode) {
      debugPrint(
          '[Main] WARNING: GEMINI_API_KEY is missing or empty in the .env file.');
    }
  }

  // Initialize BalanceStorage
  final storage = await BalanceStorage.create();

  // Create providers in the correct order
  final balanceProvider = BalanceProvider(storage);
  final investmentProvider = InvestmentProvider(storage);
  final listProvider = ListProvider(balanceProvider, investmentProvider);

  // Set up provider relationships BEFORE creating BudgetProvider
  if (kDebugMode) debugPrint('[Main] Setting up provider relationships...');

  // Set balance provider reference in investment provider
  investmentProvider.setBalanceProvider(balanceProvider);

  // Set list provider reference in balance provider
  balanceProvider.setListProvider(listProvider);

  // Set list provider reference in investment provider
  investmentProvider.setListProvider(listProvider);

  // Wait a bit to ensure all async initialization is complete
  await Future.delayed(const Duration(milliseconds: 100));

  // Create BudgetProvider after all relationships are established
  final budgetProvider =
      BudgetProvider(balanceProvider, investmentProvider, prefs);

  final aiAdvisorProvider = AIAdvisorProvider(prefs);

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
        } catch (_) {}
      });
    } catch (_) {}
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

          // Create new instances for these
          ChangeNotifierProvider(create: (_) => TransactionTypeProvider()),
          ChangeNotifierProvider(create: (_) => ThemeProvider()),
          ChangeNotifierProvider(create: (context) => CategoryProvider(prefs)),
          ChangeNotifierProvider<AIAdvisorProvider>.value(
              value: aiAdvisorProvider),
          ChangeNotifierProvider(create: (_) => UserProfileProvider()),
        ],
        child: MyApp(initialHasSeenOnboarding: hasSeenOnboarding),
      ),
    ),
  );
}

class MyApp extends StatefulWidget {
  final bool? initialHasSeenOnboarding;
  const MyApp({
    super.key,
    this.initialHasSeenOnboarding,
  });

  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  static ResetBalanceService? _resetBalanceService;
  bool _hasInitialized = false;
  bool? _hasSeenOnboarding;

  @override
  void initState() {
    super.initState();
    // start with supplied value if available (makes startup snappier),
    // but still re-check prefs to be sure.
    _hasSeenOnboarding = widget.initialHasSeenOnboarding;

    // async load and overwrite with the real stored value
    _loadHasSeenOnboarding();

    _initializeAI();
    WidgetsBinding.instance.addObserver(this);

    // Initialize the service only once
    if (_resetBalanceService == null) {
      _resetBalanceService = ResetBalanceService();
      if (kDebugMode) {
        debugPrint('[MyApp] Created new ResetBalanceService instance');
      }
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeResetService();
    });
  }

  Future<void> _loadHasSeenOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    final value = prefs.getBool('hasSeenOnboarding') ?? false;
    if (kDebugMode) {
      debugPrint('[MyApp] _loadHasSeenOnboarding -> $value');
    }
    if (mounted) {
      setState(() {
        _hasSeenOnboarding = value;
      });
    }
  }

  Future<void> _initializeAI() async {
    final prefs = await SharedPreferences.getInstance();
    final apiKey = prefs.getString('GEMINI_API_KEY');

    if (apiKey != null && mounted) {
      final aiProvider = context.read<AIAdvisorProvider>();
      final balanceProvider = context.read<BalanceProvider>();
      final investmentProvider = context.read<InvestmentProvider>();
      final budgetProvider = context.read<BudgetProvider>();
      final listProvider = context.read<ListProvider>();
      final categoryProvider = context.read<CategoryProvider>();

      await aiProvider.initializeAdvisor(
        apiKey: apiKey,
        balanceProvider: balanceProvider,
        investmentProvider: investmentProvider,
        budgetProvider: budgetProvider,
        listProvider: listProvider,
        categoryProvider: categoryProvider,
      );
    }
  }

  void _initializeResetService() {
    if (!_hasInitialized && _resetBalanceService != null) {
      if (kDebugMode) debugPrint('[MyApp] Initializing reset service...');
      _resetBalanceService!.startResetTimers(context);
      _hasInitialized = true;
    } else {
      if (kDebugMode) {
        debugPrint(
            '[MyApp] Reset service already initialized or service is null');
      }
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (kDebugMode) {
      debugPrint('[MyApp] App lifecycle state changed to: $state');
    }

    if (state == AppLifecycleState.resumed && _resetBalanceService != null) {
      // Only reinitialize if we haven't already done so today
      if (kDebugMode) {
        debugPrint(
            '[MyApp] App resumed - checking if reset service needs reinitialization');
      }
      _resetBalanceService!.startResetTimers(context);
    }
  }

  @override
  void dispose() {
    if (kDebugMode) debugPrint('[MyApp] Disposing MyApp...');
    WidgetsBinding.instance.removeObserver(this);

    _resetBalanceService?.stop();
    _resetBalanceService = null;

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    // while we are still loading the pref show a simple splash/progress
    if (_hasSeenOnboarding == null) {
      return MaterialApp(
        theme: ThemeData.light(),
        darkTheme: ThemeData.dark(),
        themeMode: themeProvider.themeMode,
        debugShowCheckedModeBanner: false,
        home: const Scaffold(
          body: Center(child: CircularProgressIndicator()),
        ),
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
                final prefs = await SharedPreferences.getInstance();

                // Write
                final succeeded =
                    await prefs.setBool('hasSeenOnboarding', true);
                debugPrint('[Onboarding] prefs.setBool returned: $succeeded');

                // Read back immediately
                final readBack = prefs.getBool('hasSeenOnboarding');
                debugPrint('[Onboarding] prefs.getBool after set: $readBack');

                // Confirm by getting a fresh instance (optional extra check)
                final freshPrefs = await SharedPreferences.getInstance();
                final freshRead = freshPrefs.getBool('hasSeenOnboarding');
                debugPrint('[Onboarding] freshPrefs.getBool: $freshRead');

                if (!succeeded) {
                  debugPrint('[Onboarding] WARNING: setBool reported failure');
                }

                if (context.mounted) {
                  // update local state if you used _hasSeenOnboarding in MyApp
                  // then navigate
                  Navigator.of(context).pushReplacement(
                    MaterialPageRoute(builder: (_) => const DesignLayout()),
                  );
                }
              },
            )
          : const DesignLayout(),
    );
  }
}
