import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:developer'; // ログ出力用
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';

class BattleViewModel {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  String? currentRoomId; // 現在のルームIDを保持
  final FirebaseFunctions _functions = FirebaseFunctions.instanceFor(region: 'us-central1');

  BattleViewModel() {
    // エミュレータ（必要なら）
    const useEmu = bool.fromEnvironment('USE_FIREBASE_EMULATOR', defaultValue: kDebugMode);
    if (useEmu) {
      try { _functions.useFunctionsEmulator('localhost', 5001); } catch (_) {}
    }
  }

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

  // バトル開始処理（Functions: createOrJoinRoom を使用）
  Future<String> handleBattleStart() async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) {
      return 'ログインしてください';
    }

    try {
      // デッキ確認（空デッキは開始不可）
      final userDeck = await fetchUserDeck();
      if (userDeck.isEmpty) {
        return 'デッキが設定されていません';
      }

      final res = await _functions.httpsCallable('createOrJoinRoom').call({});
      final data = Map<String, dynamic>.from(res.data as Map);
      final roomId = data['roomId'] as String?;
      final joinedAs = data['joinedAs'] as String?; // 'player1' | 'player2'
      if (roomId == null) {
        return 'エラーが発生しました: roomId なし';
      }
      currentRoomId = roomId;

      if (joinedAs == 'player2') {
        return 'ルームに参加しました: $roomId';
      } else {
        return '新しいルームを作成しました。対戦相手を待っています...';
      }
    } catch (e) {
      log('Functions エラー(createOrJoinRoom): $e');
      return 'エラーが発生しました: ${e.toString()}';
    }
  }

  // マッチングをキャンセルする（Functions: leaveRoom を使用）
  Future<void> cancelMatching(String roomId) async {
    try {
      await _functions.httpsCallable('leaveRoom').call({'roomId': roomId});
      log('ルーム離脱（キャンセル）: $roomId');
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