import 'package:flutter/material.dart'; // Flutterアプリとして実行
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  final testFirestore = FirebaseFirestore.instance;

  // ✅ 1. データ作成 (Create)
  DocumentReference docRef = await testFirestore.collection('test_collection').add({
    'name': 'テストユーザー',
    'age': 25,
    'created_at': FieldValue.serverTimestamp(),
  });
  print('✅ 作成完了: ${docRef.id}');

  // ✅ 2. データ取得 (Read)
  DocumentSnapshot doc = await docRef.get();
  if (doc.exists) {
    print('✅ 取得データ: ${doc.data()}');
  }

  // ✅ 3. データ更新 (Update)
  await docRef.update({'age': 30});
  print('✅ 更新完了: 年齢を30に変更');

}
