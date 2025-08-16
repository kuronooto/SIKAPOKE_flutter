import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'Deckbuilder_page.dart';

class CardPage extends StatelessWidget {
  final String userId;

  const CardPage({super.key, required this.userId});

  /// ユーザーの所持カードを取得し、それに対応するカード情報を結合
  Future<List<Map<String, dynamic>>> getOwnedCardDetails() async {
    CollectionReference ownedCardsRef = FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('owned_cards');

    CollectionReference cardsRef = FirebaseFirestore.instance.collection('cards');

    try {
      final ownedSnapshot = await ownedCardsRef.get();
      // 修正: 例外にならないよう安全に取り出し、count/number 両対応
      final ownedCards = ownedSnapshot.docs.map((doc) {
        final data = (doc.data() as Map<String, dynamic>? ) ?? {};
        final id = (data['id'] is int)
            ? data['id'] as int
            : int.tryParse(doc.id) ?? 0;
        final rawCount = data['count'] ?? data['number'] ?? 0;
        final owned = rawCount is int ? rawCount : int.tryParse(rawCount.toString()) ?? 0;
        return {'cardId': id, 'owned': owned};
      }).where((e) => (e['cardId'] as int) > 0 && (e['owned'] as int) > 0).toList();

      final List<Map<String, dynamic>> cardDetails = [];
      for (var owned in ownedCards) {
        final cardId = owned['cardId'] as int;
        final snap = await cardsRef.where('id', isEqualTo: cardId).limit(1).get();
        if (snap.docs.isNotEmpty) {
          final cardData = snap.docs.first.data() as Map<String, dynamic>;
          cardDetails.add({
            'cardId': cardData['id'],
            'name': cardData['name'],
            'power': cardData['power'],
            'rank': cardData['rank'],
            'type': cardData['type'],
            // 修正: 所持枚数キーを owned に統一
            'owned': owned['owned'],
            'rarityLevel': _getRarityLevelFromRank(cardData['rank']),
          });
        }
      }

      return cardDetails;
    } catch (e) {
      // print("エラー: $e");
      return [];
    }
  }

