import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:math' as math;
import 'gacha/gacha_screen.dart';
import '../viewmodels/gacha_view_model.dart';

class PackOpeningPage extends StatelessWidget {
  const PackOpeningPage({super.key});

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          '資格パックを開封',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.deepPurple,
        elevation: 0,
      ),
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.deepPurple.shade300,
              Colors.deepPurple.shade50,
              Colors.white,
            ],
            stops: const [0.0, 0.3, 1.0],
          ),
        ),
        child: Column(
          children: [
            const SizedBox(height: 30),
            // タイトルと説明文
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.8),
                      borderRadius: BorderRadius.circular(30),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: const Text(
                      '資格パックを開封しましょう！',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.deepPurple,
                      ),
                    ),
                  ),
                  const SizedBox(height: 15),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.6),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text(
                      '「最強の資格」「資格のある島」「時空の資格」「超克の資格」',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.deepPurple,
                        fontWeight: FontWeight.w500,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 40),

            // パックセレクション（カード型UI）
            Container(
              height: screenHeight * 0.35,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildPackCard(
                    context,
                    Colors.deepPurple.shade300,
                    '最強の資格',
                    0,
                    screenWidth,
                  ),
                  _buildPackCard(
                    context,
                    Colors.blue.shade400,
                    '資格のある島',
                    1,
                    screenWidth,
                  ),
                  _buildPackCard(
                    context,
                    Colors.teal.shade500,
                    '時空の資格',
                    2,
                    screenWidth,
                  ),
                  _buildPackCard(
                    context,
                    Colors.red.shade600,
                    '超克の資格',
                    3,
                    screenWidth,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 40),

            // パックを開封するボタン
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 40),
              child: ElevatedButton(
                onPressed: () {
                  // デフォルトで「最強の資格」パックを選択
                  _navigateToGachaScreen(context, 0);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.deepPurple,
                  foregroundColor: Colors.white,
                  elevation: 8,
                  shadowColor: Colors.deepPurple.shade200,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 30,
                    vertical: 16,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                  minimumSize: Size(screenWidth * 0.7, 60),
                ),
                child: const Text(
                  'パックを開封する',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ガチャ画面に遷移する共通メソッド
  void _navigateToGachaScreen(BuildContext context, int packTypeIndex) {
    // GachaViewModel を作成
    final viewModel = GachaViewModel();

    // 直接選択せず、GachaScreenで選択するように変更
    Navigator.of(context).push(
      MaterialPageRoute(
        builder:
            (context) => ChangeNotifierProvider.value(
              value: viewModel,
              child: GachaScreen(selectedPackTypeIndex: packTypeIndex),
            ),
      ),
    );
  }

  // パックカードのウィジェット
  Widget _buildPackCard(
    BuildContext context,
    Color color,
    String name,
    int packTypeIndex,
    double screenWidth,
  ) {
    final cardWidth = screenWidth * 0.2;
    final cardHeight = cardWidth * 1.5;

    return GestureDetector(
      onTap: () => _navigateToGachaScreen(context, packTypeIndex),
      child: Container(
        width: cardWidth,
        height: cardHeight,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [color.withOpacity(0.7), color, color.withOpacity(0.8)],
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.5),
              offset: const Offset(0, 4),
              blurRadius: 8,
            ),
          ],
        ),
        child: Column(
          children: [
            // 上部バー
            Container(
              height: 24,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.2),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'SIKAPOKE',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 9,
                    ),
                  ),
                  Icon(Icons.auto_awesome, color: Colors.white, size: 12),
                ],
              ),
            ),

            // 中央のアイコン - 幾何学的デザイン
            Expanded(
              child: Center(
                child: Container(
                  width: cardWidth * 0.6,
                  height: cardWidth * 0.6,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(4),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.2),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: CustomPaint(
                    painter: MiniGeometricPatternPainter(
                      baseColor: color,
                      rarityLevel: packTypeIndex + 1,
                    ),
                  ),
                ),
              ),
            ),

            // 下部バー（パック名）
            Container(
              height: 32,
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 4),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.2),
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(16),
                  bottomRight: Radius.circular(16),
                ),
              ),
              child: Center(
                child: Text(
                  name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 10,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ミニサイズ用の幾何学的パターンを描画するカスタムペインター
class MiniGeometricPatternPainter extends CustomPainter {
  final Color baseColor;
  final int rarityLevel;

  MiniGeometricPatternPainter({
    required this.baseColor,
    required this.rarityLevel,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint =
        Paint()
          ..color = baseColor
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2;

    final fillPaint =
        Paint()
          ..color = baseColor.withOpacity(0.2)
          ..style = PaintingStyle.fill;

    final centerX = size.width / 2;
    final centerY = size.height / 2;

    // レベルに応じたパターンの複雑さ
    final complexity = rarityLevel;

    // 幾何学的なパターンを描画

    // 1. 中央の形
    switch (complexity) {
      case 1: // シンプルな四角形
        canvas.drawRect(
          Rect.fromCenter(
            center: Offset(centerX, centerY),
            width: size.width * 0.5,
            height: size.height * 0.5,
          ),
          paint,
        );
        break;

      case 2: // 二重の四角形
        canvas.drawRect(
          Rect.fromCenter(
            center: Offset(centerX, centerY),
            width: size.width * 0.6,
            height: size.height * 0.6,
          ),
          paint,
        );
        canvas.drawRect(
          Rect.fromCenter(
            center: Offset(centerX, centerY),
            width: size.width * 0.4,
            height: size.height * 0.4,
          ),
          paint,
        );
        break;

      case 3: // 三角形と四角形
        final path = Path();
        path.moveTo(centerX, centerY - size.height * 0.3);
        path.lineTo(centerX + size.width * 0.3, centerY + size.height * 0.3);
        path.lineTo(centerX - size.width * 0.3, centerY + size.height * 0.3);
        path.close();
        canvas.drawPath(path, paint);

        canvas.drawRect(
          Rect.fromCenter(
            center: Offset(centerX, centerY),
            width: size.width * 0.3,
            height: size.height * 0.3,
          ),
          paint,
        );
        break;

      case 4: // 複雑な六角形
        final radius = size.width * 0.35;
        final path = Path();
        for (int i = 0; i < 6; i++) {
          final angle = i * math.pi / 3;
          final x = centerX + radius * math.cos(angle);
          final y = centerY + radius * math.sin(angle);

          if (i == 0) {
            path.moveTo(x, y);
          } else {
            path.lineTo(x, y);
          }
        }
        path.close();
        canvas.drawPath(path, paint);

        // 内側の三角形
        final innerPath = Path();
        for (int i = 0; i < 3; i++) {
          final angle = i * 2 * math.pi / 3;
          final x = centerX + radius * 0.5 * math.cos(angle);
          final y = centerY + radius * 0.5 * math.sin(angle);

          if (i == 0) {
            innerPath.moveTo(x, y);
          } else {
            innerPath.lineTo(x, y);
          }
        }
        innerPath.close();
        canvas.drawPath(innerPath, paint);
        break;

      default: // デフォルトは単純な四角形
        canvas.drawRect(
          Rect.fromCenter(
            center: Offset(centerX, centerY),
            width: size.width * 0.5,
            height: size.height * 0.5,
          ),
          paint,
        );
    }

    // 2. 装飾パターン
    // レア度に応じて細かい装飾を追加
    for (int i = 0; i < complexity; i++) {
      // 周辺の円
      final radius = size.width * (0.15 + i * 0.05);
      canvas.drawCircle(
        Offset(centerX, centerY),
        radius,
        Paint()
          ..color = baseColor.withOpacity(0.3)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.8,
      );
    }

    // 3. 対角線
    if (complexity >= 3) {
      canvas.drawLine(
        Offset(size.width * 0.2, size.height * 0.2),
        Offset(size.width * 0.8, size.height * 0.8),
        Paint()
          ..color = baseColor.withOpacity(0.4)
          ..strokeWidth = 0.8,
      );
      canvas.drawLine(
        Offset(size.width * 0.8, size.height * 0.2),
        Offset(size.width * 0.2, size.height * 0.8),
        Paint()
          ..color = baseColor.withOpacity(0.4)
          ..strokeWidth = 0.8,
      );
    }

    // 4. 中央の点
    canvas.drawCircle(
      Offset(centerX, centerY),
      2.0,
      Paint()
        ..color = baseColor
        ..style = PaintingStyle.fill,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
