import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart'; // 追加: Firebase Core のインポート
import 'package:flutter/material.dart';
import 'package:sikapoke_flutter/firebase_options.dart';
import 'pages/root_page.dart';
import 'pages/auth_page.dart'; // 追加: LoginPage のインポート
import 'utils/upload_cards.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (e) {
    debugPrint('Firebase 初期化エラー: $e'); // 初期化エラーをログに出力
  }
  runApp(const MainApp());
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(home: AuthCheck());
  }
}

class AuthCheck extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return FutureBuilder<User?>(
      future: _checkLoginStatus(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Scaffold(body: Center(child: CircularProgressIndicator()));
        } else if (snapshot.hasData) {
          return RootPage();
        } else {
          //return DataUploadPage();
          return LoginPage();
        }
      },
    );
  }

  Future<User?> _checkLoginStatus() async {
    return FirebaseAuth.instance.currentUser;
  }
}
