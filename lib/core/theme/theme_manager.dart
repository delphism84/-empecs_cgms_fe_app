import 'package:flutter/material.dart';

class ThemeManager with ChangeNotifier{

//thememode instance:

ThemeMode _themeMode = ThemeMode.light;
ThemeMode get themeMode => _themeMode;


// method to get the value of the dark mode switch botton:
void toggleTheme(bool isDark ){
  _themeMode = isDark?ThemeMode.dark:ThemeMode.light;
  notifyListeners();


}

// allow setting any ThemeMode, including system


}

// global instance for easy access across app
// 일부 화면에서 직접 접근하는 코드를 위해 단일 인스턴스를 노출
final ThemeManager themeManager = ThemeManager();