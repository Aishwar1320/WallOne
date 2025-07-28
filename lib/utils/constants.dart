import 'package:flutter/material.dart';

// Colors based on theme

Color mainColor(BuildContext context) =>
    Theme.of(context).brightness == Brightness.light
        ? const Color.fromARGB(255, 250, 241, 251)
        : const Color(0xFF0E0E0E);

Color boxColor(BuildContext context) =>
    Theme.of(context).brightness == Brightness.light
        ? Colors.white
        : const Color(0xFF232326);

Color inversePrimaryColor(BuildContext context) =>
    Theme.of(context).brightness == Brightness.light
        ? Colors.white
        : const Color(0xFF424345);

Color switchColor(BuildContext context) =>
    Theme.of(context).brightness == Brightness.light
        ? const Color(0xFF424345)
        : const Color(0xFF424345);

Color purpleColors(BuildContext context) =>
    Theme.of(context).brightness == Brightness.light
        ? Colors.deepPurpleAccent.shade100
        : const Color.fromARGB(255, 83, 34, 168);

Color cardTextColor(BuildContext context) =>
    Theme.of(context).brightness == Brightness.light
        ? Colors.deepPurpleAccent.shade100
        : Colors.white70;

Color primaryColor(BuildContext context) =>
    Theme.of(context).brightness == Brightness.light
        ? Colors.black
        : Colors.white70;

Color actualInversePrimaryColor(BuildContext context) =>
    Theme.of(context).brightness == Brightness.light
        ? Colors.white70
        : Colors.black;

Color shadowColor(BuildContext context) =>
    Theme.of(context).brightness == Brightness.light
        ? Colors.black26
        : Colors.black38;

Color snackbarColor(BuildContext context) =>
    Theme.of(context).brightness == Brightness.light
        ? Colors.white
        : Colors.grey.shade900;

// Budget Card Colors
Color budgetBackgroundLight(BuildContext context) =>
    Theme.of(context).brightness == Brightness.light
        ? Colors.grey.shade100
        : const Color(0xFF2A2A2D);

Color budgetTextLight(BuildContext context) =>
    Theme.of(context).brightness == Brightness.light
        ? Colors.grey.shade600
        : Colors.grey.shade400;

Color budgetProgressGreen(BuildContext context) =>
    Theme.of(context).brightness == Brightness.light
        ? Colors.green.shade400
        : Colors.green.shade700;

Color budgetProgressOrange(BuildContext context) =>
    Theme.of(context).brightness == Brightness.light
        ? Colors.orange.shade400
        : Colors.orange.shade700;

Color budgetProgressDeepOrange(BuildContext context) =>
    Theme.of(context).brightness == Brightness.light
        ? Colors.deepOrange.shade400
        : Colors.deepOrange.shade700;

Color budgetProgressRed(BuildContext context) =>
    Theme.of(context).brightness == Brightness.light
        ? Colors.red.shade400
        : Colors.red.shade700;

Color budgetDeleteBackground(BuildContext context) =>
    Theme.of(context).brightness == Brightness.light
        ? Colors.red.shade400
        : Colors.red.shade700;

// Snackbar

void showCustomSnackBar(BuildContext context) {
  final overlay = Overlay.of(context);
  final overlayEntry = OverlayEntry(
    builder: (context) {
      return const Positioned(
        bottom: 100, // Position from the bottom
        left: 50,
        right: 40,
        child: _CustomSnackBar(message: 'Coming Soon!'),
      );
    },
  );

  // Insert the custom snackbar into the overlay
  overlay.insert(overlayEntry);

  // Remove the snackbar after the duration
  Future.delayed(const Duration(seconds: 2), () {
    overlayEntry.remove();
  });
}

class _CustomSnackBar extends StatefulWidget {
  final String message;

  const _CustomSnackBar({required this.message});

  @override
  State<_CustomSnackBar> createState() => _CustomSnackBarState();
}

class _CustomSnackBarState extends State<_CustomSnackBar>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );

    _fadeAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    );

    _controller.forward(); // Start the fade-in animation
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _fadeAnimation,
      builder: (context, child) {
        return Opacity(
          opacity: _fadeAnimation.value,
          child: child,
        );
      },
      child: Material(
        color: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.deepPurple,
            borderRadius: BorderRadius.circular(8),
            boxShadow: const [
              BoxShadow(
                color: Colors.black26,
                blurRadius: 8,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.info, color: Colors.white),
              const SizedBox(width: 8),
              Text(
                widget.message,
                style: const TextStyle(color: Colors.white),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
