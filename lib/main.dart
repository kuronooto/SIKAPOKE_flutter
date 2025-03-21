import 'package:flutter/material.dart';
import 'pages/auth_page.dart'; // 追加: auth_page.dart のインポート
import 'pages/root_page.dart';

void main() {
  runApp(const MainApp());
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: RootPage(), // 変更: LoginPage に遷移
    );
  }
}
