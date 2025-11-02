import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wallone/state/balance_provider.dart';
import 'package:wallone/utils/services/shared_pref.dart';

class ResetBalanceService {
  Timer? _dailyTimer;
  Timer? _weeklyTimer;
  Timer? _monthlyTimer;
  BuildContext? _context;
  BalanceStorage? _storage;

  // Flags to prevent duplicate resets
  bool _dailyResetProcessed = false;
  bool _weeklyResetProcessed = false;
  bool _monthlyResetProcessed = false;

  bool _isInitialized = false;
  bool _isInitializing = false;

  void startResetTimers(BuildContext context) {
    if (_isInitialized || _isInitializing) {
      print(
          '[ResetBalanceService] Already initialized or initializing - skipping');
      return;
    }

    _context = context;
    _initializeStorage();
  }

  Future<void> _initializeStorage() async {
    _isInitializing = true;
    print('[ResetBalanceService] Starting initialization...');

    _storage = await BalanceStorage.create();

    // Load and check all resets in sequence
    await _loadAndCheckResets();

    // Mark initialized BEFORE scheduling
    _isInitialized = true;

    // Schedule future resets
    _scheduleNextDailyReset();
    _scheduleNextWeeklyReset();
    _scheduleNextMonthlyReset();

    _isInitializing = false;
    print('[ResetBalanceService] Initialization complete');
  }

  /// Central method to load data and check if resets are needed
  Future<void> _loadAndCheckResets() async {
    if (_storage == null || _context == null) return;

    try {
      print('[ResetBalanceService] Loading balances and checking resets...');

      // Load all data
      final balances = await _storage!.loadBalances();
      final prefs = await SharedPreferences.getInstance();

      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final todayString = today.toIso8601String().split('T')[0];

      // Extract values
      String? lastResetDateStr = balances['lastResetDate'];
      final dailyExpenses = (balances['dailyExpenses'] ?? 0.0) as double;
      final dailyIncomes = (balances['dailyIncomes'] ?? 0.0) as double;
      final weeklyExpenses = (balances['weeklyExpenses'] ?? 0.0) as double;
      final weeklyIncomes = (balances['weeklyIncomes'] ?? 0.0) as double;
      final monthlyExpenses = (balances['monthlyExpenses'] ?? 0.0) as double;
      final monthlyIncomes = (balances['monthlyIncomes'] ?? 0.0) as double;

      final lastWeeklyReset = prefs.getString('lastWeeklyResetDate');
      final lastMonthlyReset = prefs.getString('lastMonthlyResetDate');

      final currentWeekKey = _getWeekKey(now);
      final currentMonthKey = _getMonthKey(now);

      // If there's no stored last daily reset date, initialize it to today
      // to avoid accidental resets on a cold start where prefs exist but
      // the reset date wasn't previously recorded.
      if (lastResetDateStr == null) {
        try {
          print(
              '[ResetBalanceService] No last daily reset date found - initializing to today to avoid accidental cold-start reset');
          await _storage!.saveLastResetDate(today);
          // set local variable so subsequent checks treat it as today's date
          lastResetDateStr = today.toIso8601String();
        } catch (e) {
          print('[ResetBalanceService] Failed to initialize lastResetDate: $e');
        }
      }

      print('[ResetBalanceService] Current state:');
      print('  Today: $todayString');
      print('  Last daily reset: $lastResetDateStr');
      print(
          '  Last weekly reset: $lastWeeklyReset (current week: $currentWeekKey)');
      print(
          '  Last monthly reset: $lastMonthlyReset (current month: $currentMonthKey)');
      print('  Daily values: expenses=$dailyExpenses, incomes=$dailyIncomes');
      print(
          '  Weekly values: expenses=$weeklyExpenses, incomes=$weeklyIncomes');
      print(
          '  Monthly values: expenses=$monthlyExpenses, incomes=$monthlyIncomes');

      // Check DAILY reset
      final needsDailyReset = _needsDailyReset(
        lastResetDateStr,
        todayString,
        dailyExpenses,
        dailyIncomes,
      );

      // Check WEEKLY reset
      final needsWeeklyReset = _needsWeeklyReset(
        lastWeeklyReset,
        currentWeekKey,
        weeklyExpenses,
        weeklyIncomes,
      );

      // Check MONTHLY reset
      final needsMonthlyReset = _needsMonthlyReset(
        lastMonthlyReset,
        currentMonthKey,
        monthlyExpenses,
        monthlyIncomes,
      );

      // Execute resets if needed
      if (needsDailyReset) {
        print('[ResetBalanceService] Daily reset is needed - executing...');
        await _executeDailyReset();
      } else {
        print(
            '[ResetBalanceService] Daily reset not needed - marking as processed');
        _dailyResetProcessed = true;
      }

      if (needsWeeklyReset) {
        print('[ResetBalanceService] Weekly reset is needed - executing...');
        await _executeWeeklyReset();
      } else {
        print(
            '[ResetBalanceService] Weekly reset not needed - marking as processed');
        _weeklyResetProcessed = true;
      }

      if (needsMonthlyReset) {
        print('[ResetBalanceService] Monthly reset is needed - executing...');
        await _executeMonthlyReset();
      } else {
        print(
            '[ResetBalanceService] Monthly reset not needed - marking as processed');
        _monthlyResetProcessed = true;
      }
    } catch (e, stackTrace) {
      print('[ResetBalanceService] Error in _loadAndCheckResets: $e');
      print('[ResetBalanceService] Stack trace: $stackTrace');
    }
  }