  // ランクからレアリティレベルへの変換
  int _getRarityLevelFromRank(String rank) {
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

  // レア度に応じたテキストを取得
  String _getRarityText(String rank) {
    switch (rank) {
      case 'S':
        return 'レジェンド';
      case 'A':
        return 'ウルトラレア';
      case 'B':
        return 'スーパーレア';
      case 'C':
        return 'レア';
      case 'D':
        return 'ノーマル';
      default:
        return 'ノーマル';
    }
  }

  // ランクからレア度の星表示を取得
  String _getRarityStars(String rank) {
    int level = _getRarityLevelFromRank(rank);
    return '★' * level;
  }

  // レア度に応じたアイコンを取得
  IconData _getCardIcon(String rank) {
    switch (rank) {
      case 'S':
        return Icons.workspace_premium;
      case 'A':
        return Icons.diamond;
      case 'B':
        return Icons.catching_pokemon;
      case 'C':
        return Icons.auto_awesome;
      case 'D':
        return Icons.style;
      default:
        return Icons.style;
    }
  }

  // レア度に応じた色を取得
  Color _getRarityColor(String rank) {
    switch (rank) {
      case 'S':
        return Colors.red.shade700;
      case 'A':
        return Colors.pink.shade700;
      case 'B':
        return Colors.orange.shade700;
      case 'C':
        return Colors.purple.shade700;
      case 'D':
        return Colors.blue.shade700;
      default:
        return Colors.blue.shade700;
    }
  }

  // レア度に応じたグラデーションを取得
  List<Color> _getGradientColors(String rank) {
    switch (rank) {
      case 'S':
        return [Colors.red.shade400, Colors.amber.shade300];
      case 'A':
        return [Colors.pink.shade300, Colors.purple.shade200];
      case 'B':
        return [Colors.orange.shade300, Colors.yellow.shade200];
      case 'C':
        return [Colors.purple.shade300, Colors.purple.shade100];
      case 'D':
        return [Colors.blue.shade300, Colors.lightBlue.shade100];
      default:
        return [Colors.blue.shade300, Colors.lightBlue.shade100];
    }
  }

  // レア度の星の色を取得
  Color _getStarColor(String rank) {
    switch (rank) {
      case 'S':
        return Colors.yellow;
      case 'A':
        return Colors.pink.shade300;
      case 'B':
        return Colors.orange.shade300;
      case 'C':
        return Colors.purple.shade300;
      case 'D':
        return Colors.blue.shade300;
      default:
        return Colors.blue.shade300;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("所持カード一覧"),
        backgroundColor: Colors.deepPurple,
        elevation: 0,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.deepPurple.shade50, Colors.white],
          ),
        ),
        child: FutureBuilder(
          future: getOwnedCardDetails(),
          builder: (context, AsyncSnapshot<List<Map<String, dynamic>>> snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return const Center(child: Text("エラーが発生しました"));
            }
            if (!snapshot.hasData || snapshot.data!.isEmpty) {
              return const Center(child: Text("カードを所持していません"));
            }

            List<Map<String, dynamic>> cards = snapshot.data!;

            // レア度順にソート
            cards.sort((a, b) => b['rarityLevel'].compareTo(a['rarityLevel']));

            return GridView.builder(
              padding: const EdgeInsets.all(8),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 5,
                childAspectRatio: 0.6,
                crossAxisSpacing: 6,
                mainAxisSpacing: 6,
              ),
              itemCount: cards.length,
              itemBuilder: (context, index) {
                var card = cards[index];
                return _buildCardItem(context, card);
              },
            );
          },
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          // 所持カード情報を取得
          final ownedCards = await getOwnedCardDetails();

          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => DeckBuilderPage(
                userId: userId,
                ownedCards: ownedCards,
                deckId: "default_deck",
              ),
            ),
          );
        },
        backgroundColor: Colors.deepPurple,
        child: const Icon(Icons.dashboard),
      ),
    );
  }

  Widget _buildCardItem(BuildContext context, Map<String, dynamic> card) {
    final String rank = card['rank'];
    final int rarityLevel = card['rarityLevel'];

    // 高レアリティのカードはエフェクトを表示
    final bool isHighRarity = rarityLevel >= 4;
    final random = math.Random(card['name'].hashCode);

    return GestureDetector(
      onTap: () => _showCardDetails(context, card),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: _getGradientColors(rank),
          ),
          borderRadius: BorderRadius.circular(8),
          boxShadow: [
            BoxShadow(
              color: _getRarityColor(rank).withOpacity(0.5),
              spreadRadius: 0.5,
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Stack(
          children: [
            // 背景グラデーション
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: _getGradientColors(rank),
                ),
              ),
            ),

            // カードの枠線
            Container(
              margin: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: Colors.white.withOpacity(0.5),
                  width: 1,
                ),
              ),
            ),

            // カードコンテンツ
            Padding(
              padding: const EdgeInsets.all(4.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  // レアリティ表示
                 Container(
  padding: const EdgeInsets.symmetric(
    horizontal: 5,
    vertical: 1,
  ),
  decoration: BoxDecoration(
    color: Colors.black.withOpacity(0.7), // 属性ごとに色分けしたい場合はここを工夫
    borderRadius: BorderRadius.circular(15),
  ),
  child: Text(
    card['type'] ?? '',
    style: const TextStyle(
      color: Colors.white,
      fontWeight: FontWeight.bold,
      fontSize: 12,
    ),
  ),
),

                  const SizedBox(height: 8),

                  // カードアイコン
                  Icon(_getCardIcon(rank), size: 60, color: Colors.white),

                  const SizedBox(height: 8),

                  // パワー
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 4,
                      vertical: 1,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      "P${card['power']}",
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 8,
                      ),
                    ),
                  ),

                  const SizedBox(height: 2),

                  // カード名
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      vertical: 2,
                      horizontal: 1,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.4),
                      borderRadius: BorderRadius.circular(2),
                    ),
                    child: Text(
                      card['name'],
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 8,
                      ),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 2,
                    ),
                  ),

                  const SizedBox(height: 4),

                  // レア度表示
                  Text(
                    _getRarityStars(rank),
                    style: TextStyle(
                      fontSize: 9,
                      color: _getStarColor(rank),
                      fontWeight: FontWeight.bold,
                      shadows: [
                        Shadow(
                          blurRadius: 2,
                          color: _getStarColor(rank).withOpacity(0.8),
                          offset: const Offset(0, 0),
                        ),
                      ],
                    ),
                  ),

                  // 所持枚数（修正: number -> owned）
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      "×${card['owned']}",
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 8,
                        shadows: [
                          Shadow(
                            color: Colors.black.withOpacity(0.5),
                            offset: const Offset(0.5, 0.5),
                            blurRadius: 1,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // キラキラエフェクト (高レアリティの場合)
            if (isHighRarity) ..._buildSparkles(random, rarityLevel, rank),
          ],
        ),
      ),
    );
  }

  // キラキラエフェクトを生成
  List<Widget> _buildSparkles(
    math.Random random,
    int rarityLevel,
    String rank,
  ) {
    final sparkleCount = rarityLevel >= 5 ? 6 : 4;

    return List.generate(sparkleCount, (index) {
      final size = 1.0 + random.nextDouble() * 2.0;
      final left = random.nextDouble() * 70;
      final top = random.nextDouble() * 100;
      final opacity = 0.5 + random.nextDouble() * 0.5;

      return Positioned(
        left: left,
        top: top,
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(opacity),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: _getStarColor(rank).withOpacity(0.8),
                blurRadius: 2,
                spreadRadius: 0.5,
              ),
            ],
          ),
        ),
      );
    });
  }

  // カードの詳細を表示するダイアログ
  void _showCardDetails(BuildContext context, Map<String, dynamic> card) {
    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: _getGradientColors(card['rank']),
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.5),
                  spreadRadius: 1,
                  blurRadius: 15,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // ヘッダー
                Text(
                  card['name'],
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    shadows: [
                      Shadow(
                        color: Colors.black54,
                        offset: Offset(1, 1),
                        blurRadius: 2,
                      ),
                    ],
                  ),
                  textAlign: TextAlign.center,
                ),

                const SizedBox(height: 10),

                // ラベル装飾
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: _getRarityColor(card['rank']).withOpacity(0.8),
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: Text(
                    _getRarityText(card['rank']),
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                // アイコン
                Icon(_getCardIcon(card['rank']), size: 80, color: Colors.white),

                const SizedBox(height: 20),

                // 詳細情報
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _detailRow("ID", card['cardId'].toString()),
                      _detailRow("タイプ", card['type']),
                      _detailRow("パワー", card['power'].toString()),
                      _detailRow("ランク", "${card['rank']} (${_getRarityStars(card['rank'])})"),
                      // 修正: 所持枚数（number -> owned）
                      _detailRow("所持枚数", "${card['owned']}枚"),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // 閉じるボタン
                ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: _getRarityColor(card['rank']),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 40,
                      vertical: 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                  ),
                  child: const Text(
                    '閉じる',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // 詳細情報の行を作成
  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        children: [
          Text(
            "$label: ",
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          Text(
            value,
            style: const TextStyle(color: Colors.white, fontSize: 16),
          ),
        ],
      ),
    );
  }
}
