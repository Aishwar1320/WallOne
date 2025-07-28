import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:wallone/utils/constants.dart';

// For Static Data
class DropdownMenuStaticWidget extends StatefulWidget {
  final Color boxColor;
  final String hintText;
  final String? label0;
  final String? label1;
  final String? label2;
  final String? label3;
  final String? label4;
  final String? label5;
  final String? label6;
  final String? label7;
  final String? label8;
  final String? label9;
  final String? label10;
  final String? label11;

  const DropdownMenuStaticWidget({
    super.key,
    required this.boxColor,
    required this.hintText,
    this.label0,
    this.label1,
    this.label2,
    this.label3,
    this.label4,
    this.label5,
    this.label6,
    this.label7,
    this.label8,
    this.label9,
    this.label10,
    this.label11,
  });

  @override
  _DropdownMenuStaticWidgetState createState() =>
      _DropdownMenuStaticWidgetState();
}

class _DropdownMenuStaticWidgetState extends State<DropdownMenuStaticWidget> {
  String? selectedItem;

  @override
  Widget build(BuildContext context) {
    // Collect all labels and filter out null values
    final labels = [
      widget.label0,
      widget.label1,
      widget.label2,
      widget.label3,
      widget.label4,
      widget.label5,
      widget.label6,
      widget.label7,
      widget.label8,
      widget.label9,
      widget.label10,
      widget.label11,
    ].where((label) => label != null).toList();

    return Column(
      children: [
        Container(
          height: 55,
          decoration: BoxDecoration(
            color: widget.boxColor,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                blurRadius: 5,
                offset: const Offset(1, 1),
                color: shadowColor(context),
              ),
            ],
          ),
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: DropdownButton<String>(
                menuMaxHeight: 200,
                borderRadius: BorderRadius.circular(20),
                value: selectedItem,
                hint: Text(
                  widget.hintText,
                  style: GoogleFonts.outfit(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: primaryColor(context),
                  ),
                ),
                icon: const Icon(Icons.keyboard_arrow_down),
                iconSize: 24,
                elevation: 16,
                style: GoogleFonts.outfit(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
                underline: Container(), // Remove the default underline
                isExpanded: true,
                onChanged: (String? newValue) {
                  setState(() {
                    selectedItem = newValue;
                  });
                },
                items: labels.map<DropdownMenuItem<String>>((String? value) {
                  return DropdownMenuItem<String>(
                    value: value,
                    child: Text(
                      value!,
                      style: GoogleFonts.outfit(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: primaryColor(context),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// For Dynamic Data
class DropdownMenuDynamicWidget extends StatefulWidget {
  final Color boxColor;
  final String hintText;
  final String? value;
  final List<String>? items;
  final Function(String?) onItemSelected;
  final String? customDisplayText;

  const DropdownMenuDynamicWidget({
    super.key,
    required this.boxColor,
    required this.hintText,
    this.value,
    this.items,
    required this.onItemSelected,
    this.customDisplayText,
  });

  @override
  _DropdownMenuDynamicWidgetState createState() =>
      _DropdownMenuDynamicWidgetState();
}

class _DropdownMenuDynamicWidgetState extends State<DropdownMenuDynamicWidget> {
  String? selectedItem;

  @override
  void initState() {
    super.initState();
    final items = _getFilteredItems();

    // Ensure defaultSelected exists in the list; otherwise, set to null
    selectedItem = items.contains(widget.value) ? widget.value : null;
  }

  /// Removes duplicate items and ensures no null values
  List<String> _getFilteredItems() {
    return (widget.items ?? []).toSet().toList(); // Removes duplicates
  }

  @override
  Widget build(BuildContext context) {
    final items = _getFilteredItems();

    return Column(
      children: [
        Container(
          height: 50,
          decoration: BoxDecoration(
            color: widget.boxColor,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                blurRadius: 5,
                color: shadowColor(context),
              ),
            ],
          ),
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: DropdownButton<String>(
                menuMaxHeight: 200,
                borderRadius: BorderRadius.circular(20),
                value: items.contains(selectedItem) ? selectedItem : null,
                hint: Text(
                  widget.hintText,
                  style: GoogleFonts.outfit(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: primaryColor(context),
                  ),
                ),
                icon: Icon(
                  Icons.keyboard_arrow_down,
                  color: primaryColor(context),
                ),
                iconSize: 24,
                elevation: 16,
                underline: Container(),
                isExpanded: true,
                onChanged: (String? newValue) {
                  setState(() {
                    selectedItem = newValue;
                  });
                  widget.onItemSelected(newValue);
                },
                items: items.map<DropdownMenuItem<String>>((String value) {
                  return DropdownMenuItem<String>(
                    value: value,
                    child: Text(
                      value,
                      style: GoogleFonts.outfit(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: primaryColor(context),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
