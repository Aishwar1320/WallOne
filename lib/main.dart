import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wallone/state/balance_provider.dart';
import 'package:wallone/state/investment_provider.dart';
import 'package:wallone/state/budget_provider.dart';
import 'package:wallone/state/category_provider.dart';
import 'package:wallone/state/list_provider.dart';
import 'package:wallone/state/theme_provider.dart';
import 'package:wallone/state/transaction_type_provider.dart';
import 'package:wallone/utils/layout.dart';
import 'package:wallone/utils/services/reset_timer.dart';
import 'package:wallone/utils/services/shared_pref.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize SharedPreferences
  final prefs = await SharedPreferences.getInstance();

  // BalanceProvider
  final storage = await BalanceStorage.create();
  final balanceProvider = BalanceProvider(storage);

  // InvestmentProvider
  final investmentProvider = InvestmentProvider(storage);

  // ListProvider with balanceProvider and investmentProvider
  final listProvider = ListProvider(balanceProvider, investmentProvider);

  // BudgetProvider with balanceProvider, investmentProvider, and SharedPreferences
  final budgetProvider =
      BudgetProvider(balanceProvider, investmentProvider, prefs);

  // linked together
  balanceProvider.setListProvider(listProvider);

  runApp(
    MultiProvider(
      providers: [
        // existing instances using .value
        ChangeNotifierProvider<BalanceProvider>.value(value: balanceProvider),
        ChangeNotifierProvider<InvestmentProvider>.value(
            value: investmentProvider),
        ChangeNotifierProvider<ListProvider>.value(value: listProvider),
        ChangeNotifierProvider<BudgetProvider>.value(value: budgetProvider),
        ChangeNotifierProvider(create: (_) => TransactionTypeProvider()),
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(
          create: (context) => CategoryProvider(prefs),
        ),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  static ResetBalanceService?
      _resetBalanceService; // Make it static to prevent multiple instances
  bool _hasInitialized = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // Initialize the service only once
    if (_resetBalanceService == null) {
      _resetBalanceService = ResetBalanceService();
      print('[MyApp] Created new ResetBalanceService instance');
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeResetService();
    });
  }

  void _initializeResetService() {
    if (!_hasInitialized && _resetBalanceService != null) {
      print('[MyApp] Initializing reset service...');
      _resetBalanceService!.startResetTimers(context);
      _hasInitialized = true;
    } else {
      print('[MyApp] Reset service already initialized or service is null');
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    print('[MyApp] App lifecycle state changed to: $state');

    if (state == AppLifecycleState.resumed && _resetBalanceService != null) {
      // Only reinitialize if we haven't already done so today
      print(
          '[MyApp] App resumed - checking if reset service needs reinitialization');
      _resetBalanceService!.startResetTimers(context);
    }
  }

  @override
  void dispose() {
    print('[MyApp] Disposing MyApp...');
    WidgetsBinding.instance.removeObserver(this);

    _resetBalanceService?.stop();
    _resetBalanceService = null;

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);

    return MaterialApp(
      theme: ThemeData.light(),
      darkTheme: ThemeData.dark(),
      themeMode: themeProvider.themeMode,
      debugShowCheckedModeBanner: false,
      home: const DesignLayout(),
    );
  }
}
