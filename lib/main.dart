import 'package:firebase_core/firebase_core.dart'; // 追加: Firebase Core のインポート
import 'package:flutter/material.dart';
import 'package:sikapoke_flutter/firebase_options.dart';
import 'pages/root_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
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
