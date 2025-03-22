import 'package:flutter/material.dart';

class AppTheme {
  static ThemeData get theme {
    return ThemeData(
      primarySwatch: Colors.deepPurple,
      fontFamily: 'Roboto',
      scaffoldBackgroundColor: Colors.white,
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.deepPurple,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(30),
          ),
        ),
      ),
      colorScheme: ColorScheme.fromSwatch(
        primarySwatch: Colors.deepPurple,
        accentColor: Colors.orangeAccent,
      ),
    );
  }

  // 薄い黄色部分を削除し、純粋な青紫グラデーションに変更
  static Gradient get backgroundGradient {
    return LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        const Color(0xFFE6E9FF), // より薄い青色
        const Color(0xFFE1E1FF), // より薄い紫色
      ],
    );
  }
}