  // ----------- RESET CHECKS -----------

  bool _needsDailyReset(
    String? lastResetDateStr,
    String todayString,
    double dailyExpenses,
    double dailyIncomes,
  ) {
    // Reset is needed if:
    // 1. No reset date exists (first time), OR
    // 2. The reset date is different from today AND there are non-zero values

    if (lastResetDateStr == null) {
      print('[ResetBalanceService] No daily reset date found - reset needed');
      return true;
    }

    // Extract only the date part from lastResetDateStr for comparison
    // It could be in format "2025-11-01T00:00:00.000" or "2025-11-01"
    String lastResetDateOnly = lastResetDateStr.split('T')[0];

    if (lastResetDateOnly != todayString) {
      final hasNonZeroValues = dailyExpenses != 0 || dailyIncomes != 0;
      print(
          '[ResetBalanceService] Date mismatch: last=$lastResetDateOnly, today=$todayString, hasValues=$hasNonZeroValues');
      return hasNonZeroValues;
    }

    print(
        '[ResetBalanceService] Daily reset already done today (last: $lastResetDateOnly, today: $todayString)');
    return false;
  }

  bool _needsWeeklyReset(
    String? lastWeeklyReset,
    String currentWeekKey,
    double weeklyExpenses,
    double weeklyIncomes,
  ) {
    if (lastWeeklyReset == null) {
      print('[ResetBalanceService] No weekly reset date found - reset needed');
      return true;
    }

    if (lastWeeklyReset != currentWeekKey) {
      final hasNonZeroValues = weeklyExpenses != 0 || weeklyIncomes != 0;
      print(
          '[ResetBalanceService] Week mismatch: last=$lastWeeklyReset, current=$currentWeekKey, hasValues=$hasNonZeroValues');
      return hasNonZeroValues;
    }

    print('[ResetBalanceService] Weekly reset already done this week');
    return false;
  }

  bool _needsMonthlyReset(
    String? lastMonthlyReset,
    String currentMonthKey,
    double monthlyExpenses,
    double monthlyIncomes,
  ) {
    if (lastMonthlyReset == null) {
      print('[ResetBalanceService] No monthly reset date found - reset needed');
      return true;
    }

    if (lastMonthlyReset != currentMonthKey) {
      final hasNonZeroValues = monthlyExpenses != 0 || monthlyIncomes != 0;
      print(
          '[ResetBalanceService] Month mismatch: last=$lastMonthlyReset, current=$currentMonthKey, hasValues=$hasNonZeroValues');
      return hasNonZeroValues;
    }

    print('[ResetBalanceService] Monthly reset already done this month');
    return false;
  }

  // ----------- DAILY RESET -----------

