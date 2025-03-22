import 'package:flutter/material.dart';
import '../viewmodels/battle_view_model.dart';
import 'room_page.dart';

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
                        'ルームID: $dialogRoomId',
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
                      onPressed: () {
                        _cancelMatching(context);
                      },
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
      dialogRoomId = _currentRoomId;
    });

    // 対戦相手が見つかるまでポーリング
    bool isMatched = false;
    int timeoutSeconds = 30; // タイムアウト秒数
    int elapsedSeconds = 0;

    while (elapsedSeconds < timeoutSeconds) {
      if (_currentRoomId == null) {
        break; // キャンセルされた場合
      }

      isMatched = await _viewModel.checkIfMatched(_currentRoomId!);
      if (isMatched) {
        // ダイアログの状態を更新
        setState(() {
          _isMatched = true; // マッチング成功状態を更新
        });
        break;
      }

      await Future.delayed(const Duration(seconds: 1)); // 1秒待機
      elapsedSeconds++;
    }

    if (!isMatched && _currentRoomId != null) {
      // タイムアウトした場合、ルームをキャンセル
      await _viewModel.cancelMatching(_currentRoomId!);
      if (mounted) {
        setState(() {
          infoText = 'マッチングタイムアウト。再度試してください。';
          _isLoading = false;
        });

        if (Navigator.canPop(context)) {
          Navigator.pop(context); // ダイアログを閉じる
        }
        return;
      }
    }

    if (mounted) {
      setState(() {
        infoText = result;
        _isLoading = false; // 処理完了後にボタンを有効化
      });
    }

    // マッチングが成功した場合
    if (isMatched && _currentRoomId != null) {
      await Future.delayed(const Duration(seconds: 1)); // 成功メッセージを表示する時間

      if (mounted && Navigator.canPop(context)) {
        Navigator.pop(context); // ダイアログを閉じる
      }

      // RoomPage に遷移
      final roomData = await _viewModel.getRoomData(_currentRoomId!);
      if (roomData != null && mounted) {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder:
                (context) => RoomPage(
                  roomId: roomData['roomId'],
                  player1Id: roomData['player1Id'],
                  player2Id: roomData['player2Id'],
                  gameState: roomData['gameState'],
                ),
          ),
        );
      }
    }
  }

  Future<void> _cancelMatching(BuildContext dialogContext) async {
    if (_currentRoomId != null) {
      await _viewModel.cancelMatching(_currentRoomId!); // ViewModel を利用してルームを削除
      _currentRoomId = null;
    }

    if (Navigator.canPop(dialogContext)) {
      Navigator.pop(dialogContext); // ダイアログを閉じる
    }

    if (mounted) {
      setState(() {
        _isLoading = false; // ボタンを再度有効化
        infoText = 'マッチングを中止しました';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AbsorbPointer(
      absorbing: _isLoading, // マッチング中は他のUIを無効化
      child: Scaffold(
        appBar: AppBar(title: const Text('バトルモード'), centerTitle: true),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Image.asset(
                'assets/battle_logo.png', // アセットに適切な画像を配置してください
                width: 150,
                height: 150,
                errorBuilder: (context, error, stackTrace) {
                  return const Icon(
                    Icons.sports_kabaddi,
                    size: 120,
                    color: Colors.blue,
                  );
                },
              ),
              const SizedBox(height: 30),
              const Text(
                'オンライン対戦モード',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 40),
                child: Text(
                  'ランダムな相手とカードバトルを行います。3ポイント先取か、相手のOMPが100を超えると勝利です！',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 14, color: Colors.grey),
                ),
              ),
              const SizedBox(height: 40),
              ElevatedButton(
                onPressed: _isLoading ? null : _handleBattleStart,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(200, 50),
                  textStyle: const TextStyle(fontSize: 18),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                ),
                child:
                    _isLoading
                        ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                        : const Text('バトル開始'),
              ),
              const SizedBox(height: 20),
              if (infoText.isNotEmpty)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: Text(
                    infoText,
                    style: TextStyle(
                      color:
                          infoText.contains('エラー') ? Colors.red : Colors.blue,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
