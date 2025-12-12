import 'dart:convert';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider/path_provider.dart';
import 'package:wallone/utils/constants.dart';
import 'package:wallone/utils/layout.dart';
import 'package:wallone/state/userprofile_provider.dart';

class UserSetupPage extends StatefulWidget {
  const UserSetupPage({super.key});

  @override
  State<UserSetupPage> createState() => _UserSetupPageState();
}

class _UserSetupPageState extends State<UserSetupPage> {
  final TextEditingController _email = TextEditingController();
  final TextEditingController _password = TextEditingController();
  final TextEditingController _name = TextEditingController();
  File? _coverImage;
  final ImagePicker picker = ImagePicker();
  bool isLoading = false;
  bool _isSignIn = true;
  bool _showProfileSetup = false;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _name.dispose();
    super.dispose();
  }

  Future<void> signUp() async {
    try {
      setState(() => isLoading = true);
      final credential =
          await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: _email.text.trim(),
        password: _password.text.trim(),
      );
      await FirebaseFirestore.instance
          .collection("users")
          .doc(credential.user!.uid)
          .set({
        "email": _email.text.trim(),
        "createdAt": DateTime.now(),
      });

      // Show profile setup after signup
      setState(() => _showProfileSetup = true);
    } catch (e) {
      snack("$e");
    } finally {
      setState(() => isLoading = false);
    }
  }

  Future<void> signIn() async {
    try {
      setState(() => isLoading = true);
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _email.text.trim(),
        password: _password.text.trim(),
      );

      // After sign-in, try to load profile from Firestore into provider
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid != null) {
        final doc =
            await FirebaseFirestore.instance.collection('users').doc(uid).get();

        if (doc.exists) {
          final data = doc.data();
          final name = data?['name'] as String?;
          final coverBase64 = data?['coverImageBase64'] as String?;

          // Update provider (and SharedPreferences via provider methods)
          if (name != null && name.isNotEmpty) {
            await context.read<UserProfileProvider>().setName(name);
          }

          if (coverBase64 != null && coverBase64.isNotEmpty) {
            // Save base64 image locally and give provider the path
            try {
              final savedPath =
                  await _saveBase64ImageToLocalFile(coverBase64, uid);
              if (savedPath != null) {
                await context
                    .read<UserProfileProvider>()
                    .setImagePath(savedPath);
              }
            } catch (_) {}
          }
        }
      }

      // Go to the main app
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const DesignLayout()),
      );
    } catch (e) {
      snack("$e");
    } finally {
      setState(() => isLoading = false);
    }
  }

  Future<void> pickImage() async {
    try {
      final picked = await picker.pickImage(source: ImageSource.gallery);
      if (picked != null) {
        setState(() => _coverImage = File(picked.path));
      }
    } catch (e) {
      snack("Failed to pick image: $e");
    }
  }

  String? encodeImageToBase64() {
    if (_coverImage == null) return null;
    final bytes = _coverImage!.readAsBytesSync();
    return base64Encode(bytes);
  }

  Future<void> saveProfile() async {
    if (_name.text.trim().isEmpty) {
      snack("Please enter your name");
      return;
    }
    try {
      setState(() => isLoading = true);
      final uid = FirebaseAuth.instance.currentUser!.uid;
      final imageBase64 = encodeImageToBase64();
      await FirebaseFirestore.instance.collection("users").doc(uid).update({
        "name": _name.text.trim(),
        "coverImageBase64": imageBase64,
      });

      // Update the in-app provider so UI shows the name/image immediately
      try {
        await context.read<UserProfileProvider>().setName(_name.text.trim());
        if (_coverImage != null) {
          // Use the picked file path directly so app can show it immediately
          await context
              .read<UserProfileProvider>()
              .setImagePath(_coverImage!.path);
        }
      } catch (_) {}

      // Mark onboarding as complete
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('hasSeenOnboarding', true);

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const DesignLayout()),
      );
    } catch (e) {
      snack("$e");
    } finally {
      setState(() => isLoading = false);
    }
  }

  /// Helper: save a base64-encoded image string to a local file and return its path
  Future<String?> _saveBase64ImageToLocalFile(
      String base64Str, String uid) async {
    try {
      final bytes = base64Decode(base64Str);
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/user_cover_$uid.png');
      await file.writeAsBytes(bytes);
      return file.path;
    } catch (e) {
      return null;
    }
  }

  void snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: mainColor(context),
      body: _showProfileSetup ? buildProfileSetup() : buildAuthPage(),
    );
  }

  Widget buildAuthPage() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Spacer(),
          Text(
            _isSignIn ? "Welcome Back!" : "Create Account",
            style: GoogleFonts.outfit(
              color: purpleColors(context),
              fontSize: 30,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 40),
          TextField(
            controller: _email,
            style: GoogleFonts.outfit(color: primaryColor(context)),
            decoration: InputDecoration(
              labelText: "Email Address",
              labelStyle: GoogleFonts.outfit(color: primaryColor(context)),
              enabledBorder: OutlineInputBorder(
                borderSide: BorderSide(color: purpleColors(context)),
                borderRadius: BorderRadius.circular(10),
              ),
              focusedBorder: OutlineInputBorder(
                borderSide: BorderSide(color: purpleColors(context), width: 2),
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _password,
            obscureText: true,
            style: GoogleFonts.outfit(color: primaryColor(context)),
            decoration: InputDecoration(
              labelText: "Password",
              labelStyle: GoogleFonts.outfit(color: primaryColor(context)),
              enabledBorder: OutlineInputBorder(
                borderSide: BorderSide(color: purpleColors(context)),
                borderRadius: BorderRadius.circular(10),
              ),
              focusedBorder: OutlineInputBorder(
                borderSide: BorderSide(color: purpleColors(context), width: 2),
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
          const Spacer(),
          isLoading
              ? CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation(purpleColors(context)),
                )
              : Column(
                  children: [
                    ElevatedButton(
                      style: ButtonStyle(
                        backgroundColor: WidgetStatePropertyAll(
                          purpleColors(context),
                        ),
                        padding: const WidgetStatePropertyAll(
                          EdgeInsets.symmetric(horizontal: 40, vertical: 16),
                        ),
                        shape: WidgetStatePropertyAll(
                          RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                      onPressed: _isSignIn ? signIn : signUp,
                      child: Text(
                        _isSignIn ? 'Sign In' : 'Sign Up',
                        style: GoogleFonts.outfit(
                          fontSize: 16,
                          color: primaryColor(context),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          _isSignIn
                              ? "Don't have an account? "
                              : "Already have an account? ",
                          style: GoogleFonts.outfit(
                            color: primaryColor(context).withOpacity(0.7),
                          ),
                        ),
                        GestureDetector(
                          onTap: () {
                            setState(() => _isSignIn = !_isSignIn);
                          },
                          child: Text(
                            _isSignIn ? "Sign Up" : "Sign In",
                            style: GoogleFonts.outfit(
                              color: purpleColors(context),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget buildProfileSetup() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Spacer(),
          Text(
            "Set Up Profile",
            style: GoogleFonts.outfit(
              color: purpleColors(context),
              fontSize: 30,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 30),
          GestureDetector(
            onTap: pickImage,
            child: Container(
              height: 100,
              width: 100,
              decoration: BoxDecoration(
                color: purpleColors(context).withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: purpleColors(context), width: 1),
              ),
              child: _coverImage == null
                  ? Center(
                      child: Icon(
                        Icons.person_2,
                        color: purpleColors(context),
                        size: 30,
                      ),
                    )
                  : ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.file(_coverImage!, fit: BoxFit.cover),
                    ),
            ),
          ),
          const SizedBox(height: 50),
          TextField(
            controller: _name,
            style: GoogleFonts.outfit(color: primaryColor(context)),
            decoration: InputDecoration(
              labelText: "Enter your name!",
              labelStyle: GoogleFonts.outfit(color: primaryColor(context)),
              enabledBorder: OutlineInputBorder(
                borderSide: BorderSide(color: purpleColors(context)),
                borderRadius: BorderRadius.circular(10),
              ),
              focusedBorder: OutlineInputBorder(
                borderSide: BorderSide(color: purpleColors(context), width: 2),
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
          const Spacer(),
          isLoading
              ? CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation(purpleColors(context)),
                )
              : ElevatedButton(
                  style: ButtonStyle(
                    backgroundColor: WidgetStatePropertyAll(
                      purpleColors(context),
                    ),
                    padding: const WidgetStatePropertyAll(
                      EdgeInsets.symmetric(horizontal: 40, vertical: 16),
                    ),
                    shape: WidgetStatePropertyAll(
                      RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                  onPressed: saveProfile,
                  child: Text(
                    'Continue',
                    style: GoogleFonts.outfit(
                      fontSize: 16,
                      color: primaryColor(context),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }
}
