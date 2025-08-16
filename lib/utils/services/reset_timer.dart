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
    _storage = await BalanceStorage.create();

    await _checkAndResetDailyIfNeeded();
    await _checkAndResetWeeklyIfNeeded();
    await _checkAndResetMonthlyIfNeeded();

    _scheduleNextDailyReset();
    _scheduleNextWeeklyReset();
    _scheduleNextMonthlyReset();

    _isInitialized = true;
    _isInitializing = false;
  }

  // ----------- DAILY RESET -----------
  void _scheduleNextDailyReset() {
    _dailyTimer?.cancel();

    if (!_isInitialized) {
      print(
          '[ResetBalanceService] Not scheduling daily reset - not initialized');
      return;
    }

    final now = DateTime.now();
    final nextMidnight = DateTime(now.year, now.month, now.day + 1, 0, 0, 1);
    final duration = nextMidnight.difference(now);

    // Ensure minimum 1 minute delay
    final finalDuration =
        duration.inMinutes < 1 ? Duration(minutes: 1) : duration;

    print(
        '[ResetBalanceService] Scheduling next daily reset in ${finalDuration.inHours} hours');

    _dailyTimer = Timer(finalDuration, () {
      print('[ResetBalanceService] Daily timer triggered');
      _dailyResetProcessed = false;
      _executeDailyReset().then((_) {
        _scheduleNextDailyReset();
      });
    });
  }

  Future<void> _checkAndResetDailyIfNeeded() async {
    if (_storage == null) return;

    try {
      final balances = await _storage!.loadBalances();
      final lastResetDateStr = balances['lastResetDate'];
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final todayString =
          today.toIso8601String().split('T')[0]; // Use only date part

      print(
          '[ResetBalanceService] Checking daily reset - Today: $todayString, Last reset: $lastResetDateStr');

      if (lastResetDateStr == null || lastResetDateStr != todayString) {
        print('[ResetBalanceService] Daily reset needed');
        await _executeDailyReset();
      } else {
        print(
            '[ResetBalanceService] Daily reset not needed - already done today');
        _dailyResetProcessed = true;
      }
    } catch (e) {
      print('[ResetBalanceService] Error checking daily reset: $e');
    }
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
      final provider = Provider.of<BalanceProvider>(_context!, listen: false);
      final resetHappened = await provider.resetDailyBalance();

      if (resetHappened) {
        print('[ResetBalanceService] Daily reset completed successfully');
      }
    } catch (e) {
      print('[ResetBalanceService] Error executing daily reset: $e');
      _dailyResetProcessed = false; // Reset flag on error
    }
  }

  // ----------- WEEKLY RESET -----------
  void _scheduleNextWeeklyReset() {
    _weeklyTimer?.cancel();

    final now = DateTime.now();
    final nextMonday = _getNextMonday(now);
    final duration = nextMonday.difference(now);

    print(
        '[ResetBalanceService] Scheduling next weekly reset in ${duration.inHours} hours (${nextMonday})');

    _weeklyTimer = Timer(duration, () {
      print('[ResetBalanceService] Weekly timer triggered');
      _weeklyResetProcessed = false;
      _executeWeeklyReset().then((_) {
        _scheduleNextWeeklyReset();
      });
    });
  }

  DateTime _getNextMonday(DateTime from) {
    // If today is Monday (weekday = 1), get next Monday
    // Otherwise, get the coming Monday
    final daysUntilMonday = from.weekday == DateTime.monday
        ? 7
        : (DateTime.monday - from.weekday + 7) % 7;
    final nextMonday =
        DateTime(from.year, from.month, from.day + daysUntilMonday);

    // Set to start of day (00:00:01 to avoid exact midnight issues)
    final scheduledTime =
        DateTime(nextMonday.year, nextMonday.month, nextMonday.day, 0, 0, 1);

    // If the calculated time is in the past or too close (less than 1 minute), add a week
    if (scheduledTime.isBefore(from) ||
        scheduledTime.difference(from).inMinutes < 1) {
      return scheduledTime.add(Duration(days: 7));
    }

    return scheduledTime;
  }

  Future<void> _checkAndResetWeeklyIfNeeded() async {
    final prefs = await SharedPreferences.getInstance();
    final lastReset = prefs.getString('lastWeeklyResetDate');
    final now = DateTime.now();
    final currentWeekKey = _getWeekKey(now);

    print(
        '[ResetBalanceService] Weekly reset check: currentWeek=$currentWeekKey, lastReset=$lastReset');

    if (lastReset == null || lastReset != currentWeekKey) {
      print('[ResetBalanceService] Weekly reset needed');
      await _executeWeeklyReset();
    } else {
      print(
          '[ResetBalanceService] Weekly reset not needed - already done this week');
      _weeklyResetProcessed = true;
    }
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
      final currentWeekKey = _getWeekKey(DateTime.now());

      // Double-check to avoid duplicate reset
      final lastReset = prefs.getString('lastWeeklyResetDate');
      if (lastReset == currentWeekKey) {
        print(
            '[ResetBalanceService] Weekly reset already done this week - skipping');
        return;
      }

      print('[ResetBalanceService] Executing weekly reset...');
      final provider = Provider.of<BalanceProvider>(_context!, listen: false);
      provider.resetWeeklyBalance();

      await prefs.setString('lastWeeklyResetDate', currentWeekKey);
      print(
          '[ResetBalanceService] Weekly reset completed for week: $currentWeekKey');
    } catch (e) {
      print('[ResetBalanceService] Error executing weekly reset: $e');
      _weeklyResetProcessed = false; // Reset flag on error
    }
  }

  // ----------- MONTHLY RESET -----------
  void _scheduleNextMonthlyReset() {
    _monthlyTimer?.cancel();

    final now = DateTime.now();
    final nextMonth = _getNextMonthStart(now);
    final duration = nextMonth.difference(now);

    print(
        '[ResetBalanceService] Scheduling next monthly reset in ${duration.inDays} days, ${duration.inHours % 24} hours (${nextMonth})');

    // IMPORTANT: For very long durations (>7 days), use a shorter interval and recheck
    Duration scheduleDuration;
    if (duration.inDays > 7) {
      // Schedule a check in 24 hours instead of the full duration
      scheduleDuration = Duration(hours: 24);
      print(
          '[ResetBalanceService] Using 24-hour check instead of full duration due to long delay');
    } else if (duration.inHours < 1) {
      // Minimum 1 hour delay
      scheduleDuration = Duration(hours: 1);
      print('[ResetBalanceService] Applied minimum 1-hour delay');
    } else {
      scheduleDuration = duration;
    }

    _monthlyTimer = Timer(scheduleDuration, () {
      print('[ResetBalanceService] Monthly timer triggered');

      // Check if it's actually time for the reset
      final checkTime = DateTime.now();
      final targetMonth = _getNextMonthStart(checkTime
          .subtract(Duration(days: 1))); // Check if we're in the target month

      if (checkTime.isAfter(targetMonth) ||
          checkTime.isAtSameMomentAs(targetMonth)) {
        print('[ResetBalanceService] Time for monthly reset');
        _monthlyResetProcessed = false;
        _executeMonthlyReset().then((_) {
          _scheduleNextMonthlyReset();
        });
      } else {
        print(
            '[ResetBalanceService] Not yet time for monthly reset, rescheduling...');
        _scheduleNextMonthlyReset();
      }
    });
  }

  DateTime _getNextMonthStart(DateTime from) {
    // Get the first day of next month
    DateTime nextMonth;

    if (from.month == 12) {
      nextMonth = DateTime(from.year + 1, 1, 1, 0, 0, 1);
    } else {
      nextMonth = DateTime(from.year, from.month + 1, 1, 0, 0, 1);
    }

    // Debug logging
    print('[ResetBalanceService] Current time: $from');
    print('[ResetBalanceService] Calculated next month start: $nextMonth');
    print('[ResetBalanceService] Duration: ${nextMonth.difference(from)}');

    // If the calculated time is in the past or too soon (less than 1 hour), move to next month
    if (nextMonth.isBefore(from) || nextMonth.difference(from).inHours < 1) {
      print(
          '[ResetBalanceService] Next month start is too soon, moving to following month');
      if (nextMonth.month == 12) {
        nextMonth = DateTime(nextMonth.year + 1, 1, 1, 0, 0, 1);
      } else {
        nextMonth = DateTime(nextMonth.year, nextMonth.month + 1, 1, 0, 0, 1);
      }
      print('[ResetBalanceService] Adjusted next month start: $nextMonth');
    }

    return nextMonth;
  }

  Future<void> _checkAndResetMonthlyIfNeeded() async {
    final prefs = await SharedPreferences.getInstance();
    final lastReset = prefs.getString('lastMonthlyResetDate');
    final now = DateTime.now();
    final currentMonthKey = _getMonthKey(now);

    print(
        '[ResetBalanceService] Monthly reset check: currentMonth=$currentMonthKey, lastReset=$lastReset');

    if (lastReset == null || lastReset != currentMonthKey) {
      print('[ResetBalanceService] Monthly reset needed');
      await _executeMonthlyReset();
    } else {
      print(
          '[ResetBalanceService] Monthly reset not needed - already done this month');
      _monthlyResetProcessed = true;
    }
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
      final currentMonthKey = _getMonthKey(DateTime.now());

      // Double-check to avoid duplicate reset
      final lastReset = prefs.getString('lastMonthlyResetDate');
      if (lastReset == currentMonthKey) {
        print(
            '[ResetBalanceService] Monthly reset already done this month - skipping');
        return;
      }

      print('[ResetBalanceService] Executing monthly reset...');
      final provider = Provider.of<BalanceProvider>(_context!, listen: false);
      provider.resetMonthlyBalance();

      await prefs.setString('lastMonthlyResetDate', currentMonthKey);
      print(
          '[ResetBalanceService] Monthly reset completed for month: $currentMonthKey');
    } catch (e) {
      print('[ResetBalanceService] Error executing monthly reset: $e');
      _monthlyResetProcessed = false; // Reset flag on error
    }
  }

  // ----------- HELPERS -----------

  String _getWeekKey(DateTime date) {
    // Get the Monday of the week containing this date
    final monday = date.subtract(Duration(days: date.weekday - 1));
    final mondayDateOnly = DateTime(monday.year, monday.month, monday.day);

    // Calculate week number based on the first Monday of the year
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

  // Debug method to check current state
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
