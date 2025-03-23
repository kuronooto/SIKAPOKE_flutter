import 'package:flutter/material.dart';
import 'dart:math' as math;

class CommonCardWidget extends StatelessWidget {
  final String cardId;
  final String name;
  final String type;
  final int power;
  final String rank;
  final bool isSelected;
  final VoidCallback? onTap;
  final bool showSparkles;

  const CommonCardWidget({
    Key? key,
    required this.cardId,
    required this.name,
    required this.type,
    required this.power,
    required this.rank,
    this.isSelected = false,
    this.onTap,
    this.showSparkles = true,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // レア度に基づく値を計算
    final int rarityLevel = _getRarityLevelFromRank(rank);
    final bool isHighRarity = rarityLevel >= 4;
    final random = math.Random(name.hashCode);

    return GestureDetector(
      onTap: onTap,
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
          border:
              isSelected
                  ? Border.all(color: Colors.yellow.shade300, width: 3)
                  : null,
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
                      color: _getRarityColor(rank).withOpacity(0.8),
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: Text(
                      _getRarityText(rank),
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 10,
                      ),
                    ),
                  ),

                  const SizedBox(height: 4),

                  // カードアイコン
                  Icon(_getCardIcon(rank), size: 40, color: Colors.white),

                  const SizedBox(height: 4),

                  // タイプ表示
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 4,
                      vertical: 1,
                    ),
                    decoration: BoxDecoration(
                      color: _getTypeColor(type),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      type,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 10,
                      ),
                    ),
                  ),

                  const SizedBox(height: 2),

                  // パワー表示
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
                      "P$power",
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 10,
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
                      name,
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

                  const SizedBox(height: 2),

                  // レア度表示
                  Text(
                    _getRarityStars(rank),
                    style: TextStyle(
                      fontSize: 8,
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
                ],
              ),
            ),

            // キラキラエフェクト (高レアリティの場合)
            if (isHighRarity && showSparkles)
              ..._buildSparkles(random, rarityLevel, rank),

            // 選択マーク - より目立つように改良
            if (isSelected)
              Positioned(
                top: 5,
                right: 5,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.yellow.shade400,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.5),
                        blurRadius: 3,
                        spreadRadius: 1,
                      ),
                    ],
                    border: Border.all(color: Colors.white, width: 1.5),
                  ),
                  child: const Icon(Icons.check, color: Colors.white, size: 14),
                ),
              ),

            // 選択済みテキスト表示
            if (isSelected)
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade600,
                    borderRadius: const BorderRadius.only(
                      bottomLeft: Radius.circular(5),
                      bottomRight: Radius.circular(5),
                    ),
                  ),
                  child: const Text(
                    '選択中',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 10,
                    ),
                  ),
                ),
              ),
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

  // カードの種類に応じた色を返す
  Color _getTypeColor(String type) {
    switch (type) {
      case 'IT':
        return Colors.blue;
      case 'ビジネス':
        return Colors.green;
      case '語学':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }
}
