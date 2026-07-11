import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';
import 'package:wallone/core/models/icon_map_model.dart';

/// Category model using icon name instead of IconData
class Category {
  final String name;
  final String iconName;

  Category({
    required this.name,
    required this.iconName,
  });

  IconData get icon => iconMap[iconName] ?? Icons.category;

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'iconName': iconName,
    };
  }

  factory Category.fromJson(Map<String, dynamic> json) {
    return Category(
      name: json['name'],
      iconName: json['iconName'],
    );
  }
}

class CategoryProvider with ChangeNotifier {
  List<Category> _categories = [];
  StreamSubscription<User?>? _authSub;

  CategoryProvider() {
    // Subscribe to auth state so categories reload whenever the user
    // signs in (including after a cold start where the sign-in may
    // happen after this provider is constructed).
    _authSub = FirebaseAuth.instance.authStateChanges().listen((user) {
      if (user != null) {
        _loadCategories();
      } else {
        _loadDefaultCategories();
        notifyListeners();
      }
    });
  }

  @override
  void dispose() {
    _authSub?.cancel();
    super.dispose();
  }

  Future<void> _loadCategories() async {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) {
        _loadDefaultCategories();
        notifyListeners();
        return;
      }

      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('settings')
          .doc('categories')
          .get();

      if (doc.exists && doc.data() != null) {
        final List<dynamic>? categoriesData =
            doc.data()?['categories'] as List<dynamic>?;
        if (categoriesData != null) {
          _categories = categoriesData
              .map((item) => Category.fromJson(item as Map<String, dynamic>))
              .toList();
        }
      } else {
        _loadDefaultCategories();
      }
    } catch (e) {
      debugPrint('Error loading categories: $e');
      _loadDefaultCategories();
    }

    notifyListeners();
  }

  void _loadDefaultCategories() {
    _categories = [
      Category(name: "Food", iconName: 'fastfood'),
      Category(name: "Shopping", iconName: 'shopping_bag'),
      Category(name: "Bills", iconName: 'receipt'),
      Category(name: "Groceries", iconName: 'local_grocery_store'),
      Category(name: "Games", iconName: 'sports_esports'),
      Category(name: "Friends", iconName: 'people'),
      Category(name: "Family", iconName: 'home'),
      Category(name: "Education", iconName: 'school'),
      Category(name: "Salary", iconName: 'attach_money'),
    ];
    _saveCategories();
  }

  List<Category> get categories => _categories;

  Future<void> _saveCategories() async {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) {
        debugPrint('No user logged in, skipping category save');
        return;
      }

      final categoriesData = _categories.map((c) => c.toJson()).toList();

      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('settings')
          .doc('categories')
          .set({'categories': categoriesData}, SetOptions(merge: true));

      notifyListeners();
    } catch (e) {
      debugPrint('Error saving categories: $e');
    }
  }

  Future<void> addCategory(String name, String iconName) async {
    if (!_categories.any((c) => c.name.toLowerCase() == name.toLowerCase())) {
      _categories.add(Category(
        name: name,
        iconName: iconName,
      ));
      await _saveCategories();
    }
  }

  Future<void> removeCategory(String name) async {
    _categories.removeWhere((c) => c.name == name);
    await _saveCategories();
  }

  Future<void> updateCategory(
      String oldName, String newName, String iconName) async {
    final index = _categories.indexWhere((c) => c.name == oldName);
    if (index != -1) {
      _categories[index] = Category(
        name: newName,
        iconName: iconName,
      );
      await _saveCategories();
    }
  }

  String getIconForCategory(String categoryName) {
    final category = _categories.firstWhere(
      (c) => c.name.toLowerCase() == categoryName.toLowerCase(),
      orElse: () => Category(
        name: "Default",
        iconName: 'category',
      ),
    );
    return category.iconName;
  }

}
