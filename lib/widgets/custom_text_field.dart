import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:wallone/utils/constants.dart';

class CustomTextField extends StatefulWidget {
  final TextEditingController controller;
  final String labelText;
  final IconData prefixIcon;
  final TextInputType keyboardType;
  final String? Function(String?)? validator;

  const CustomTextField({
    Key? key,
    required this.controller,
    required this.labelText,
    required this.prefixIcon,
    this.keyboardType = TextInputType.text,
    this.validator,
  }) : super(key: key);

  @override
  _CustomTextFieldState createState() => _CustomTextFieldState();
}

class _CustomTextFieldState extends State<CustomTextField> {
  late FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode();
    _focusNode.addListener(() {
      if (_focusNode.hasFocus) {
        // Trigger a rebuild to clear or update error styling if needed.
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            blurRadius: 5,
            color: shadowColor(context),
          ),
        ],
      ),
      child: TextFormField(
        controller: widget.controller,
        focusNode: _focusNode,
        keyboardType: widget.keyboardType,
        autovalidateMode: AutovalidateMode.onUserInteraction,
        validator: widget.validator,
        decoration: InputDecoration(
          labelText: widget.labelText,
          labelStyle: GoogleFonts.outfit(
            color: primaryColor(context).withOpacity(0.7),
            fontWeight: FontWeight.w500,
          ),
          prefixIcon: Icon(
            widget.prefixIcon,
            color: primaryColor(context).withOpacity(0.7),
          ),
          errorStyle: GoogleFonts.outfit(
            color: Colors.redAccent,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
          filled: true,
          fillColor: budgetBackgroundLight(context),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(
              color: Theme.of(context).primaryColor,
              width: 1.5,
            ),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(
              color: Colors.redAccent,
              width: 1.5,
            ),
          ),
          focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(
              color: Colors.redAccent,
              width: 1.5,
            ),
          ),
        ),
      ),
    );
  }
}
