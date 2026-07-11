import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class UserProfileProvider extends ChangeNotifier {
  String? userName;
  String? coverImagePath; // local file path for display
  bool isPremium = true; // Hardcoded to true for V1 to unlock all features

  StreamSubscription<User?>? _authSub;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _userDocSub;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _userImageSub;


  UserProfileProvider() {
    _init();
  }

  Future<void> _loadFromLocal() async {
    try {
      const storage = FlutterSecureStorage();
      userName = await storage.read(key: 'cached_userName');
      coverImagePath = await storage.read(key: 'cached_coverImagePath');
      isPremium = true; // Always true for V1
      notifyListeners();
    } catch (e) {
      debugPrint('[UserProfileProvider] Error loading local cache: $e');
    }
  }

  Future<void> _saveToLocal(String key, dynamic value) async {
    try {
      const storage = FlutterSecureStorage();
      if (value == null) {
        await storage.delete(key: key);
      } else {
        await storage.write(key: key, value: value.toString());
      }
    } catch (e) {
      debugPrint('[UserProfileProvider] Error saving local cache: $e');
    }
  }

  Future<void> _init() async {
    await _loadFromLocal();


    // Listen to auth state so we can subscribe/unsubscribe to user's doc
    _authSub = FirebaseAuth.instance.authStateChanges().listen((user) async {
      // cancel previous firestore listener
      await _userDocSub?.cancel();
      _userDocSub = null;
      await _userImageSub?.cancel();
      _userImageSub = null;

      if (user == null) {
        // logged out — clear profile in memory
        userName = null;
        coverImagePath = null;
        isPremium = true;
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

        if (remoteName != null) {
          userName = remoteName;
          _saveToLocal('cached_userName', remoteName);
        }

        notifyListeners();
      });
    } catch (e) {
      debugPrint('[UserProfileProvider] Error subscribing to user doc: $e');
      // ignore listen errors — don't crash provider
    }
  }

  /// When setting a name, write to Firestore if signed-in; otherwise fallback to local prefs
  Future<void> setName(String name) async {
    userName = name;
    _saveToLocal('cached_userName', name);
    notifyListeners();

    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) {
      try {
        FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .set({'name': name}, SetOptions(merge: true)).catchError((e) {
          debugPrint(
              '[UserProfileProvider] Error saving name to Firestore: $e');
        });
      } catch (e) {
        debugPrint('[UserProfileProvider] Error saving name: $e');
      }
    }
  }

  /// When setting an image path (local file), save it locally and update UI
  Future<void> setImagePath(String path) async {
    coverImagePath = path;
    _saveToLocal('cached_coverImagePath', path);
    notifyListeners();
  }



  Future<void> clear() async {
    userName = null;
    coverImagePath = null;
    isPremium = true;
    _saveToLocal('cached_userName', null);
    _saveToLocal('cached_coverImagePath', null);
    _saveToLocal('cached_isPremium', true);
    notifyListeners();

    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) {
      try {
        FirebaseFirestore.instance.collection('users').doc(uid).set({
          'name': FieldValue.delete(),
        }, SetOptions(merge: true)).catchError((e) {
          debugPrint(
              '[UserProfileProvider] Error clearing profile in Firestore: $e');
        });
      } catch (e) {
        debugPrint('[UserProfileProvider] Error clearing profile: $e');
      }
    }
  }



  @override
  void dispose() {
    _authSub?.cancel();
    _userDocSub?.cancel();
    _userImageSub?.cancel();
    super.dispose();
  }
}
