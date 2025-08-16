import 'dart:math';
import 'package:cloud_functions/cloud_functions.dart';
import '../models/pack_model.dart';

class CardGachaService {
  final Random _random = Random();


  // Firestoreからカードをランク別にランダム取得 → Cloud Functions へ委譲
  Future<CardResult> getRandomCard(int packRarityLevel) async {
    try {
      // サーバー側で: ランク決定 / カード選択 / 所持付与 / 履歴保存 を実施
      final functions = FirebaseFunctions.instanceFor(region: 'us-central1');
      final res = await functions.httpsCallable('drawGacha').call({
        'packRarityLevel': packRarityLevel,
      });

      final data = Map<String, dynamic>.from(res.data as Map);
      final card = Map<String, dynamic>.from(data['card'] as Map);
      final rarityLevel =
          (data['rarityLevel'] as num?)?.toInt() ??
          _getRarityLevel(card['rank'] as String? ?? 'D');
      final imageIndex =
          (data['imageIndex'] as num?)?.toInt() ?? _random.nextInt(3);

      return CardResult(
        id: (card['id']?.toString() ?? '0'),
        name: card['name'] ?? 'Unknown Card',
        imagePath: 'assets/images/cards/card_${rarityLevel}_$imageIndex.png',
        rarityLevel: rarityLevel,
        description: _generateCardDescription(card),
      );
    } on FirebaseFunctionsException catch (e) {
      print('drawGacha Functions エラー: code=${e.code}, message=${e.message}');
      return _createFallbackCard('C');
    } catch (e) {
      print('カード取得エラー: $e');
      return _createFallbackCard('C');
    }
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