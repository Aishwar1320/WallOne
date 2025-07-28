import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wallone/state/balance_provider.dart';
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

  // ListProvider with balanceProvider
  final listProvider = ListProvider(balanceProvider);

  // BudgetProvider with balanceProvider and SharedPreferences
  final budgetProvider = BudgetProvider(balanceProvider, prefs);

  // linked together
  balanceProvider.setListProvider(listProvider);

  runApp(
    MultiProvider(
      providers: [
        // existing instances using .value
        ChangeNotifierProvider<BalanceProvider>.value(value: balanceProvider),
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
  late ResetBalanceService _resetBalanceService;

  @override
  void initState() {
    super.initState();
    _resetBalanceService = ResetBalanceService();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _resetBalanceService.startResetTimers(context);
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _resetBalanceService.startResetTimers(context);
    }
  }

  @override
  void dispose() {
    _resetBalanceService.stop();
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
