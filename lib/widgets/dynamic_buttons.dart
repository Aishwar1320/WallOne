import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:wallone/utils/constants.dart';

class DynamicButtonsWidget extends StatefulWidget {
  final Function(bool) onSelectionChanged; // Callback for selection change

  const DynamicButtonsWidget({super.key, required this.onSelectionChanged});

  @override
  State<DynamicButtonsWidget> createState() => _DynamicButtonsWidgetState();
}

class _DynamicButtonsWidgetState extends State<DynamicButtonsWidget> {
  bool isExpensesSelected = true; // Tracks which button is selected

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 55,
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: boxColor(context),
        borderRadius: BorderRadius.circular(25),
        boxShadow: [
          BoxShadow(
            blurRadius: 5,
            offset: const Offset(1, 1),
            color: shadowColor(context),
          )
        ],
      ),
      child: Row(
        children: [
          // Expenses Button
          Expanded(
            child: GestureDetector(
              onTap: () {
                setState(() {
                  isExpensesSelected = true; // Select Expenses
                });
                widget.onSelectionChanged(true); // Notify parent widget
              },
              child: AnimatedContainer(
                duration:
                    const Duration(milliseconds: 300), // Animation duration
                curve: Curves.easeInOut, // Animation curve
                height: 50,
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
                  child: AnimatedDefaultTextStyle(
                    duration:
                        const Duration(milliseconds: 300), // Animation duration
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

          // Income Button
          Expanded(
            child: GestureDetector(
              onTap: () {
                setState(() {
                  isExpensesSelected = false; // Select Income
                });
                widget.onSelectionChanged(false); // Notify parent widget
              },
              child: AnimatedContainer(
                duration:
                    const Duration(milliseconds: 300), // Animation duration
                curve: Curves.easeInOut, // Animation curve
                height: 50,
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
                  child: AnimatedDefaultTextStyle(
                    duration:
                        const Duration(milliseconds: 300), // Animation duration
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
        ],
      ),
    );
  }
}
