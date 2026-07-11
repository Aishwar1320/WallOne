import 'package:flutter/foundation.dart';

class PurchaseService {
  static final PurchaseService _instance = PurchaseService._internal();
  factory PurchaseService() => _instance;
  PurchaseService._internal();

  bool get isAvailable => false;

  Future<void> initialize() async {
    debugPrint('PurchaseService (stub) initialized');
  }

  Future<void> dispose() async {}
}
