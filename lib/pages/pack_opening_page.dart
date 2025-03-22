import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
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
                    'assets/images/packs/normal_pack.png',
                    0,
                    screenWidth,
                  ),
                  _buildPackCard(
                    context,
                    Colors.blue.shade400,
                    '資格のある島',
                    'assets/images/packs/rare_pack.png',
                    1,
                    screenWidth,
                  ),
                  _buildPackCard(
                    context,
                    Colors.teal.shade500,
                    '時空の資格',
                    'assets/images/packs/super_rare_pack.png',
                    2,
                    screenWidth,
                  ),
                  _buildPackCard(
                    context,
                    Colors.red.shade600,
                    '超克の資格',
                    'assets/images/packs/legend_pack.png',
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
    String imagePath,
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
                  Container(
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      color: Colors.black,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      _getRarityLabel(packTypeIndex),
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 8,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // 中央のアイコン
            Expanded(
              child: Center(
                child: Container(
                  width: cardWidth * 0.5,
                  height: cardWidth * 0.5,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.black, width: 2),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.2),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Center(
                    child: Container(
                      width: cardWidth * 0.3,
                      height: cardWidth * 0.3,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.black, width: 1.5),
                      ),
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

  // レア度ラベルを取得
  String _getRarityLabel(int typeIndex) {
    switch (typeIndex) {
      case 0:
        return 'N';
      case 1:
        return 'R';
      case 2:
        return 'SR';
      case 3:
        return 'UR';
      default:
        return 'N';
    }
  }
}
