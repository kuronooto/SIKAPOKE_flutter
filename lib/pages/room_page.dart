import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class RoomPage extends StatefulWidget {
  final String roomId;
  final String player1Id;
  final String? player2Id;
  final Map<String, dynamic> gameState; // Add gameState parameter

  const RoomPage({
    super.key,
    required this.roomId,
    required this.player1Id,
    this.player2Id,
    required this.gameState, // Include gameState in the constructor
  });

  @override
  State<RoomPage> createState() => _RoomPageState();
}

class _RoomPageState extends State<RoomPage> {
  int turn = 1;
  int player1Points = 0;
  int player2Points = 0;
  int player1OMP = 0;
  int player2OMP = 0;
  int? selectedCardId;
  int? opponentCardId;
  bool isWaitingForOpponent = false;

  final Map<String, String> typeWeakness = {
    "IT": "語学",
    "語学": "ビジネス",
    "ビジネス": "IT",
  };

  @override
  void initState() {
    super.initState();
    _listenToGameState();
  }

  void _listenToGameState() {
    final roomRef = FirebaseFirestore.instance
        .collection('rooms')
        .doc(widget.roomId);
    roomRef.snapshots().listen((snapshot) {
      final data = snapshot.data();
      if (data != null) {
        final gameState = data['game_state'] as Map<String, dynamic>;
        final logs = data['logs'] as Map<String, dynamic>;

        setState(() {
          turn = gameState['turn'];
          player1Points = gameState['player1_point'];
          player2Points = gameState['player2_point'];
          player1OMP = gameState['player1_over_mount'];
          player2OMP = gameState['player2_over_mount'];
        });

        // ログを表示する場合の処理（必要に応じて追加）
        print('Logs: $logs');
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async => false, // 戻るボタンを無効化
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Room Page'),
          automaticallyImplyLeading: false, // AppBarの戻るボタンを非表示
        ),
        body: Column(
          children: [
            // 上部: ターン数、ポイント、OMP
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    children: [
                      Text('Player 1 Points: $player1Points'),
                      Text('Player 1 OMP: $player1OMP'),
                    ],
                  ),
                  Text('Turn: $turn'),
                  Column(
                    children: [
                      Text('Player 2 Points: $player2Points'),
                      Text('Player 2 OMP: $player2OMP'),
                    ],
                  ),
                ],
              ),
            ),
            const Divider(),
            // 中央: 選択したカードと相手のカード
            Expanded(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (selectedCardId != null)
                      Text('Your Card: $selectedCardId'),
                    if (opponentCardId != null)
                      Text('Opponent Card: $opponentCardId'),
                  ],
                ),
              ),
            ),
            const Divider(),
            // 下部: カード選択
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: List.generate(5, (index) {
                  return ElevatedButton(
                    onPressed:
                        isWaitingForOpponent
                            ? null
                            : () => _selectCard(index + 1),
                    child: Text('Card ${index + 1}'),
                  );
                }),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _selectCard(int cardId) async {
    setState(() {
      selectedCardId = cardId;
      isWaitingForOpponent = true;
    });

    // Firestore に選択したカードを送信
    final roomRef = FirebaseFirestore.instance
        .collection('rooms')
        .doc(widget.roomId);
    await roomRef.update({
      'game_state.player1_card':
          widget.player1Id == widget.player1Id ? cardId : null,
      'game_state.player2_card':
          widget.player1Id == widget.player2Id ? cardId : null,
    });

    // 相手のカードを待機
    _waitForOpponentCard();
  }

  void _waitForOpponentCard() async {
    final roomRef = FirebaseFirestore.instance
        .collection('rooms')
        .doc(widget.roomId);
    roomRef.snapshots().listen((snapshot) {
      final data = snapshot.data();
      if (data != null) {
        final gameState = data['game_state'] as Map<String, dynamic>;
        final opponentCard =
            widget.player1Id == widget.player1Id
                ? gameState['player2_card']
                : gameState['player1_card'];

        if (opponentCard != null) {
          setState(() {
            opponentCardId = opponentCard;
            isWaitingForOpponent = false;
          });

          // ターンの勝敗を計算
          _calculateTurnResult();
        }
      }
    });
  }

  void _calculateTurnResult() {
    if (selectedCardId == null || opponentCardId == null) return;

    // カードの攻撃力を取得
    final selectedCardPower = _getCardPower(selectedCardId!);
    final opponentCardPower = _getCardPower(opponentCardId!);

    // タイプ相性を計算
    final selectedCardType = _getCardType(selectedCardId!);
    final opponentCardType = _getCardType(opponentCardId!);

    int selectedCardFinalPower = selectedCardPower;
    int opponentCardFinalPower = opponentCardPower;

    if (typeWeakness[selectedCardType] == opponentCardType) {
      selectedCardFinalPower *= 2;
    }
    if (typeWeakness[opponentCardType] == selectedCardType) {
      opponentCardFinalPower *= 2;
    }

    // 勝敗を判定
    if (selectedCardFinalPower > opponentCardFinalPower) {
      player1Points++;
      player2OMP += selectedCardFinalPower - opponentCardFinalPower;
    } else if (selectedCardFinalPower < opponentCardFinalPower) {
      player2Points++;
      player1OMP += opponentCardFinalPower - selectedCardFinalPower;
    }

    // ターンを進める
    setState(() {
      turn++;
      selectedCardId = null;
      opponentCardId = null;
    });

    // 勝敗判定
    _checkGameOver();
  }

  void _checkGameOver() {
    if (player1Points >= 3) {
      _showGameOverDialog('You Win!');
    } else if (player2Points >= 3) {
      _showGameOverDialog('You Lose!');
    } else if (player1OMP > 100) {
      _showGameOverDialog('You Lose! (OMP Over)');
    } else if (player2OMP > 100) {
      _showGameOverDialog('You Win! (Opponent OMP Over)');
    }
  }

  void _showGameOverDialog(String result) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          title: Text(result),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                Navigator.of(context).pop();
              },
              child: const Text('Exit'),
            ),
          ],
        );
      },
    );
  }

  int _getCardPower(int cardId) {
    // 仮のカード攻撃力を返す（Firestore から取得する場合は修正）
    return cardId * 10;
  }

  String _getCardType(int cardId) {
    // 仮のカードタイプを返す（Firestore から取得する場合は修正）
    if (cardId % 3 == 0) return 'IT';
    if (cardId % 3 == 1) return '語学';
    return 'ビジネス';
  }
}
