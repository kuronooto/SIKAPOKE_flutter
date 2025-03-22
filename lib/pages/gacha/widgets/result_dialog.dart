import 'package:flutter/material.dart';
import '../../../models/pack_model.dart';
import 'dart:math';

class ResultDialog extends StatelessWidget {
  final CardResult result;
  final VoidCallback onClose;

  const ResultDialog({Key? key, required this.result, required this.onClose})
    : super(key: key);

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: Colors.white.withOpacity(0.9),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Text(
        'ゲット！',
        style: TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.bold,
          color: Colors.deepPurple,
        ),
        textAlign: TextAlign.center,
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 獲得したカードの表示
          Container(
            width: 200,
            height: 280,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: _getGradientColors(result.rarityLevel),
              ),
              borderRadius: BorderRadius.circular(15),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.3),
                  spreadRadius: 1,
                  blurRadius: 10,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: Stack(
              children: [
                // 背景グラデーション
                Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(15),
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: _getGradientColors(result.rarityLevel),
                    ),
                  ),
                ),

                // カードの枠線
                Container(
                  margin: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.5),
                      width: 2,
                    ),
                  ),
                ),

                // カードコンテンツ
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // レアリティ表示
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: _getRarityColor(
                          result.rarityLevel,
                        ).withOpacity(0.8),
                        borderRadius: BorderRadius.circular(15),
                      ),
                      child: Text(
                        _getRarityText(result.rarityLevel),
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ),

                    const SizedBox(height: 15),

                    // カードアイコン
                    Icon(
                      _getCardIcon(result.rarityLevel),
                      size: 80,
                      color: Colors.white,
                    ),

                    const SizedBox(height: 15),

                    // カード名
                    Container(
                      width: 180,
                      padding: const EdgeInsets.symmetric(
                        vertical: 8,
                        horizontal: 10,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.4),
                        borderRadius: BorderRadius.circular(5),
                      ),
                      child: Text(
                        result.name,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ),

                    const SizedBox(height: 15),

                    // レア度表示
                    Text(
                      result.rarityStars,
                      style: TextStyle(
                        fontSize: 22,
                        color: _getStarColor(result.rarityLevel),
                        fontWeight: FontWeight.bold,
                        shadows: [
                          Shadow(
                            blurRadius: 5,
                            color: _getStarColor(
                              result.rarityLevel,
                            ).withOpacity(0.8),
                            offset: const Offset(0, 0),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                // キラキラエフェクト (高レアリティの場合)
                if (result.rarityLevel >= 4) ..._buildSparkles(),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Text(
            result.name,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.deepPurple,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            'レア度: ${result.rarityStars}',
            style: TextStyle(
              fontSize: 16,
              color: _getRarityColor(result.rarityLevel),
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            result.description,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 14, color: Colors.black87),
          ),
        ],
      ),
      actions: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton(
              onPressed: () {
                // 現在のダイアログを閉じる
                Navigator.of(context).pop();

                // onClose コールバックを実行
                onClose();

                // GachaScreen を閉じて元のページに戻る
                Navigator.of(context).pop();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.deepPurple,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 40,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
              ),
              child: const Text('閉じる', style: TextStyle(fontSize: 16)),
            ),
          ],
        ),
      ],
    );
  }

  // キラキラエフェクトを生成
  List<Widget> _buildSparkles() {
    final random = Random(result.name.hashCode);
    const sparkleCount = 10;

    return List.generate(sparkleCount, (index) {
      final size = 3.0 + random.nextDouble() * 5.0;
      final left = random.nextDouble() * 200;
      final top = random.nextDouble() * 280;
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
                color: _getStarColor(result.rarityLevel).withOpacity(0.8),
                blurRadius: 4,
                spreadRadius: 1,
              ),
            ],
          ),
        ),
      );
    });
  }

  List<Color> _getGradientColors(int rarityLevel) {
    switch (rarityLevel) {
      case 1:
        return [Colors.blue.shade300, Colors.lightBlue.shade100];
      case 2:
        return [Colors.purple.shade300, Colors.purple.shade100];
      case 3:
        return [Colors.orange.shade300, Colors.yellow.shade200];
      case 4:
        return [Colors.pink.shade300, Colors.purple.shade200];
      case 5:
        return [Colors.red.shade400, Colors.amber.shade300];
      default:
        return [Colors.blue.shade300, Colors.lightBlue.shade100];
    }
  }

  Color _getRarityColor(int rarityLevel) {
    switch (rarityLevel) {
      case 1:
        return Colors.blue.shade700;
      case 2:
        return Colors.purple.shade700;
      case 3:
        return Colors.orange.shade700;
      case 4:
        return Colors.pink.shade700;
      case 5:
        return Colors.red.shade700;
      default:
        return Colors.blue.shade700;
    }
  }

  Color _getStarColor(int rarityLevel) {
    switch (rarityLevel) {
      case 1:
        return Colors.blue.shade300;
      case 2:
        return Colors.purple.shade300;
      case 3:
        return Colors.orange.shade300;
      case 4:
        return Colors.pink.shade300;
      case 5:
        return Colors.yellow;
      default:
        return Colors.blue.shade300;
    }
  }

  String _getRarityText(int rarityLevel) {
    switch (rarityLevel) {
      case 1:
        return 'ノーマル';
      case 2:
        return 'レア';
      case 3:
        return 'スーパーレア';
      case 4:
        return 'ウルトラレア';
      case 5:
        return 'レジェンド';
      default:
        return 'ノーマル';
    }
  }

  IconData _getCardIcon(int rarityLevel) {
    switch (rarityLevel) {
      case 1:
        return Icons.style;
      case 2:
        return Icons.auto_awesome;
      case 3:
        return Icons.catching_pokemon;
      case 4:
        return Icons.diamond;
      case 5:
        return Icons.workspace_premium;
      default:
        return Icons.style;
    }
  }
}
