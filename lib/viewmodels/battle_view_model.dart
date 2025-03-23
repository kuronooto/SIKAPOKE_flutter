import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:developer'; // ログ出力用

class BattleViewModel {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  String? currentRoomId; // 現在のルームIDを保持

  // ユーザーのデッキを取得する
  Future<List<int>> fetchUserDeck() async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) {
      return [];
    }

    try {
      final userDoc = await _firestore.collection('users').doc(userId).get();
      if (userDoc.exists && userDoc.data()!.containsKey('deck')) {
        return List<int>.from(userDoc.data()!['deck']);
      }
    } catch (e) {
      log('デッキ取得エラー: $e');
    }

    return [];
  }

  // バトル開始処理
  Future<String> handleBattleStart() async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) {
      return 'ログインしてください';
    }

    try {
      final roomsRef = _firestore.collection('rooms');

      // シンプルな条件でマッチングを試みる
      final waitingRooms =
          await roomsRef.where('room_status', isEqualTo: 'waiting').get();

      // 自分以外が作ったルームがあるか確認
      final availableRooms =
          waitingRooms.docs
              .where((doc) => doc.data()['player1_id'] != userId)
              .toList();

      if (availableRooms.isNotEmpty) {
        // 待機中のルームがあれば参加
        final room = availableRooms.first;
        currentRoomId = room.id;

        // プレイヤー2としてマッチング
        await roomsRef.doc(room.id).update({
          'player2_id': userId,
          'room_status': 'match',
        });

        return 'ルームに参加しました: ${room.id}';
      } else {
        // 待機中のルームが存在しない場合、新しいルームを作成
        log('待機中のルームがないため、新規作成します');

        // デッキ情報を取得
        final userDeck = await fetchUserDeck();
        if (userDeck.isEmpty) {
          return 'デッキが設定されていません';
        }

        // ゲームの初期状態を設定
        final newRoom = await roomsRef.add({
          'game_state': {
            'turn': 1,
            'player1_point': 0,
            'player2_point': 0,
            'player1_over_mount': 0,
            'player2_over_mount': 0,
            'player1_card': null,
            'player2_card': null,
          },
          'logs': {
            'player1_log': {'type': [], 'power': []},
            'player2_log': {'type': [], 'power': []},
          },
          'room_status': 'waiting',
          'player1_id': userId,
          'player2_id': null,
          'created_at': FieldValue.serverTimestamp(),
        });

        currentRoomId = newRoom.id; // ルームIDを保持
        return '新しいルームを作成しました。対戦相手を待っています...';
      }
    } catch (e) {
      log('Firestore エラー: $e');
      return 'エラーが発生しました: ${e.toString()}';
    }
  }

  // マッチングをキャンセルする
  Future<void> cancelMatching(String roomId) async {
    try {
      final userId = _auth.currentUser?.uid;
      final roomRef = _firestore.collection('rooms').doc(roomId);
      final roomSnapshot = await roomRef.get();

      if (roomSnapshot.exists) {
        final data = roomSnapshot.data();

        // 自分がプレイヤー1の場合は削除、プレイヤー2の場合は退出
        if (data?['player1_id'] == userId && data?['player2_id'] == null) {
          // 自分が作成した待機中のルームの場合は削除
          await roomRef.delete();
          log('ルームを削除しました: $roomId');
        } else if (data?['player2_id'] == userId) {
          // 自分がプレイヤー2の場合は退出
          await roomRef.update({'player2_id': null, 'room_status': 'waiting'});
          log('ルームから退出しました: $roomId');
        }
      }
    } catch (e) {
      log('マッチングキャンセルエラー: $e');
    }
  }

  // マッチングが成立したかどうかを確認
  Future<bool> checkIfMatched(String roomId) async {
    try {
      final roomSnapshot =
          await _firestore.collection('rooms').doc(roomId).get();

      if (roomSnapshot.exists) {
        final data = roomSnapshot.data();
        return data?['room_status'] == 'match' && data?['player2_id'] != null;
      }
      return false;
    } catch (e) {
      log('マッチング確認エラー: $e');
      return false;
    }
  }

  // ルームの情報を取得
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
          'gameState': data?['game_state'],
          'logs': data?['logs'],
        };
      }
    } catch (e) {
      log('ルームデータ取得エラー: $e');
    }
    return null;
  }

  // カード情報を取得
  Future<Map<String, dynamic>?> getCardData(int cardId) async {
    if (cardId <= 0) {
      return null;
    }

    try {
      final cardSnapshot =
          await _firestore
              .collection('cards')
              .where('id', isEqualTo: cardId)
              .limit(1)
              .get();

      if (cardSnapshot.docs.isNotEmpty) {
        return cardSnapshot.docs.first.data();
      }
    } catch (e) {
      log('カードデータ取得エラー: $e');
    }

    return null;
  }
}
