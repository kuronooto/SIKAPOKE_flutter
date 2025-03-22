import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'gacha/gacha_screen.dart';
import '../viewmodels/gacha_view_model.dart';

class PackOpeningPage extends StatelessWidget {
  const PackOpeningPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('資格パックを開封'),
        backgroundColor: Colors.deepPurple,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.deepPurple.shade50, Colors.white],
          ),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                '資格パックを開封しましょう！',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.deepPurple,
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                '「最強の資格」「資格のある島」「時空の資格」「超克の資格」',
                style: TextStyle(fontSize: 16, color: Colors.deepPurple),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              _buildPackPreview(context),
              const SizedBox(height: 30),
              ElevatedButton(
                onPressed: () {
                  // GachaScreen に遷移 (デフォルトで最強の資格パックを表示)
                  _navigateToGachaScreen(context, 0);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.deepPurple,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 30,
                    vertical: 15,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                ),
                child: const Text(
                  'パックを開封する',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
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

  // パックプレビューウィジェット
  Widget _buildPackPreview(BuildContext context) {
    return Container(
      height: 100,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        children: [
          _buildPreviewItem(context, Colors.deepPurple.shade300, '最強の資格', 0),
          _buildPreviewItem(context, Colors.blue.shade400, '資格のある島', 1),
          _buildPreviewItem(context, Colors.teal.shade500, '時空の資格', 2),
          _buildPreviewItem(context, Colors.red.shade600, '超克の資格', 3),
        ],
      ),
    );
  }

  Widget _buildPreviewItem(
    BuildContext context,
    Color color,
    String name,
    int packTypeIndex,
  ) {
    return GestureDetector(
      onTap: () {
        // 共通メソッドを使用してガチャ画面に遷移
        _navigateToGachaScreen(context, packTypeIndex);
      },
      child: Container(
        width: 80,
        margin: const EdgeInsets.symmetric(horizontal: 8),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [color.withOpacity(0.8), color],
          ),
          borderRadius: BorderRadius.circular(10),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 5,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // パックアイコン
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.black, width: 2),
              ),
            ),
            const SizedBox(height: 8),
            // パック名
            Text(
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
          ],
        ),
      ),
    );
  }
}
