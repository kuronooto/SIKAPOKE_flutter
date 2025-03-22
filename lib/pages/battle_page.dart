import 'package:flutter/material.dart';
import '../viewmodels/battle_view_model.dart';
import 'room_page.dart'; // RoomPage をインポート

class BattlePage extends StatefulWidget {
  const BattlePage({super.key});

  @override
  State<BattlePage> createState() => _BattlePageState();
}

class _BattlePageState extends State<BattlePage> {
  final BattleViewModel _viewModel = BattleViewModel();
  String infoText = '';
  bool _isLoading = false; // ボタンの状態を管理
  String? _currentRoomId; // 現在のルームIDを保持
  bool _isMatched = false; // マッチング成功状態を管理

  Future<void> _handleBattleStart() async {
    setState(() {
      _isLoading = true; // ボタンを無効化
      _isMatched = false; // 初期化
    });

    // ダイアログの状態を更新するための変数
    String? dialogRoomId;

    showDialog(
      context: context,
      barrierDismissible: false, // ダイアログ外をタップしても閉じない
      builder: (context) {
        return WillPopScope(
          onWillPop: () async => false, // 戻るボタンを無効化
          child: StatefulBuilder(
            builder: (context, setState) {
              return AlertDialog(
                title: const Text('マッチング中'),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (!_isMatched) ...[
                      const CircularProgressIndicator(), // 読み込みアニメーション
                      const SizedBox(height: 20),
                      const Text('対戦相手を探しています...'),
                    ] else ...[
                      const Icon(
                        Icons.check_circle,
                        color: Colors.green,
                        size: 50,
                      ),
                      const SizedBox(height: 20),
                      const Text(
                        'マッチング成功！',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                    if (dialogRoomId != null) ...[
                      const SizedBox(height: 10),
                      Text(
                        'Room ID: $dialogRoomId',
                        style: const TextStyle(
                          fontSize: 14,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ],
                ),
                actions: [
                  if (!_isMatched)
                    TextButton(
                      onPressed: _cancelMatching, // マッチング中止
                      child: const Text('マッチング中止'),
                    ),
                ],
              );
            },
          ),
        );
      },
    );

    final result = await _viewModel.handleBattleStart();

    // ダイアログの Room ID を更新
    setState(() {
      _currentRoomId = _viewModel.currentRoomId; // ルームIDを保持
    });
    dialogRoomId = _currentRoomId;

    // 対戦相手が見つかるまでポーリング
    while (true) {
      final isMatched = await _viewModel.checkIfMatched(_currentRoomId!);
      if (isMatched) {
        // ダイアログの状態を更新
        setState(() {
          _isMatched = true; // マッチング成功状態を更新
        });
        break;
      }
      await Future.delayed(const Duration(seconds: 1)); // 1秒待機
    }

    setState(() {
      infoText = result;
      _isLoading = false; // 処理完了後にボタンを有効化
    });

    if (Navigator.canPop(context)) {
      Navigator.pop(context); // ダイアログを閉じる
    }

    // RoomPage に遷移
    final roomData = await _viewModel.getRoomData(_currentRoomId!);
    if (roomData != null) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder:
              (context) => RoomPage(
                roomId: roomData['roomId'],
                player1Id: roomData['player1Id'],
                player2Id: roomData['player2Id'],
              ),
        ),
      );
    }
  }

  Future<void> _cancelMatching() async {
    if (_currentRoomId != null) {
      await _viewModel.cancelMatching(_currentRoomId!); // ViewModel を利用してルームを削除
    }
    if (Navigator.canPop(context)) {
      Navigator.pop(context); // ダイアログを閉じる
    }
    setState(() {
      _isLoading = false; // ボタンを再度有効化
      infoText = 'マッチングを中止しました';
    });
  }

  @override
  Widget build(BuildContext context) {
    return AbsorbPointer(
      absorbing: _isLoading, // マッチング中は他のUIを無効化
      child: Scaffold(
        appBar: AppBar(title: const Text('Battle Page')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ElevatedButton(
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
      ),
    );
  }
}
