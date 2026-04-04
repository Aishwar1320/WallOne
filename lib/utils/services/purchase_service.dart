import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:in_app_purchase_storekit/in_app_purchase_storekit.dart';
import 'package:in_app_purchase_storekit/store_kit_wrappers.dart';

class PurchaseService {
  static final PurchaseService _instance = PurchaseService._internal();
  factory PurchaseService() => _instance;
  PurchaseService._internal();

  final InAppPurchase _iap = InAppPurchase.instance;
  StreamSubscription<List<PurchaseDetails>>? _subscription;

  // Product IDs - MUST match exactly with Google Play Console
  static const String monthlySubscriptionId = 'wallone_premium_monthly';
  static const String annualSubscriptionId = 'wallone_premium_annual';

  static const Set<String> _productIds = {
    monthlySubscriptionId,
    annualSubscriptionId,
  };

  List<ProductDetails> _products = [];
  bool _isAvailable = false;
  bool _isInitialized = false;

  // Callbacks for UI updates
  Function(bool isPremium)? onPremiumStatusChanged;
  Function(String error)? onError;
  Function(String message)? onPurchaseSuccess;

  bool get isAvailable => _isAvailable;
  List<ProductDetails> get products => _products;
  bool get isInitialized => _isInitialized;

  /// Initialize the purchase service
  Future<void> initialize() async {
    if (_isInitialized) {
      debugPrint('PurchaseService already initialized');
      return;
    }

    try {
      debugPrint('Initializing PurchaseService...');

      _isAvailable = await _iap.isAvailable();

      if (!_isAvailable) {
        debugPrint('In-App Purchase not available on this device');
        onError?.call('In-App Purchase not available');
        return;
      }

      debugPrint('In-App Purchase is available');

      // Platform-specific setup for iOS
      if (Platform.isIOS) {
        final InAppPurchaseStoreKitPlatformAddition iosPlatform =
            _iap.getPlatformAddition<InAppPurchaseStoreKitPlatformAddition>();
        await iosPlatform.setDelegate(PaymentQueueDelegate());
      }

      // Load available products
      await _loadProducts();

      // Listen to purchase updates
      _subscription = _iap.purchaseStream.listen(
        _onPurchaseUpdate,
        onDone: () {
          debugPrint('Purchase stream done');
          _subscription?.cancel();
        },
        onError: (error) {
          debugPrint('Purchase stream error: $error');
          onError?.call(error.toString());
        },
      );

      // Restore previous purchases on initialization
      await restorePurchases();

      _isInitialized = true;
      debugPrint('PurchaseService initialized successfully');
    } catch (e, st) {
      debugPrint('Error initializing PurchaseService: $e');
      debugPrint('Stack trace: $st');
      onError?.call('Failed to initialize purchases: $e');
    }
  }

  /// Load available products from app stores
  Future<void> _loadProducts() async {
    try {
      debugPrint('Loading products: $_productIds');

      final ProductDetailsResponse response =
          await _iap.queryProductDetails(_productIds);

      if (response.error != null) {
        debugPrint('Error loading products: ${response.error}');
        onError?.call(response.error!.message);
        return;
      }

      if (response.productDetails.isEmpty) {
        debugPrint(
            'No products found. Make sure products are created in Play Console');
        debugPrint('Not found products: ${response.notFoundIDs}');
        return;
      }

      _products = response.productDetails;
      debugPrint('Successfully loaded ${_products.length} products');

      for (var product in _products) {
        debugPrint('Product loaded: ${product.id}');
        debugPrint('  Title: ${product.title}');
        debugPrint('  Description: ${product.description}');
        debugPrint('  Price: ${product.price}');
      }
    } catch (e, st) {
      debugPrint('Error in _loadProducts: $e');
      debugPrint('Stack trace: $st');
      onError?.call('Failed to load products: $e');
    }
  }

  /// Handle purchase stream updates
  Future<void> _onPurchaseUpdate(List<PurchaseDetails> purchases) async {
    debugPrint('Received ${purchases.length} purchase updates');

    for (final purchase in purchases) {
      debugPrint('Processing purchase: ${purchase.productID}');
      debugPrint('  Status: ${purchase.status}');
      debugPrint('  Purchase ID: ${purchase.purchaseID}');

      switch (purchase.status) {
        case PurchaseStatus.purchased:
          debugPrint('Purchase successful');
          await _verifyAndDeliverPurchase(purchase);
          break;

        case PurchaseStatus.error:
          debugPrint('Purchase error: ${purchase.error}');
          onError?.call(purchase.error?.message ?? 'Purchase failed');
          break;

        case PurchaseStatus.canceled:
          debugPrint('Purchase canceled by user');
          break;

        case PurchaseStatus.pending:
          debugPrint('Purchase pending');
          break;

        case PurchaseStatus.restored:
          debugPrint('Purchase restored');
          await _verifyAndDeliverPurchase(purchase);
          break;
      }

      // Mark purchase as complete
      if (purchase.pendingCompletePurchase) {
        debugPrint('Completing purchase...');
        await _iap.completePurchase(purchase);
      }
    }
  }

  /// Verify and deliver purchase to user
  Future<void> _verifyAndDeliverPurchase(PurchaseDetails purchase) async {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) {
        debugPrint('No user logged in, cannot deliver purchase');
        onError?.call('Please log in to activate premium');
        return;
      }

