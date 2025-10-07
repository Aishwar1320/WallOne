import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:wallone/utils/constants.dart';

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
      height: screenWidth / 7,
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: boxColor(context),
        borderRadius: BorderRadius.circular(27),
        boxShadow: [
          BoxShadow(
            color: shadowColor(context).withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
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
                height: screenWidth / 7,
                decoration: BoxDecoration(
                  color: isExpensesSelected
                      ? purpleColors(context)
                      : Colors.transparent,
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(20),
                    topLeft: Radius.circular(20),
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
                            : switchColor(context),
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
                height: screenWidth / 7,
                decoration: BoxDecoration(
                  color: isExpensesSelected
                      ? Colors.transparent
                      : purpleColors(context),
                  borderRadius: const BorderRadius.only(
                    bottomRight: Radius.circular(20),
                    topRight: Radius.circular(20),
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
                            ? switchColor(context)
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
