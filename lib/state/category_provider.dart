import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

import 'package:wallone/state/budget_provider.dart';

/// Mapping of icon names to constant IconData
// const Map<String, IconData> _iconMap = {
//   'fastfood': Icons.fastfood,
//   'shopping_bag': Icons.shopping_bag,
//   'receipt': Icons.receipt,
//   'local_grocery_store': Icons.local_grocery_store,
//   'sports_esports': Icons.sports_esports,
//   'people': Icons.people,
//   'home': Icons.home,
//   'school': Icons.school,
//   'attach_money': Icons.attach_money,
//   'category': Icons.category, // fallback
// };

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
  final SharedPreferences _prefs;
  static const String _categoriesKey = 'categories';

  CategoryProvider(this._prefs) {
    _loadCategories();
    if (_categories.isEmpty) {
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
  }

  List<Category> get categories => _categories;

  Future<void> _loadCategories() async {
    final String? categoriesJson = _prefs.getString(_categoriesKey);
    if (categoriesJson != null) {
      final List<dynamic> decoded = jsonDecode(categoriesJson);
      _categories = decoded.map((item) => Category.fromJson(item)).toList();
      notifyListeners();
    }
  }

  Future<void> _saveCategories() async {
    final String encoded =
        jsonEncode(_categories.map((c) => c.toJson()).toList());
    await _prefs.setString(_categoriesKey, encoded);
    notifyListeners();
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
