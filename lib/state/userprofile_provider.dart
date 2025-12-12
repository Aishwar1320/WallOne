import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class UserProfileProvider extends ChangeNotifier {
  String? userName;
  String? coverImagePath; // local file path for display
  bool isPremium = false;

  StreamSubscription<User?>? _authSub;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _userDocSub;

  UserProfileProvider() {
    _init();
  }

  Future<void> _init() async {
    // Read any cached values quickly for faster UX (optional)
    try {
      final prefs = await SharedPreferences.getInstance();
      userName = prefs.getString('userName');
      coverImagePath = prefs.getString('coverImagePath');
      isPremium = prefs.getBool('isPremium') ?? false;
    } catch (_) {}

    // Listen to auth state so we can subscribe/unsubscribe to user's doc
    _authSub = FirebaseAuth.instance.authStateChanges().listen((user) async {
      // cancel previous firestore listener
      await _userDocSub?.cancel();
      _userDocSub = null;

      if (user == null) {
        // logged out — clear profile in memory (keep cache if desired)
        userName = null;
        coverImagePath = null;
        isPremium = false;
        notifyListeners();
      } else {
        // signed in — subscribe to their firestore doc for realtime updates
        _subscribeToFirestoreUser(user.uid);
      }
    });
  }

  Future<void> _subscribeToFirestoreUser(String uid) async {
    try {
      final docRef = FirebaseFirestore.instance.collection('users').doc(uid);
      _userDocSub = docRef.snapshots().listen((snapshot) async {
        if (!snapshot.exists) return;
        final data = snapshot.data();
        final remoteName = data?['name'] as String?;
        final remotePremium = data?['isPremium'];
        final coverBase64 = data?['coverImageBase64'] as String?;

        if (remoteName != null) userName = remoteName;
        if (remotePremium is bool) {
          isPremium = remotePremium;
        } else if (remotePremium is int) {
          // sometimes boolean flags may be stored as 0/1
          isPremium = remotePremium != 0;
        }
        if (coverBase64 != null && coverBase64.isNotEmpty) {
          final savedPath = await _saveBase64ImageToLocalFile(coverBase64, uid);
          if (savedPath != null) coverImagePath = savedPath;
        }

        // Cache values locally for quick startup
        try {
          final prefs = await SharedPreferences.getInstance();
          if (userName != null) await prefs.setString('userName', userName!);
          if (coverImagePath != null) {
            await prefs.setString('coverImagePath', coverImagePath!);
          }
          await prefs.setBool('isPremium', isPremium);
        } catch (_) {}

        notifyListeners();
      });
    } catch (e) {
      // ignore listen errors — don't crash provider
    }
  }

  /// When setting a name, write to Firestore if signed-in; otherwise fallback to local prefs
  Future<void> setName(String name) async {
    userName = name;
    notifyListeners();

    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) {
      try {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .set({'name': name}, SetOptions(merge: true));
      } catch (_) {}
    } else {
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('userName', name);
      } catch (_) {}
    }
  }

  /// When setting an image path (local file), save as base64 to Firestore and keep local path for UI
  Future<void> setImagePath(String path) async {
    coverImagePath = path;
    notifyListeners();

    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) {
      try {
        final f = File(path);
        if (await f.exists()) {
          final bytes = await f.readAsBytes();
          final base64Img = base64Encode(bytes);
          await FirebaseFirestore.instance
              .collection('users')
              .doc(uid)
              .set({'coverImageBase64': base64Img}, SetOptions(merge: true));
        }
      } catch (_) {}
    } else {
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('coverImagePath', path);
      } catch (_) {}
    }
  }

  /// Set premium status for the current user. Persists to Firestore when signed in,
  /// otherwise caches locally in SharedPreferences.
  Future<void> setPremium(bool value) async {
    isPremium = value;
    notifyListeners();

    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) {
      try {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .set({'isPremium': value}, SetOptions(merge: true));
      } catch (_) {}
    } else {
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('isPremium', value);
      } catch (_) {}
    }
  }

  Future<void> clear() async {
    userName = null;
    coverImagePath = null;
    isPremium = false;
    notifyListeners();

    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) {
      try {
        await FirebaseFirestore.instance.collection('users').doc(uid).set({
          'name': FieldValue.delete(),
          'coverImageBase64': FieldValue.delete(),
          'isPremium': FieldValue.delete(),
        }, SetOptions(merge: true));
      } catch (_) {}
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('userName');
      await prefs.remove('coverImagePath');
      await prefs.remove('isPremium');
    } catch (_) {}
  }

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

  @override
  void dispose() {
    _authSub?.cancel();
    _userDocSub?.cancel();
    super.dispose();
  }
}
