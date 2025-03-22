import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:developer'; // ログ出力用

class BattleViewModel {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  String? currentRoomId; // 現在のルームIDを保持

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
        currentRoomId = room.id; // ルームIDを保持
        await roomsRef.doc(room.id).update({
          'player2_id': userId,
          'room_status': 'match',
        });
        return 'ルームに参加しました: ${room.id}';
      } else {
        // 待機中のルームが存在しない場合、新しいルームを作成
        final newRoom = await roomsRef.add({
          'game_state': {
            'turn': 1,
            'player1_point': 0,
            'player2_point': 0,
            'player1_over_mount': 0, // 修正: 配列から整数型に変更
            'player2_over_mount': 0, // 修正: 配列から整数型に変更
          },
          'logs': {
            'player1_log': {'type': [], 'power': []},
            'player2_log': {'type': [], 'power': []},
          },
          'room_status': 'waiting',
          'player1_id': userId,
          'player2_id': null,
          'created_at':
              FieldValue.serverTimestamp(), // Firestore サーバータイムスタンプを設定
        });
        currentRoomId = newRoom.id; // ルームIDを保持
        return '新しいルームを作成しました: ${newRoom.id}';
      }
    } catch (e) {
      log('Firestore エラー: $e'); // エラーをログに出力
      return 'エラー: ${e.toString()}';
    }
  }

  Future<void> cancelMatching(String roomId) async {
    try {
      await _firestore.collection('rooms').doc(roomId).delete();
      log('ルームを削除しました: $roomId');
    } catch (e) {
      log('ルーム削除エラー: $e');
    }
  }

  Future<bool> checkIfMatched(String roomId) async {
    try {
      final roomSnapshot =
          await _firestore.collection('rooms').doc(roomId).get();
      if (roomSnapshot.exists) {
        final data = roomSnapshot.data();
        return data?['player2_id'] != null; // player2_id が設定されているか確認
      }
      return false;
    } catch (e) {
      log('マッチング確認エラー: $e');
      return false;
    }
  }

  Future<Map<String, dynamic>?> getRoomData(String roomId) async {
    try {
      final roomSnapshot =
          await _firestore.collection('rooms').doc(roomId).get();
      if (roomSnapshot.exists) {
        final data = roomSnapshot.data();
        return {
          'roomId': roomId,
          'player1Id': data?['player1_id'],
          'player2Id': data?['player2_id'],
          'gameState': data?['game_state'], // game_state を取得
        };
      }
    } catch (e) {
      log('ルームデータ取得エラー: $e');
    }
    return null;
  }
}
