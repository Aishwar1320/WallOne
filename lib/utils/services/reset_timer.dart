import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wallone/state/balance_provider.dart';

class ResetBalanceService {
  Timer? _dailyTimer;
  Timer? _weeklyTimer;
  Timer? _monthlyTimer;
  BuildContext? _context;

  void startResetTimers(BuildContext context) {
    _context = context;

    _checkAndResetDailyIfNeeded();
    _checkAndResetWeeklyIfNeeded();
    _checkAndResetMonthlyIfNeeded();

    _scheduleNextDailyReset();
    _scheduleNextWeeklyReset();
    _scheduleNextMonthlyReset();
  }

  // ----------- DAILY RESET -----------
  void _scheduleNextDailyReset() {
    _dailyTimer?.cancel();
    final now = DateTime.now().toUtc();
    final nextMidnight = DateTime(now.year, now.month, now.day + 1).toUtc();
    final duration = nextMidnight.difference(now);

    _dailyTimer = Timer(duration, () {
      _executeDailyReset();
      _scheduleNextDailyReset();
    });
  }

  Future<void> _checkAndResetDailyIfNeeded() async {
    final prefs = await SharedPreferences.getInstance();
    final lastReset = prefs.getString('lastDailyResetDate');
    final today = _formatDate(DateTime.now().toUtc());

    if (lastReset == null || lastReset != today) {
      await _executeDailyReset();
    }
  }

  Future<void> _executeDailyReset() async {
    if (_context != null) {
      final provider = Provider.of<BalanceProvider>(_context!, listen: false);
      provider.resetDailyBalance();
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
          'lastDailyResetDate', _formatDate(DateTime.now().toUtc()));
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
      _executeWeeklyReset();
      _scheduleNextWeeklyReset();
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
      final provider = Provider.of<BalanceProvider>(_context!, listen: false);
      provider.resetWeeklyBalance();
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
          'lastWeeklyResetDate', _getWeekKey(DateTime.now().toUtc()));
    }
  }

  // ----------- MONTHLY RESET -----------
  void _scheduleNextMonthlyReset() {
    _monthlyTimer?.cancel();
    final now = DateTime.now().toUtc();
    final nextMonth = DateTime(now.year, now.month + 1, 1).toUtc();
    final duration = nextMonth.difference(now);

    _monthlyTimer = Timer(duration, () {
      _executeMonthlyReset();
      _scheduleNextMonthlyReset();
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
      final provider = Provider.of<BalanceProvider>(_context!, listen: false);
      provider.resetMonthlyBalance();
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
          'lastMonthlyResetDate', _getMonthKey(DateTime.now().toUtc()));
    }
  }

  // ----------- HELPERS -----------
  String _formatDate(DateTime date) =>
      '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

  String _getWeekKey(DateTime date) {
    final monday = date.subtract(Duration(days: date.weekday - 1));
    return '${monday.year}-W${monday.month.toString().padLeft(2, '0')}-${monday.day.toString().padLeft(2, '0')}';
  }

  String _getMonthKey(DateTime date) =>
      '${date.year}-${date.month.toString().padLeft(2, '0')}';

  void stop() {
    _dailyTimer?.cancel();
    _weeklyTimer?.cancel();
    _monthlyTimer?.cancel();
    _context = null;
  }
}
