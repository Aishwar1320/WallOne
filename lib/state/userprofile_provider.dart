import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:path_provider/path_provider.dart';
import 'package:wallone/utils/services/purchase_service.dart';

class UserProfileProvider extends ChangeNotifier {
  String? userName;
  String? coverImagePath; // local file path for display
  bool isPremium = false;

  StreamSubscription<User?>? _authSub;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _userDocSub;

  // Purchase service instance
  final PurchaseService _purchaseService = PurchaseService();

  // 🔧 DEVELOPMENT MODE - Set to false when publishing to Play Store
  static const bool _isDevelopmentMode =
      kDebugMode; // Automatically true in debug builds

  UserProfileProvider() {
    _init();
  }

  Future<void> _init() async {
    // Only initialize purchase service if NOT in development mode
    if (!_isDevelopmentMode) {
      await _initializePurchases();
    } else {
      if (kDebugMode) {
        debugPrint('═══════════════════════════════════════════════════');
        debugPrint('🔧 DEVELOPMENT MODE: In-App Purchases DISABLED');
        debugPrint('   Manual premium toggle available for testing');
        debugPrint('   Change _isDevelopmentMode to false for production');
        debugPrint('═══════════════════════════════════════════════════');
      }
    }

    // Listen to auth state so we can subscribe/unsubscribe to user's doc
    _authSub = FirebaseAuth.instance.authStateChanges().listen((user) async {
      // cancel previous firestore listener
      await _userDocSub?.cancel();
      _userDocSub = null;

      if (user == null) {
        // logged out — clear profile in memory
        userName = null;
        coverImagePath = null;
        isPremium = false;
        notifyListeners();
      } else {
        // signed in — subscribe to their firestore doc for realtime updates
        _subscribeToFirestoreUser(user.uid);

        // Check and restore purchases for logged-in user (only in production)
        if (!_isDevelopmentMode) {
          await _purchaseService.restorePurchases();
        }
      }
    });
  }

  /// Initialize purchase service with callbacks
  Future<void> _initializePurchases() async {
    try {
      debugPrint('[UserProfileProvider] Initializing purchase service...');

      // Setup callbacks
      _purchaseService.onPremiumStatusChanged = (isPremiumStatus) {
        debugPrint(
            '[UserProfileProvider] Premium status changed: $isPremiumStatus');
        isPremium = isPremiumStatus;
        notifyListeners();
      };

      _purchaseService.onError = (error) {
        debugPrint('[UserProfileProvider] Purchase error: $error');
        // You can show a snackbar or error message here if needed
      };

      _purchaseService.onPurchaseSuccess = (message) {
        debugPrint('[UserProfileProvider] Purchase success: $message');
        // You can show a success message here if needed
      };

      // Initialize the service
      await _purchaseService.initialize();

      // Check current subscription status
      final currentStatus = await _purchaseService.checkSubscriptionStatus();
      if (currentStatus != isPremium) {
        isPremium = currentStatus;
        notifyListeners();
      }

      debugPrint(
          '[UserProfileProvider] Purchase service initialized. Premium: $isPremium');
    } catch (e, st) {
      debugPrint('[UserProfileProvider] Error initializing purchases: $e');
      debugPrint('Stack trace: $st');
    }
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

        // Update premium status from Firestore
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
    notifyListeners();

    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) {
      try {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .set({'name': name}, SetOptions(merge: true));
      } catch (e) {
        debugPrint('[UserProfileProvider] Error saving name: $e');
      }
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
      } catch (e) {
        debugPrint('[UserProfileProvider] Error saving image: $e');
      }
    }
  }

  /// Set premium status for the current user. Persists to Firestore when signed in.
  ///
  /// 🔧 DEVELOPMENT NOTE: In development mode, this allows manual toggling
  /// In production, this should only be called by the purchase service
  Future<void> setPremium(bool value) async {
    if (_isDevelopmentMode) {
      // Allow manual toggle in development
      if (kDebugMode) {
        debugPrint(
            '[UserProfileProvider] 🔧 DEV MODE: Manually setting premium to $value');
      }
    }

    isPremium = value;
    notifyListeners();

    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) {
      try {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .set({'isPremium': value}, SetOptions(merge: true));
      } catch (e) {
        debugPrint('[UserProfileProvider] Error saving premium status: $e');
      }
    }
  }

  /// Purchase a subscription product
  /// 🔧 In development mode, this simulates a purchase
  Future<void> purchasePremium(String productId) async {
    if (_isDevelopmentMode) {
      // Simulate purchase in development mode
      if (kDebugMode) {
        debugPrint(
            '[UserProfileProvider] 🔧 DEV MODE: Simulating purchase of $productId');
      }
      await setPremium(true);
      return;
    }

    // Real purchase in production
    try {
      debugPrint('[UserProfileProvider] Purchasing product: $productId');

      final product = _purchaseService.getProduct(productId);
      if (product != null) {
        await _purchaseService.buyProduct(product);
      } else {
        debugPrint('[UserProfileProvider] Product not found: $productId');
      }
    } catch (e, st) {
      debugPrint('[UserProfileProvider] Error purchasing premium: $e');
      debugPrint('Stack trace: $st');
    }
  }

  /// Restore previous purchases
  /// 🔧 In development mode, this checks Firestore only
  Future<void> restorePurchases() async {
    if (_isDevelopmentMode) {
      if (kDebugMode) {
        debugPrint(
            '[UserProfileProvider] 🔧 DEV MODE: Checking Firestore for premium status');
      }
      // Just check current Firestore status
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid != null) {
        try {
          final doc = await FirebaseFirestore.instance
              .collection('users')
              .doc(uid)
              .get();
          final firestorePremium = doc.data()?['isPremium'] ?? false;
          if (firestorePremium != isPremium) {
            isPremium = firestorePremium;
            notifyListeners();
          }
        } catch (e) {
          debugPrint('[UserProfileProvider] Error checking Firestore: $e');
        }
      }
      return;
    }

    // Real restore in production
    try {
      debugPrint('[UserProfileProvider] Restoring purchases...');
      await _purchaseService.restorePurchases();
    } catch (e, st) {
      debugPrint('[UserProfileProvider] Error restoring purchases: $e');
      debugPrint('Stack trace: $st');
    }
  }

  /// Get available purchase products
  /// 🔧 In development mode, returns empty list
  List<dynamic> get availableProducts {
    if (_isDevelopmentMode) {
      return []; // Return empty in dev mode
    }
    return _purchaseService.products;
  }

  /// Check if purchase service is initialized
  /// 🔧 In development mode, always returns true
  bool get isPurchaseServiceInitialized {
    if (_isDevelopmentMode) {
      return true; // Always ready in dev mode
    }
    return _purchaseService.isInitialized;
  }

  /// Get purchase service instance (for direct access if needed)
  PurchaseService get purchaseService => _purchaseService;

  /// 🔧 DEVELOPMENT HELPER: Check if in development mode
  bool get isInDevelopmentMode => _isDevelopmentMode;

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
      } catch (e) {
        debugPrint('[UserProfileProvider] Error clearing profile: $e');
      }
    }
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
      debugPrint('[UserProfileProvider] Error saving image file: $e');
      return null;
    }
  }

  @override
  void dispose() {
    _authSub?.cancel();
    _userDocSub?.cancel();
    if (!_isDevelopmentMode) {
      _purchaseService.dispose();
    }
    super.dispose();
  }
}