  void _scheduleNextDailyReset() {
    _dailyTimer?.cancel();
    final now = DateTime.now();
    DateTime nextMidnight =
        DateTime(now.year, now.month, now.day).add(const Duration(days: 1));
    Duration duration = nextMidnight.difference(now);

    if (duration.inMilliseconds <= 0) {
      nextMidnight = nextMidnight.add(const Duration(days: 1));
      duration = nextMidnight.difference(now);
    }

    print(
        '[ResetBalanceService] Scheduling next daily reset in ${duration.inHours} hours (at $nextMidnight)');

    _dailyTimer = Timer(duration, () async {
      print('[ResetBalanceService] Daily timer triggered');
      _dailyResetProcessed = false;
      await _executeDailyReset();
      _scheduleNextDailyReset();
    });
  }

  Future<void> _executeDailyReset() async {
    if (_dailyResetProcessed) {
      print('[ResetBalanceService] Daily reset already processed - skipping');
      return;
    }
    if (_context == null || _storage == null) return;

    _dailyResetProcessed = true;

    try {
      print('[ResetBalanceService] Executing daily reset...');

      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final todayString = today.toIso8601String().split('T')[0];

      final provider = Provider.of<BalanceProvider>(_context!, listen: false);

      // Reset daily values to 0
      provider.resetDailyValues();

      // Save the reset date
      await _storage!.saveLastResetDate(today);

      print(
          '[ResetBalanceService] Daily reset completed successfully for date: $todayString');
    } catch (e, stackTrace) {
      print('[ResetBalanceService] Error executing daily reset: $e');
      print('[ResetBalanceService] Stack trace: $stackTrace');
      _dailyResetProcessed = false;
    }
  }

  // ----------- WEEKLY RESET -----------

  void _scheduleNextWeeklyReset() {
    _weeklyTimer?.cancel();
    final now = DateTime.now();
    final nextMonday = _getNextMonday(now);
    Duration duration = nextMonday.difference(now);

    if (duration.inMilliseconds <= 0) {
      duration = nextMonday.add(const Duration(days: 7)).difference(now);
    }

    print(
        '[ResetBalanceService] Scheduling next weekly reset in ${duration.inHours} hours (${nextMonday})');

    _weeklyTimer = Timer(duration, () async {
      print('[ResetBalanceService] Weekly timer triggered');
      _weeklyResetProcessed = false;
      await _executeWeeklyReset();
      _scheduleNextWeeklyReset();
    });
  }

  DateTime _getNextMonday(DateTime from) {
    final int daysUntilMonday = (DateTime.monday - from.weekday) % 7;
    final int addDays = daysUntilMonday == 0 ? 7 : daysUntilMonday;
    final nextMondayDate =
        DateTime(from.year, from.month, from.day).add(Duration(days: addDays));
    return DateTime(
        nextMondayDate.year, nextMondayDate.month, nextMondayDate.day, 0, 0, 0);
  }

  Future<void> _executeWeeklyReset() async {
    if (_weeklyResetProcessed) {
      print('[ResetBalanceService] Weekly reset already processed - skipping');
      return;
    }
    if (_context == null) return;

    _weeklyResetProcessed = true;

    try {
      final prefs = await SharedPreferences.getInstance();
      final now = DateTime.now();
      final currentWeekKey = _getWeekKey(now);

      // Double-check to avoid duplicate reset
      final lastReset = prefs.getString('lastWeeklyResetDate');
      if (lastReset == currentWeekKey) {
        print(
            '[ResetBalanceService] Weekly reset already done this week - skipping');
        return;
      }

      print('[ResetBalanceService] Executing weekly reset...');

      final provider = Provider.of<BalanceProvider>(_context!, listen: false);

      // Reset weekly values to 0
      provider.resetWeeklyValues();

      // Save the reset date
      await prefs.setString('lastWeeklyResetDate', currentWeekKey);

      print(
          '[ResetBalanceService] Weekly reset completed for week: $currentWeekKey');
    } catch (e, stackTrace) {
      print('[ResetBalanceService] Error executing weekly reset: $e');
      print('[ResetBalanceService] Stack trace: $stackTrace');
      _weeklyResetProcessed = false;
    }
  }

  // ----------- MONTHLY RESET -----------

