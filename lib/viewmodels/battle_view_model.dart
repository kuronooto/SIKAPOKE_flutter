import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:developer'; // ログ出力用

class BattleViewModel {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Future<String> handleBattleStart() async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) {
      return 'ログインしてください';
    }

    try {
      final roomsRef = _firestore.collection('rooms');
      final waitingRoom =
          await roomsRef
              .where('room_status', isEqualTo: 'waiting')
              .limit(1)
              .get();

      if (waitingRoom.docs.isNotEmpty) {
        // 待機中のルームが存在する場合、player2_id を設定
        final room = waitingRoom.docs.first;
        await roomsRef.doc(room.id).update({
          'player2_id': userId,
          'room_status': 'match',
        });
        return 'ルームに参加しました: ${room.id}';
      } else {
        // 待機中のルームが存在しない場合、新しいルームを作成
        final newRoom = await roomsRef.add({
          'game_state': {},
          'logs': [],
          'room_status': 'waiting',
          'player1_id': userId,
          'player2_id': null,
          'created_at':
              FieldValue.serverTimestamp(), // Firestore サーバータイムスタンプを設定
        });
        return '新しいルームを作成しました: ${newRoom.id}';
      }
    } catch (e) {
      log('Firestore エラー: $e'); // エラーをログに出力
      return 'エラー: ${e.toString()}';
    }
  }
}
