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
  bool _dailyResetProcessed = false;
  bool _isInitialized = false;
  bool _isInitializing = false;

  void startResetTimers(BuildContext context) {
    // Prevent multiple initializations
    if (_isInitialized || _isInitializing) {
      print(
          '[ResetBalanceService] Already initialized or initializing - skipping');
      return;
    }

    _context = context;
    _initializeStorage();
  }

  Future<void> _initializeStorage() async {
    _storage = await BalanceStorage.create();

    await _checkAndResetDailyIfNeeded();
    await _checkAndResetWeeklyIfNeeded();
    await _checkAndResetMonthlyIfNeeded();

    _scheduleNextDailyReset();
    _scheduleNextWeeklyReset();
    _scheduleNextMonthlyReset();
  }

  // ----------- DAILY RESET -----------
  void _scheduleNextDailyReset() {
    _dailyTimer?.cancel();

    // Don't schedule if not properly initialized
    if (!_isInitialized) {
      print(
          '[ResetBalanceService] Not scheduling daily reset - not initialized');
      return;
    }

    final now = DateTime.now().toUtc();
    final nextMidnight = DateTime(now.year, now.month, now.day + 1).toUtc();
    final duration = nextMidnight.difference(now);

    print(
        '[ResetBalanceService] Scheduling next daily reset in ${duration.inHours} hours');

    _dailyTimer = Timer(duration, () {
      print(
          '[ResetBalanceService] Daily timer triggered - resetting flag and executing');
      _dailyResetProcessed = false; // Reset the flag for the new day
      _executeDailyReset().then((_) {
        _scheduleNextDailyReset(); // Schedule next reset after completion
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
      final todayString = today.toIso8601String();

      print(
          '[ResetBalanceService] Checking daily reset - Today: $todayString, Last reset: $lastResetDateStr');

      if (lastResetDateStr == null || lastResetDateStr != todayString) {
        print('[ResetBalanceService] Daily reset needed');
        await _executeDailyReset();
      } else {
        print(
            '[ResetBalanceService] Daily reset not needed - already done today');
        _dailyResetProcessed =
            true; // Mark as processed since it's already done
      }
    } catch (e) {
      print('[ResetBalanceService] Error checking daily reset: $e');
    }
  }

  Future<void> _executeDailyReset() async {
    // Check if already processed to prevent infinite loops
    if (_dailyResetProcessed) {
      print(
          '[ResetBalanceService] Daily reset already processed today - skipping execution');
      return;
    }

    if (_context == null || _storage == null) {
      print(
          '[ResetBalanceService] Context or storage not available for daily reset');
      return;
    }

    // Set the flag immediately to prevent race conditions
    _dailyResetProcessed = true;

    try {
      print('[ResetBalanceService] Executing daily reset...');
      final provider = Provider.of<BalanceProvider>(_context!, listen: false);
      final resetHappened = await provider.resetDailyBalance();

      if (resetHappened) {
        print('[ResetBalanceService] Daily reset completed successfully');
      } else {
        print('[ResetBalanceService] Daily reset was skipped (already done)');
      }
    } catch (e) {
      print('[ResetBalanceService] Error executing daily reset: $e');
    }
  }

  // ----------- WEEKLY RESET -----------
  void _scheduleNextWeeklyReset() {
    _weeklyTimer?.cancel();
    final now = DateTime.now().toUtc();
    final daysUntilNextMonday = (8 - now.weekday) % 7;
    final nextMonday =
        DateTime(now.year, now.month, now.day + daysUntilNextMonday).toUtc();
    final duration = nextMonday.difference(now);

    _weeklyTimer = Timer(duration, () {
      _executeWeeklyReset().then((_) {
        _scheduleNextWeeklyReset();
      });
    });
  }

  Future<void> _checkAndResetWeeklyIfNeeded() async {
    final prefs = await SharedPreferences.getInstance();
    final lastReset = prefs.getString('lastWeeklyResetDate');
    final now = DateTime.now().toUtc();
    final currentWeek = _getWeekKey(now);

    if (lastReset == null || lastReset != currentWeek) {
      await _executeWeeklyReset();
    }
  }

  Future<void> _executeWeeklyReset() async {
    if (_context != null) {
      try {
        print('[ResetBalanceService] Executing weekly reset...');
        final provider = Provider.of<BalanceProvider>(_context!, listen: false);
        provider.resetWeeklyBalance();
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(
            'lastWeeklyResetDate', _getWeekKey(DateTime.now().toUtc()));
        print('[ResetBalanceService] Weekly reset completed');
      } catch (e) {
        print('[ResetBalanceService] Error executing weekly reset: $e');
      }
    }
  }

  // ----------- MONTHLY RESET -----------
  void _scheduleNextMonthlyReset() {
    _monthlyTimer?.cancel();
    final now = DateTime.now().toUtc();
    final nextMonth = DateTime(now.year, now.month + 1, 1).toUtc();
    final duration = nextMonth.difference(now);

    _monthlyTimer = Timer(duration, () {
      _executeMonthlyReset().then((_) {
        _scheduleNextMonthlyReset();
      });
    });
  }

  Future<void> _checkAndResetMonthlyIfNeeded() async {
    final prefs = await SharedPreferences.getInstance();
    final lastReset = prefs.getString('lastMonthlyResetDate');
    final now = DateTime.now().toUtc();
    final currentMonthKey = _getMonthKey(now);

    if (lastReset == null || lastReset != currentMonthKey) {
      await _executeMonthlyReset();
    }
  }

  Future<void> _executeMonthlyReset() async {
    if (_context != null) {
      try {
        print('[ResetBalanceService] Executing monthly reset...');
        final provider = Provider.of<BalanceProvider>(_context!, listen: false);
        provider.resetMonthlyBalance();
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(
            'lastMonthlyResetDate', _getMonthKey(DateTime.now().toUtc()));
        print('[ResetBalanceService] Monthly reset completed');
      } catch (e) {
        print('[ResetBalanceService] Error executing monthly reset: $e');
      }
    }
  }

  // ----------- HELPERS -----------

  String _getWeekKey(DateTime date) {
    final monday = date.subtract(Duration(days: date.weekday - 1));
    return '${monday.year}-W${monday.month.toString().padLeft(2, '0')}-${monday.day.toString().padLeft(2, '0')}';
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
    _isInitialized = false;
    _isInitializing = false;
  }
}