  void _scheduleNextMonthlyReset() {
    _monthlyTimer?.cancel();
    final now = DateTime.now();
    DateTime nextMonth = _getNextMonthStart(now);
    Duration duration = nextMonth.difference(now);

    if (duration.inMilliseconds <= 0) {
      nextMonth = _getNextMonthStart(nextMonth.add(const Duration(days: 1)));
      duration = nextMonth.difference(now);
    }

    print(
        '[ResetBalanceService] Scheduling next monthly reset in ${duration.inDays} days, ${duration.inHours % 24} hours (${nextMonth})');

    _monthlyTimer = Timer(duration, () async {
      print('[ResetBalanceService] Monthly timer triggered');
      _monthlyResetProcessed = false;
      await _executeMonthlyReset();
      _scheduleNextMonthlyReset();
    });
  }

  DateTime _getNextMonthStart(DateTime from) {
    DateTime nextMonth;
    if (from.month == 12) {
      nextMonth = DateTime(from.year + 1, 1, 1, 0, 0, 0);
    } else {
      nextMonth = DateTime(from.year, from.month + 1, 1, 0, 0, 0);
    }
    return nextMonth;
  }

  Future<void> _executeMonthlyReset() async {
    if (_monthlyResetProcessed) {
      print('[ResetBalanceService] Monthly reset already processed - skipping');
      return;
    }
    if (_context == null) return;

    _monthlyResetProcessed = true;

    try {
      final prefs = await SharedPreferences.getInstance();
      final now = DateTime.now();
      final currentMonthKey = _getMonthKey(now);

      // Double-check to avoid duplicate reset
      final lastReset = prefs.getString('lastMonthlyResetDate');
      if (lastReset == currentMonthKey) {
        print(
            '[ResetBalanceService] Monthly reset already done this month - skipping');
        return;
      }

      print('[ResetBalanceService] Executing monthly reset...');

      final provider = Provider.of<BalanceProvider>(_context!, listen: false);

      // Reset monthly values to 0
      provider.resetMonthlyValues();

      // Save the reset date
      await prefs.setString('lastMonthlyResetDate', currentMonthKey);

      print(
          '[ResetBalanceService] Monthly reset completed for month: $currentMonthKey');
    } catch (e, stackTrace) {
      print('[ResetBalanceService] Error executing monthly reset: $e');
      print('[ResetBalanceService] Stack trace: $stackTrace');
      _monthlyResetProcessed = false;
    }
  }

  // ----------- HELPERS -----------

  String _getWeekKey(DateTime date) {
    final monday = date.subtract(Duration(days: date.weekday - 1));
    final mondayDateOnly = DateTime(monday.year, monday.month, monday.day);

    final firstDayOfYear = DateTime(mondayDateOnly.year, 1, 1);
    final firstMonday = firstDayOfYear.weekday == DateTime.monday
        ? firstDayOfYear
        : firstDayOfYear
            .add(Duration(days: DateTime.monday - firstDayOfYear.weekday + 7));

    final weekNumber =
        ((mondayDateOnly.difference(firstMonday).inDays) / 7).floor() + 1;

    return '${mondayDateOnly.year}-W${weekNumber.toString().padLeft(2, '0')}-${mondayDateOnly.month.toString().padLeft(2, '0')}-${mondayDateOnly.day.toString().padLeft(2, '0')}';
  }

  String _getMonthKey(DateTime date) =>
      '${date.year}-${date.month.toString().padLeft(2, '0')}';

  void stop() {
    print('[ResetBalanceService] Stopping all timers and resetting state');
    _dailyTimer?.cancel();
    _weeklyTimer?.cancel();
    _monthlyTimer?.cancel();

    _context = null;
    _storage = null;

    _dailyResetProcessed = false;
    _weeklyResetProcessed = false;
    _monthlyResetProcessed = false;

    _isInitialized = false;
    _isInitializing = false;
  }

  void debugPrintState() {
    final now = DateTime.now();
    print('[ResetBalanceService] Current state:');
    print('  - Initialized: $_isInitialized');
    print('  - Daily processed: $_dailyResetProcessed');
    print('  - Weekly processed: $_weeklyResetProcessed');
    print('  - Monthly processed: $_monthlyResetProcessed');
    print('  - Current week key: ${_getWeekKey(now)}');
    print('  - Current month key: ${_getMonthKey(now)}');
    print('  - Next Monday: ${_getNextMonday(now)}');
    print('  - Next month start: ${_getNextMonthStart(now)}');
  }
}
