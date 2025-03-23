import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../viewmodels/battle_view_model.dart';
import 'room_page.dart';
import '../widgets/common/card.dart';

class BattlePage extends StatefulWidget {
  const BattlePage({super.key});

  @override
  State<BattlePage> createState() => _BattlePageState();
}

class _BattlePageState extends State<BattlePage> {
  final BattleViewModel _viewModel = BattleViewModel();
  String infoText = '';
  bool _isLoading = false;
  String? _currentRoomId;
  bool _isMatched = false;

  // Player deck information
  List<int> _playerDeck = [];
  List<Map<String, dynamic>> _deckCards = [];
  bool _isDeckLoaded = false;

  @override
  void initState() {
    super.initState();
    _loadPlayerDeck();
  }

  // Load the player's deck from Firestore
  Future<void> _loadPlayerDeck() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId == null) {
        setState(() {
          infoText = 'ログインしてください';
          _isLoading = false;
        });
        return;
      }

      // Get the player's deck
      final userDoc =
          await FirebaseFirestore.instance
              .collection('users')
              .doc(userId)
              .get();

      if (userDoc.exists && userDoc.data()!.containsKey('deck')) {
        _playerDeck = List<int>.from(userDoc.data()!['deck']);

        // Load card data for each card in the deck
        for (var cardId in _playerDeck) {
          // Skip placeholder or invalid cards (cardId 0)
          if (cardId > 0) {
            final cardDoc =
                await FirebaseFirestore.instance
                    .collection('cards')
                    .where('id', isEqualTo: cardId)
                    .limit(1)
                    .get();

            if (cardDoc.docs.isNotEmpty) {
              _deckCards.add(cardDoc.docs.first.data());
            }
          }
        }

        setState(() {
          _isDeckLoaded = true;
        });
      }
    } catch (e) {
      setState(() {
        infoText = 'デッキの読み込みエラー: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _handleBattleStart() async {
    // デッキにカードがあるか確認
    if (_playerDeck.isEmpty || _deckCards.isEmpty) {
      setState(() {
        infoText = 'デッキにカードがないため、バトルを開始できません';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _isMatched = false;
      infoText = '';
    });

    // ダイアログとその状態変数
    String? dialogRoomId;
    String statusMessage = '対戦相手を探しています...';
    bool showErrorCancel = false;

    // マッチングダイアログを表示
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            return AlertDialog(
              title: const Text('マッチング'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (!_isMatched) ...[
                    const CircularProgressIndicator(),
                    const SizedBox(height: 20),
                    Text(statusMessage),
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
                      style: const TextStyle(fontSize: 14, color: Colors.grey),
                    ),
                  ],
                ],
              ),
              actions: [
                if (!_isMatched || showErrorCancel)
                  TextButton(
                    onPressed: () {
                      _cancelMatching();
                      Navigator.of(dialogContext).pop();
                    },
                    child: const Text('マッチング中止'),
                  ),
              ],
            );
          },
        );
      },
    );

    try {
      // マッチング処理を開始
      final result = await _viewModel.handleBattleStart();

      setState(() {
        _currentRoomId = _viewModel.currentRoomId;
        dialogRoomId = _currentRoomId;
      });

      // 実行結果から判断して適切なメッセージを設定
      if (result.contains('新しいルームを作成しました')) {
        statusMessage = '部屋を作成しました。対戦相手を待っています...';
      } else if (result.contains('ルームに参加しました')) {
        statusMessage = 'マッチングが成功しました！';
        _isMatched = true;
      } else {
        statusMessage = result;
      }

      // ルームIDがあればポーリングを開始
      if (_currentRoomId != null) {
        // 最大30秒間ポーリング
        bool matchingSuccess = false;
        for (int i = 0; i < 30; i++) {
          final isMatched = await _viewModel.checkIfMatched(_currentRoomId!);
          if (isMatched) {
            setState(() {
              _isMatched = true;
              statusMessage = 'マッチング成功！ゲーム画面に移動します...';
            });
            matchingSuccess = true;
            break;
          }
          await Future.delayed(const Duration(seconds: 1));
        }

        // 30秒経過してもマッチングしなかった場合
        if (!matchingSuccess) {
          statusMessage = 'マッチングタイムアウト。しばらく経ってからもう一度お試しください。';
          showErrorCancel = true;
          setState(() {
            infoText = 'マッチングタイムアウト';
          });
          return;
        }
      }

      // 部屋データを取得してゲーム画面に遷移
      final roomData = await _viewModel.getRoomData(_currentRoomId!);
      if (roomData != null) {
        // ダイアログを閉じる
        if (Navigator.canPop(context)) {
          Navigator.pop(context);
        }

        // ゲーム画面に遷移
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
    } catch (e) {
      statusMessage = 'エラーが発生しました: $e';
      showErrorCancel = true;
      setState(() {
        infoText = 'マッチングエラー: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _cancelMatching() async {
    if (_currentRoomId != null) {
      await _viewModel.cancelMatching(_currentRoomId!);
    }
    if (Navigator.canPop(context)) {
      Navigator.pop(context);
    }
    setState(() {
      _isLoading = false;
      infoText = 'マッチングを中止しました';
    });
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('バトル'),
        backgroundColor: Colors.blueGrey[700],
      ),
      body:
          _isLoading && !_isDeckLoaded
              ? const Center(child: CircularProgressIndicator())
              : Column(
                children: [
                  // 上部：バトル説明
                  Container(
                    padding: const EdgeInsets.all(16),
                    color: Colors.blue[100],
                    child: const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'カードバトルルール',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 8),
                        Text('1. 各ターンごとに1枚のカードを選択します'),
                        Text('2. 3ポイント先取で勝利'),
                        Text('3. OMP（オーバーマウント・ポイント）が100を超えると敗北'),
                        Text('4. カード相性: IT > 語学 > ビジネス > IT'),
                      ],
                    ),
                  ),

                  // 中部：デッキカード表示
                  Expanded(
                    child:
                        _deckCards.isEmpty
                            ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(
                                    Icons.warning,
                                    size: 64,
                                    color: Colors.orange,
                                  ),
                                  const SizedBox(height: 16),
                                  const Text(
                                    'デッキにカードがありません',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  const Text(
                                    'カードページからデッキを設定してください',
                                    style: TextStyle(color: Colors.grey),
                                  ),
                                  if (infoText.isNotEmpty) ...[
                                    const SizedBox(height: 16),
                                    Padding(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 24,
                                      ),
                                      child: Text(
                                        infoText,
                                        style: const TextStyle(
                                          color: Colors.red,
                                        ),
                                        textAlign: TextAlign.center,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            )
                            : Column(
                              children: [
                                const Padding(
                                  padding: EdgeInsets.all(12),
                                  child: Text(
                                    'あなたのデッキ',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                Expanded(
                                  child: GridView.builder(
                                    padding: const EdgeInsets.all(12),
                                    gridDelegate:
                                        const SliverGridDelegateWithFixedCrossAxisCount(
                                          crossAxisCount: 2,
                                          childAspectRatio: 0.8,
                                          crossAxisSpacing: 12,
                                          mainAxisSpacing: 12,
                                        ),
                                    itemCount: _deckCards.length,
                                    itemBuilder: (context, index) {
                                      final card = _deckCards[index];
                                      return _buildCardItem(card);
                                    },
                                  ),
                                ),
                              ],
                            ),
                  ),

                  // 下部：バトル開始ボタン
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    child: ElevatedButton(
                      onPressed:
                          _deckCards.isEmpty || _isLoading
                              ? null
                              : _handleBattleStart,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text(
                        'バトル開始',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
    );
  }

  Widget _buildCardItem(Map<String, dynamic> card) {
    final String name = card['name'] as String;
    final int power = card['power'] as int;
    final String type = card['type'] as String;
    final String rank = card['rank'] as String;
    final int cardId = card['id'] as int;

    return CommonCardWidget(
      cardId: cardId.toString(),
      name: name,
      type: type,
      power: power,
      rank: rank,
      isSelected: false,
      onTap: null, // バトル画面では選択できないので null
    );
  }
}
