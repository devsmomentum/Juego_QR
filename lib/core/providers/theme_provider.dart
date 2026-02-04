import 'package:flutter/material.dart';

class ThemeProvider extends ChangeNotifier {
  bool _isDayMode = true; // La app inicia en modo día

  bool get isDayMode => _isDayMode;
  bool get isNightMode => !_isDayMode;

  void toggleTheme() {
    _isDayMode = !_isDayMode;
    notifyListeners();
  }

  void setDayMode() {
    _isDayMode = true;
    notifyListeners();
  }

  void setNightMode() {
    _isDayMode = false;
    notifyListeners();
  }
}
