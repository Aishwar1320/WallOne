import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:wallone/state/balance_provider.dart';
import 'package:wallone/state/budget_provider.dart';

class UsageCard extends StatefulWidget {
  final BudgetProvider budgetProvider;
  final BalanceProvider balanceProvider;
  final double progress;

  const UsageCard({
    super.key,
    required this.budgetProvider,
    required this.balanceProvider,
    required this.progress,
  });

  @override
  State<UsageCard> createState() => _UsageCardState();
}

class _UsageCardState extends State<UsageCard>
    with SingleTickerProviderStateMixin {
  bool showDaily = true;
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 500));
    _animation = Tween<double>(begin: 0, end: 1).animate(_controller);
  }

  void _toggleCard() {
    if (showDaily) {
      _controller.forward();
    } else {
      _controller.reverse();
    }
    setState(() {
      showDaily = !showDaily;
    });
  }

  @override
  Widget build(BuildContext context) {
    final code = context.read<BalanceProvider>().currencyCode;
    final symbol = NumberFormat.simpleCurrency(name: code).currencySymbol;
    final screenWidth = MediaQuery.of(context).size.width;

    return GestureDetector(
      onTap: _toggleCard,
      child: AnimatedBuilder(
        animation: _animation,
        builder: (context, child) {
          final angle = _animation.value * 3.14;
          final isFront = _animation.value < 0.5;

          final usage = isFront
              ? widget.budgetProvider.dailyUsage
              : widget.budgetProvider.weeklyUsage;
          final label = isFront ? "Monthly Usage" : "Weekly Usage";

          return Transform(
            alignment: Alignment.center,
            transform: Matrix4.identity()
              ..setEntry(3, 2, 0.001)
              ..rotateY(angle),
            child: isFront
                ? _buildCardContent(label, usage, symbol, screenWidth)
                : Transform(
                    alignment: Alignment.center,
                    transform: Matrix4.identity()..rotateY(3.14),
                    child: _buildCardContent(label, usage, symbol, screenWidth),
                  ),
          );
        },
      ),
    );
  }

  Widget _buildCardContent(
      String label, double usage, String symbol, double screenWidth) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Icon(
                  Icons.calendar_today,
                  color: Colors.white.withValues(alpha: 0.9),
                  size: 14,
                ),
              ),
              const SizedBox(
                width: 9,
              ),
              Text(
                label,
                style: GoogleFonts.outfit(
                  fontSize: screenWidth / 27,
                  color: Colors.white70,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            spacing: 8,
            children: [
              Text(
                "Daily",
                style: GoogleFonts.outfit(
                  fontSize: screenWidth / 38,
                  fontWeight: FontWeight.bold,
                  color: Colors.white70,
                ),
              ),
              Text(
                "$symbol${usage.toStringAsFixed(2)}",
                style: GoogleFonts.outfit(
                  fontSize: screenWidth / 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

