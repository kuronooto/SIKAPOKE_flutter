import 'package:flutter/material.dart';
import '../viewmodels/battle_view_model.dart';

class BattlePage extends StatefulWidget {
  const BattlePage({super.key});

  @override
  State<BattlePage> createState() => _BattlePageState();
}

class _BattlePageState extends State<BattlePage> {
  final BattleViewModel _viewModel = BattleViewModel();
  String infoText = '';
  bool _isLoading = false; // ボタンの状態を管理

  Future<void> _handleBattleStart() async {
    setState(() {
      _isLoading = true; // ボタンを無効化
    });

    final result = await _viewModel.handleBattleStart();

    setState(() {
      infoText = result;
      _isLoading = false; // 処理完了後にボタンを有効化
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Battle Page')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _isLoading
                ? const CircularProgressIndicator() // 読み込みアニメーション
                : ElevatedButton(
                  onPressed: _isLoading ? null : _handleBattleStart,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    minimumSize: const Size(200, 50),
                    textStyle: const TextStyle(fontSize: 18),
                  ),
                  child: const Text('バトル開始'),
                ),
            const SizedBox(height: 20),
            if (infoText.isNotEmpty)
              Text(
                infoText,
                style: const TextStyle(color: Colors.red),
                textAlign: TextAlign.center,
              ),
          ],
        ),
      ),
    );
  }
}
