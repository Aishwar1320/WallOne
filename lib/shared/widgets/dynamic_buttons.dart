import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:wallone/core/utils/constants.dart';

class DynamicButtonsWidget extends StatefulWidget {
  final Function(bool) onSelectionChanged;

  const DynamicButtonsWidget({super.key, required this.onSelectionChanged});

  @override
  State<DynamicButtonsWidget> createState() => _DynamicButtonsWidgetState();
}

class _DynamicButtonsWidgetState extends State<DynamicButtonsWidget> {
  bool isExpensesSelected = true;

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    return Container(
      height: screenWidth / 9,
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: boxColor(context),
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: shadowColor(context).withValues(alpha: 0.1),
            blurRadius: 3,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Expenses Button
          Expanded(
            child: GestureDetector(
              onTap: () {
                setState(() => isExpensesSelected = true);
                widget.onSelectionChanged(true);
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut,
                height: screenWidth / 9,
                decoration: BoxDecoration(
                  color: isExpensesSelected
                      ? purpleColors(context)
                      : Colors.transparent,
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(10),
                    topLeft: Radius.circular(10),
                  ),
                ),
                child: Center(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: AnimatedDefaultTextStyle(
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeInOut,
                      style: GoogleFonts.outfit(
                        color: isExpensesSelected
                            ? primaryColor(context)
                            : switchColor,
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                      ),
                      child: const Text("Expenses"),
                    ),
                  ),
                ),
              ),
            ),
          ),

          // Income Button
          Expanded(
            child: GestureDetector(
              onTap: () {
                setState(() => isExpensesSelected = false);
                widget.onSelectionChanged(false);
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut,
                height: screenWidth / 9,
                decoration: BoxDecoration(
                  color: isExpensesSelected
                      ? Colors.transparent
                      : purpleColors(context),
                  borderRadius: const BorderRadius.only(
                    bottomRight: Radius.circular(10),
                    topRight: Radius.circular(10),
                  ),
                ),
                child: Center(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: AnimatedDefaultTextStyle(
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeInOut,
                      style: GoogleFonts.outfit(
                        color: isExpensesSelected
                            ? switchColor
                            : primaryColor(context),
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                      ),
                      child: const Text("Income"),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

