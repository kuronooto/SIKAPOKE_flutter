import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/pack_model.dart';

class CardGachaService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final Random _random = Random();

  // パックレアリティに応じたカードの取得確率を設定
  final Map<int, Map<String, int>> _rarityProbability = {
    1: {'S': 2, 'A': 8, 'B': 20, 'C': 30, 'D': 40}, // ノーマルパック
    2: {'S': 5, 'A': 15, 'B': 30, 'C': 50, 'D': 0}, // レアパック
    3: {'S': 15, 'A': 25, 'B': 60, 'C': 0, 'D': 0}, // スーパーレアパック
    4: {'S': 40, 'A': 60, 'B': 0, 'C': 0, 'D': 0}, // レジェンドパック
  };

  // Firestoreからカードをランク別にランダム取得
  Future<CardResult> getRandomCard(int packRarityLevel) async {
    try {
      // パックのレアリティに基づいてカードのランクを決定
      String cardRank = _determineCardRank(packRarityLevel);

      // 指定したランクのカードを全て取得
      QuerySnapshot cardSnapshot =
          await _firestore
              .collection('cards')
              .where('rank', isEqualTo: cardRank)
              .get();

      if (cardSnapshot.docs.isEmpty) {
        // カードが見つからない場合は代替カードを返す
        return _createFallbackCard(cardRank);
      }

      // ランダムにカードを1枚選択
      int randomIndex = _random.nextInt(cardSnapshot.docs.length);
      DocumentSnapshot cardDoc = cardSnapshot.docs[randomIndex];
      Map<String, dynamic> cardData = cardDoc.data() as Map<String, dynamic>;

      // ユーザーがログインしている場合、カードを所有カードリストに追加
      await _addCardToUserCollection(cardDoc.id);

      // カード結果を生成
      CardResult result = CardResult(
        id: cardDoc.id,
        name: cardData['name'] ?? 'Unknown Card',
        imagePath:
            'assets/images/cards/card_${_getRarityLevel(cardRank)}_${_random.nextInt(3)}.png',
        rarityLevel: _getRarityLevel(cardRank),
        description: _generateCardDescription(cardData),
      );

      return result;
    } catch (e) {
      print('カード取得エラー: $e');
      return _createFallbackCard('C'); // エラー時はフォールバックカード
    }
  }

  // ユーザーの所有カードコレクションにカードを追加
  Future<void> _addCardToUserCollection(String cardId) async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) return;

      // ユーザーの所有カードリファレンス
      final userCardRef = _firestore
          .collection('users')
          .doc(userId)
          .collection('owned_cards')
          .doc(cardId);

      // カードの存在確認
      final cardDoc = await userCardRef.get();

      if (cardDoc.exists) {
        // 既に所持している場合は枚数を増やす
        int currentNumber = (cardDoc.data()?['number'] as num?)?.toInt() ?? 0;
        await userCardRef.update({'number': currentNumber + 1});
      } else {
        // 新規カードの場合
        await userCardRef.set({
          'id': int.parse(cardId), // idを数値として保存
          'number': 1,
        });
      }
    } catch (e) {
      print('カード追加エラー: $e');
    }
  }

  // パックレアリティに基づいてカードランクを確率的に決定
  String _determineCardRank(int packRarityLevel) {
    // パックレアリティが範囲外の場合は標準のノーマルパック確率を使用
    if (!_rarityProbability.containsKey(packRarityLevel)) {
      packRarityLevel = 1;
    }

    Map<String, int> probabilities = _rarityProbability[packRarityLevel]!;
    int totalProbability = probabilities.values.fold(
      0,
      (sum, value) => sum + value,
    );
    int randomValue = _random.nextInt(totalProbability);

    int cumulativeProbability = 0;
    for (var entry in probabilities.entries) {
      cumulativeProbability += entry.value;
      if (randomValue < cumulativeProbability) {
        return entry.key;
      }
    }

    // デフォルトは最も低いランク
    return 'D';
  }

  // ランクからレアリティレベルへの変換
  int _getRarityLevel(String rank) {
    switch (rank) {
      case 'S':
        return 5;
      case 'A':
        return 4;
      case 'B':
        return 3;
      case 'C':
        return 2;
      case 'D':
        return 1;
      default:
        return 1;
    }
  }

  // カード説明の生成
  String _generateCardDescription(Map<String, dynamic> cardData) {
    String type = cardData['type'] ?? '';
    String name = cardData['name'] ?? '';
    int power = cardData['power'] ?? 0;
    String rank = cardData['rank'] ?? '';

    List<String> descriptions = [
      '$nameは$typeの資格で、レアリティ$rankです。',
      'このカードの力は$powerです。有効に活用しましょう。',
      '$rankランクの$typeカード。パワー値$power。',
    ];

    return descriptions[_random.nextInt(descriptions.length)];
  }

  // エラー時やカードが見つからない場合のフォールバックカード
  CardResult _createFallbackCard(String rank) {
    int rarityLevel = _getRarityLevel(rank);
    return CardResult(
      id: 'fallback_${DateTime.now().millisecondsSinceEpoch}',
      name: '${rank}ランクカード',
      imagePath: 'assets/images/cards/card_${rarityLevel}_0.png',
      rarityLevel: rarityLevel,
      description: 'システムによって自動生成されたカードです。',
    );
  }
}
