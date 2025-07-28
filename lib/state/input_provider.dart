import 'package:flutter/material.dart';

class KeypadInputProvider with ChangeNotifier {
  String _input = "";

  String get input => _input;

  void updateInput(String value) {
    _input = value;
    notifyListeners();
  }

  void clearInput() {
    _input = "";
    notifyListeners();
  }
}
