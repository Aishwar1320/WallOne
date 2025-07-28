import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:wallone/utils/constants.dart';

class AboutUsPage extends StatelessWidget {
  const AboutUsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: mainColor(context),
      appBar: AppBar(
        title: Text(
          "About Us",
          style: GoogleFonts.outfit(
            color: primaryColor(context),
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new, color: primaryColor(context)),
          onPressed: () => Navigator.pop(context),
        ),
        backgroundColor: mainColor(context),
        elevation: 0,
      ),
      body: const Center(child: Text("Hello")),
    );
  }
}
