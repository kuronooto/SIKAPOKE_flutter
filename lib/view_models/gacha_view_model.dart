import 'dart:math';
import 'package:flutter/material.dart';
import '../models/pack_model.dart';

class GachaViewModel extends ChangeNotifier {
  final List<PackModel> packs = [
    PackModel(
      id: 'normal',
      name: 'ノーマルパック',
      color: Colors.deepPurple.shade300,
      imagePath: 'assets/images/packs/normal_pack.png',
      rarityLevel: 1,
    ),
    PackModel(
      id: 'rare',
      name: 'レアパック',
      color: Colors.deepPurple.shade400,
      imagePath: 'assets/images/packs/rare_pack.png',
      rarityLevel: 2,
    ),
    PackModel(
      id: 'super_rare',
      name: '最強の遺伝子',
      color: Colors.deepPurple.shade500,
      imagePath: 'assets/images/packs/super_rare_pack.png',
      rarityLevel: 3,
    ),
    PackModel(
      id: 'legend',
      name: 'レジェンドパック',
      color: Colors.deepPurple.shade600,
      imagePath: 'assets/images/packs/legend_pack.png',
      rarityLevel: 4,
    ),
    // 追加パック
    PackModel(
      id: 'limited',
      name: 'リミテッドパック',
      color: Colors.deepPurple.shade700,
      imagePath: 'assets/images/packs/limited_pack.png',
      rarityLevel: 4,
    ),
    PackModel(
      id: 'anniversary',
      name: '記念パック',
      color: Colors.purple.shade400,
      imagePath: 'assets/images/packs/anniversary_pack.png',
      rarityLevel: 3,
    ),
    PackModel(
      id: 'special',
      name: 'スペシャルパック',
      color: Colors.indigo.shade400,
      imagePath: 'assets/images/packs/special_pack.png',
      rarityLevel: 3,
    ),
    PackModel(
      id: 'premium',
      name: 'プレミアムパック',
      color: Colors.deepPurple.shade800,
      imagePath: 'assets/images/packs/premium_pack.png',
      rarityLevel: 4,
    ),
  ];

  int _selectedPackIndex = 0;
  bool _isSelecting = false;
  bool _isOpening = false;
  CardResult? _result;

  int get selectedPackIndex => _selectedPackIndex;
  bool get isSelecting => _isSelecting;
  bool get isOpening => _isOpening;
  CardResult? get result => _result;
  bool get hasSelectedPack => _selectedPackIndex != -1;

  void startPackSelection() {
    if (_isSelecting || _isOpening) return;

    _isSelecting = true;
    // ランダムなパックを選択
    _selectedPackIndex = Random().nextInt(packs.length);
    notifyListeners();
  }

  void selectPack(int index) {
    if (_isSelecting || _isOpening) return;

    _selectedPackIndex = index;
    notifyListeners();
  }

  void openSelectedPack() {
    if (_isOpening || _selectedPackIndex == -1) return;

    _isOpening = true;
    notifyListeners();

    // 実際のアプリではここで API 呼び出しなどを行い結果を取得
    _generateResult();
  }

  void resetSelection() {
    _selectedPackIndex = -1;
    _isSelecting = false;
    _isOpening = false;
    _result = null;
    notifyListeners();
  }

  void completeSelection() {
    _isSelecting = false;
    notifyListeners();
  }

  void completeOpening() {
    _isOpening = false;
    notifyListeners();
  }

