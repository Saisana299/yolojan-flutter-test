import 'package:flutter/material.dart';

ThemeData appTheme() {
  return ThemeData(
    colorSchemeSeed: Colors.blue,
    useMaterial3: true,
    scaffoldBackgroundColor: const Color.fromARGB(255, 245, 245, 245),
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.white,
      shape: Border(
        bottom: BorderSide(
          color: Color.fromARGB(255, 222, 222, 222),
          width: 1.0,
        ),
      ),
    ),
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: Colors.white,
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.white,
      ),
    ),
  );
}