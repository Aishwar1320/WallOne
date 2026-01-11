import 'package:flutter/material.dart';

class KeypadInputProvider with ChangeNotifier {
  String _input = "";

  String get input => _input;

  void updateInput(String value) {
    if (_input != value) {
      _input = value;
      notifyListeners();
    }
  }

  void clearInput() {
    if (_input.isNotEmpty) {
      _input = "";
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _input = "";
    super.dispose();
  }
}