  // ガチャ結果の生成（実際のアプリではサーバーから取得するかも）
  void _generateResult() {
    final selectedPack = packs[_selectedPackIndex];

    // パックに応じた確率でレア度を決定
    final baseRarity = selectedPack.rarityLevel;
    final random = Random();
    int resultRarity;

    // レア度による確率計算
    final chance = random.nextDouble();

    // パックの種類によって確率を変える
    switch (baseRarity) {
      case 1: // ノーマルパック
        if (chance > 0.98) {
          resultRarity = 5; // 2% で最高レア
        } else if (chance > 0.90) {
          resultRarity = 4; // 8% で超レア
        } else if (chance > 0.70) {
          resultRarity = 3; // 20% で上レア
        } else if (chance > 0.40) {
          resultRarity = 2; // 30% で中レア
        } else {
          resultRarity = 1; // 40% で通常レア
        }
        break;

      case 2: // レアパック
        if (chance > 0.95) {
          resultRarity = 5; // 5% で最高レア
        } else if (chance > 0.80) {
          resultRarity = 4; // 15% で超レア
        } else if (chance > 0.50) {
          resultRarity = 3; // 30% で上レア
        } else {
          resultRarity = 2; // 50% で中レア
        }
        break;

      case 3: // スーパーレアパック
        if (chance > 0.85) {
          resultRarity = 5; // 15% で最高レア
        } else if (chance > 0.60) {
          resultRarity = 4; // 25% で超レア
        } else {
          resultRarity = 3; // 60% で上レア
        }
        break;

      case 4: // レジェンドパック
        if (chance > 0.60) {
          resultRarity = 5; // 40% で最高レア
        } else {
          resultRarity = 4; // 60% で超レア
        }
        break;

      default:
        resultRarity = baseRarity;
    }

    // 名前バリエーションの追加
    final nameVariation = random.nextInt(3); // 同じレア度でも複数の名前バリエーション

    _result = CardResult(
      id: 'card_${DateTime.now().millisecondsSinceEpoch}',
      name: _getCardName(resultRarity, nameVariation),
      imagePath: _getCardImagePath(resultRarity, nameVariation),
      rarityLevel: resultRarity,
      description: _getCardDescription(resultRarity, nameVariation),
    );
  }

  String _getCardName(int rarity, int variation) {
    // レア度ごとの名前バリエーション
    final namesByRarity = [
      // レア度1（ノーマル）
      ['ノーマルキャラA', 'ノーマルキャラB', 'ノーマルキャラC'],
      // レア度2（レア）
      ['レアキャラA', 'レアキャラB', 'レアキャラC'],
      // レア度3（スーパーレア）
      ['スーパーレアキャラA', 'スーパーレアキャラB', 'スーパーレアキャラC'],
      // レア度4（ウルトラレア）
      ['ウルトラレアキャラA', 'ウルトラレアキャラB', 'ウルトラレアキャラC'],
      // レア度5（レジェンド）
      ['レジェンドキャラA', 'レジェンドキャラB', 'レジェンドキャラC'],
    ];

    final normalizedRarity = min(rarity - 1, namesByRarity.length - 1);
    final normalizedVariation = min(
      variation,
      namesByRarity[normalizedRarity].length - 1,
    );

    return namesByRarity[normalizedRarity][normalizedVariation];
  }

  String _getCardImagePath(int rarity, int variation) {
    // 実際にはバリエーションごとに異なる画像パスを返す
    return 'assets/images/cards/card_${rarity}_$variation.png';
  }

  String _getCardDescription(int rarity, int variation) {
    // レア度や種類ごとに異なる説明文
    final descriptions = [
      // レア度1
      [
        '一番よく見かけるキャラクターです。',
        'どこにでもいるキャラクターですが、愛嬌があります。',
        '珍しくはありませんが、大事に育ててあげてください。',
      ],
      // レア度2
      [
        'やや珍しいキャラクターです。特殊な技を持っています。',
        '都会で見かけることが多いキャラクターです。',
        '少し変わった性格のキャラクターです。',
      ],
      // レア度3
      [
        '特殊な能力を持つレアなキャラクターです！',
        '様々なバトルで活躍する強力なキャラクターです！',
        '珍しい姿をしたスーパーレアキャラクターです！',
      ],
      // レア度4
      [
        '伝説級の強さを持つキャラクターです！',
        '非常に珍しい特別なキャラクターです！',
        'あなたはラッキー！めったに出会えない強力なキャラクターです！',
      ],
      // レア度5
      [
        '神話に登場する伝説の存在です！大事にしてください！',
        '何千年に一度出会えるかどうかの超激レアキャラクターです！',
        'おめでとうございます！最高レアリティのキャラクターをゲットしました！',
      ],
    ];

    final normalizedRarity = min(rarity - 1, descriptions.length - 1);
    final normalizedVariation = min(
      variation,
      descriptions[normalizedRarity].length - 1,
    );

    return descriptions[normalizedRarity][normalizedVariation];
  }
}
