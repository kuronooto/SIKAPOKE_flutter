import 'package:cloud_firestore/cloud_firestore.dart';

class CardModel {
  final int id;
  final String name;
  final String type;
  final int power;
  final String? description;
  final String? imageUrl;

  CardModel({
    required this.id,
    required this.name,
    required this.type,
    required this.power,
    this.description,
    this.imageUrl,
  });

  factory CardModel.fromFirestore(String id, Map<String, dynamic> data) {
    return CardModel(
      id: int.parse(id),
      name: data['name'] as String? ?? '名称未設定カード',
      type: data['type'] as String? ?? '不明',
      power: data['power'] as int? ?? 0,
      description: data['description'] as String?,
      imageUrl: data['image_url'] as String?,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'type': type,
      'power': power,
      'description': description,
      'image_url': imageUrl,
    };
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'type': type,
      'power': power,
      'description': description,
      'image': imageUrl,
    };
  }
}

class CardRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // カードデータを取得
  Future<CardModel?> getCard(int cardId) async {
    try {
      final cardRef = _firestore.collection('cards').doc(cardId.toString());
      final cardSnapshot = await cardRef.get();

      if (cardSnapshot.exists) {
        return CardModel.fromFirestore(
          cardId.toString(),
          cardSnapshot.data() ?? {},
        );
      }
      return null;
    } catch (e) {
      print('カード取得エラー: $e');
      return null;
    }
  }

  // 複数のカードデータを一度に取得
  Future<List<CardModel>> getCards(List<int> cardIds) async {
    try {
      List<CardModel> cards = [];

      // カードIDごとにデータを取得
      for (final cardId in cardIds) {
        final card = await getCard(cardId);
        if (card != null) {
          cards.add(card);
        }
      }

      return cards;
    } catch (e) {
      print('複数カード取得エラー: $e');
      return [];
    }
  }

  // 初期テストカードデータを作成
  Future<void> createInitialCards() async {
    try {
      // ITカード
      await _firestore.collection('cards').doc('0').set({
        'name': 'プログラミング入門',
        'type': 'IT',
        'power': 10,
        'description': 'プログラミングの基礎を学ぶ',
      });

      await _firestore.collection('cards').doc('1').set({
        'name': 'アプリ開発',
        'type': 'IT',
        'power': 20,
        'description': 'モバイルアプリケーションの開発',
      });

      // 語学カード
      await _firestore.collection('cards').doc('2').set({
        'name': '英会話初級',
        'type': '語学',
        'power': 15,
        'description': '基本的な英会話フレーズを習得',
      });

      await _firestore.collection('cards').doc('3').set({
        'name': 'TOEIC対策',
        'type': '語学',
        'power': 25,
        'description': 'TOEIC高得点を目指す',
      });

      // ビジネスカード
      await _firestore.collection('cards').doc('4').set({
        'name': 'マーケティング戦略',
        'type': 'ビジネス',
        'power': 18,
        'description': '効果的なマーケティング戦略を学ぶ',
      });

      await _firestore.collection('cards').doc('5').set({
        'name': 'リーダーシップ研修',
        'type': 'ビジネス',
        'power': 30,
        'description': 'チームを導くリーダーシップスキルを身につける',
      });
    } catch (e) {
      print('初期カード作成エラー: $e');
    }
  }
}