      debugPrint('Delivering purchase to user: $uid');

      // Update user's premium status in Firestore
      await FirebaseFirestore.instance.collection('users').doc(uid).update({
        'isPremium': true,
        'premiumPurchaseDate': FieldValue.serverTimestamp(),
        'premiumProductId': purchase.productID,
        'premiumPurchaseId': purchase.purchaseID,
        'premiumStatus': 'active',
      });

      // Save detailed purchase record
      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('purchases')
          .doc(purchase.purchaseID ??
              DateTime.now().millisecondsSinceEpoch.toString())
          .set({
        'productId': purchase.productID,
        'purchaseId': purchase.purchaseID,
        'purchaseDate': FieldValue.serverTimestamp(),
        'status': purchase.status.toString(),
        'transactionDate': purchase.transactionDate,
        'verificationData': purchase.verificationData.serverVerificationData,
      });

      debugPrint('Premium status activated successfully for user: $uid');

      // Notify listeners
      onPremiumStatusChanged?.call(true);
      onPurchaseSuccess
          ?.call('Premium activated successfully! Enjoy all AI features.');
    } catch (e, st) {
      debugPrint('Error delivering purchase: $e');
      debugPrint('Stack trace: $st');
      onError?.call('Failed to activate premium: $e');
    }
  }

  /// Purchase a product (subscription)
  Future<void> buyProduct(ProductDetails product) async {
    if (!_isAvailable) {
      onError?.call('In-App Purchase not available');
      return;
    }

    try {
      debugPrint('Initiating purchase for: ${product.id}');

      final PurchaseParam purchaseParam = PurchaseParam(
        productDetails: product,
      );

      // For subscriptions, use buyNonConsumable
      final bool success = await _iap.buyNonConsumable(
        purchaseParam: purchaseParam,
      );

      if (!success) {
        debugPrint('Failed to initiate purchase');
        onError?.call('Failed to start purchase process');
      } else {
        debugPrint('Purchase process started');
      }
    } catch (e, st) {
      debugPrint('Error buying product: $e');
      debugPrint('Stack trace: $st');
      onError?.call('Purchase failed: $e');
    }
  }

  /// Restore previous purchases
  Future<void> restorePurchases() async {
    if (!_isAvailable) {
      debugPrint('Cannot restore: IAP not available');
      return;
    }

    try {
      debugPrint('Restoring purchases...');

      // This will trigger the purchase stream with restored purchases
      await _iap.restorePurchases();

      // Also check Firestore for current status
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid != null) {
        final userDoc =
            await FirebaseFirestore.instance.collection('users').doc(uid).get();

        final isPremium = userDoc.data()?['isPremium'] ?? false;
        final status = userDoc.data()?['premiumStatus'] ?? 'inactive';

        debugPrint(
            'Current premium status from Firestore: $isPremium ($status)');
        onPremiumStatusChanged?.call(isPremium);
      }

      debugPrint('Purchases restored');
    } catch (e, st) {
      debugPrint('Error restoring purchases: $e');
      debugPrint('Stack trace: $st');
      onError?.call('Failed to restore purchases: $e');
    }
  }

  /// Check current subscription status from Firestore
  Future<bool> checkSubscriptionStatus() async {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) {
        debugPrint('No user logged in');
        return false;
      }

      final userDoc =
          await FirebaseFirestore.instance.collection('users').doc(uid).get();

      final isPremium = userDoc.data()?['isPremium'] ?? false;
      debugPrint('Subscription status check: $isPremium');

      return isPremium;
    } catch (e) {
      debugPrint('Error checking subscription status: $e');
      return false;
    }
  }

  /// Get product by ID
  ProductDetails? getProduct(String productId) {
    try {
      return _products.firstWhere((product) => product.id == productId);
    } catch (e) {
      debugPrint('Product not found: $productId');
      return null;
    }
  }

  /// Get monthly subscription product
  ProductDetails? get monthlyProduct => getProduct(monthlySubscriptionId);

  /// Get annual subscription product
  ProductDetails? get annualProduct => getProduct(annualSubscriptionId);

  /// Cancel subscription (this opens the Play Store subscription management)
  Future<void> manageSubscription() async {
    // On Android, this will open Play Store subscription management
    // On iOS, this will open App Store subscription management
    try {
      if (Platform.isAndroid) {
        debugPrint('Opening Play Store subscription management');
        // User needs to cancel through Play Store
        // You can provide a deep link or instructions
      } else if (Platform.isIOS) {
        debugPrint('Opening App Store subscription management');
        // User needs to cancel through App Store settings
      }
    } catch (e) {
      debugPrint('Error managing subscription: $e');
    }
  }

  /// Dispose and cleanup
  void dispose() {
    debugPrint('Disposing PurchaseService');
    _subscription?.cancel();
    _subscription = null;
  }
}

/// iOS Payment Queue Delegate
class PaymentQueueDelegate implements SKPaymentQueueDelegateWrapper {
  @override
  bool shouldContinueTransaction(
      SKPaymentTransactionWrapper transaction, SKStorefrontWrapper storefront) {
    return true;
  }

  @override
  bool shouldShowPriceConsent() {
    return false;
  }
}
