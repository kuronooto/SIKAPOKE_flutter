import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:sikapoke_flutter/firebase_options.dart';
import 'pages/root_page.dart';
import 'pages/auth_page.dart';
import 'utils/upload_cards.dart';
import 'package:flutter/foundation.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  
  // エミュレーター設定
  const useEmu = bool.fromEnvironment('USE_FIREBASE_EMULATOR', defaultValue: kDebugMode);
  if (useEmu) {
    try {
      FirebaseFirestore.instance.useFirestoreEmulator('localhost', 8080);
      FirebaseFunctions.instance.useFunctionsEmulator('localhost', 5001);
      await FirebaseAuth.instance.useAuthEmulator('localhost', 9099);
    } catch (e) {
      debugPrint('エミュレーター設定エラー: $e');
    }
  }
  
  // 匿名認証を保証（ガチャなどに必要）
  if (FirebaseAuth.instance.currentUser == null) {
    try {
      await FirebaseAuth.instance.signInAnonymously();
      debugPrint('匿名ログイン成功');
    } catch (e) {
      debugPrint('匿名ログイン失敗: $e');
    }
  }
  
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(home: AuthCheck());
  }
}

class AuthCheck extends StatelessWidget {
  // ユーザー初期化（users/{uid} 作成）を保証
  Future<void> _postSignInSetup() async {
    final functions = FirebaseFunctions.instanceFor(region: 'us-central1');
    const useEmu = bool.fromEnvironment('USE_FIREBASE_EMULATOR', defaultValue: kDebugMode);
    if (useEmu) {
      try { functions.useFunctionsEmulator('localhost', 5001); } catch (_) {}
    }
    try {
      await functions.httpsCallable('ensureUserInitialized').call(<String, dynamic>{});
    } catch (e) {
      debugPrint('ensureUserInitialized error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    // 変更: Stream で認証状態を監視し、初期化完了後に RootPage へ
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        //return DataUploadPage();
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        if (snapshot.hasData) {
          return FutureBuilder<void>(
            future: _postSignInSetup(),
            builder: (context, s) {
              if (s.connectionState != ConnectionState.done) {
                return const Scaffold(body: Center(child: CircularProgressIndicator()));
              }
              return RootPage();
            },
          );
        } else {
          return LoginPage();
        }
      },
    );
  }
}